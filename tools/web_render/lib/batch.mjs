// Batch mode (author, 2026-10-24): submit every prompt in its own Gemini chat without waiting,
// record each asset's chat URL, then come back and harvest the finished results chat by chat.
// Generation runs on Google's side, so a chat keeps rendering after the tab or script is gone.
// State: runs/batch.json, { asset_id: { kind, chat, submitted, harvested? } }.
import fs from 'node:fs';
import path from 'node:path';
import {
  StepError, waitReady, runSteps, insertText, resultInfo, waitForResult, capture, finish,
} from './engine.mjs';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const CHAT_RE = /^https:\/\/gemini\.google\.com\/(?:u\/\d+\/)?app\/[0-9a-f]{8,}/;

export function loadBatch(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return {}; }
}

// Submit and harvest can run at the same time, so each write re-reads the file and replaces only
// the entry this process changed, never another process's newer entries.
function saveBatch(file, state, id) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const disk = loadBatch(file);
  disk[id] = state[id];
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(disk, null, 2)}\n`);
  fs.renameSync(tmp, file);
}

/** Open a fresh chat, put the prompt in, send it, and return the chat URL Gemini moves to. */
async function submitOne(session, surface, task, prompt) {
  const st = surface.steps;
  const ctx = { vars: { aspect: task.aspect, id: task.id }, stepMs: surface.timeouts?.stepMs ?? 20_000 };
  await session.newPage();
  await session.goto(surface.url);
  await waitReady(session, surface, ctx);
  await runSteps(session, st.open, 'open', ctx);
  if (surface.skillFirst) {
    // The author's Gemini skill replaces the tool mode: pick it, then append the prompt after its chip.
    await runSteps(session, st.skill, 'skill', ctx);
    await insertText(session, st.input, prompt, { ...ctx, append: true });
  } else {
    await runSteps(session, st.mode, 'mode', ctx);
    await runSteps(session, st.options, 'options', ctx);
    await insertText(session, st.input, prompt, ctx);
  }
  await runSteps(session, st.submit, 'submit', ctx);
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    const url = session.page.url();
    // A chat counts only once the sent message is on the page (a rejected send can still flash a URL).
    if (CHAT_RE.test(url) && await session.page.$('user-query')) return url.split('?')[0];
    await sleep(500);
  }
  throw new StepError('submit', `sent, but the page never moved to a chat URL (still ${session.page.url()})`);
}

const chatId = (url) => (url.match(/\/app\/([0-9a-f]{8,})/) || [])[1] || null;

/** Click the first visible element whose own text is exactly `text` (inside `scope`, a CSS selector). */
async function clickText(page, scope, text) {
  return page.evaluate((scope, text) => {
    const vis = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
    for (const root of document.querySelectorAll(scope)) {
      for (const e of root.querySelectorAll('button, [role=menuitem], [role=button]')) {
        if (vis(e) && e.innerText.trim().split('\n').map((x) => x.trim()).pop() === text) { e.click(); return true; }
      }
    }
    return false;
  }, scope, text);
}

/**
 * Delete the chat at `chatUrl` and nothing else (author, 2026-10-24: once the track is downloaded,
 * clean up the chat that was created for it, only that id). Uses the open chat's own conversation
 * menu, after checking the page is that chat; then reloads the URL to confirm the chat is gone.
 */
export async function deleteChat(session, chatUrl) {
  const want = chatId(chatUrl);
  const page = session.page;
  if (!want || chatId(page.url()) !== want) throw new StepError('delete', `page is ${page.url()}, not the chat ${chatUrl}; nothing deleted`);
  const menu = await page.waitForSelector("button[aria-label^='Open menu for conversation actions']", { timeout: 20_000 });
  await menu.click();
  await sleep(1000);
  const item = await page.waitForSelector("gem-menu-item[data-test-id='delete-button']", { visible: true, timeout: 10_000 }).catch(() => null);
  if (!item) throw new StepError('delete', 'no Delete item in the conversation menu');
  await item.click();
  await sleep(1000);
  if (chatId(page.url()) !== want) throw new StepError('delete', 'the page left the chat before confirming; nothing confirmed');
  const confirm = await page.$("[data-test-id='confirm-button']");
  if (confirm) await confirm.click();
  else if (!await clickText(page, 'mat-dialog-container, [role=dialog], [role=alertdialog]', 'Delete')) {
    const seen = await page.evaluate(() => [...document.querySelectorAll('button')].filter((e) => e.getBoundingClientRect().width).map((e) => `${e.innerText.trim().replace(/\s+/g, ' ')}|${e.getAttribute('data-test-id')}`).slice(-12).join('; '));
    throw new StepError('delete', `no Delete button in the confirmation dialog (visible buttons: ${seen})`);
  }
  await sleep(3000);
  await session.goto(chatUrl);
  await sleep(5000);
  if (chatId(page.url()) === want && await page.$('model-response')) throw new StepError('delete', 'the chat still opens after Delete');
}

/** Submit every task not already submitted; `gapMs` between sends. */
export async function submitAll(session, { tasks, surfaceOf, promptOf, file, gapMs, log = console.log }) {
  const state = loadBatch(file);
  const todo = tasks.filter((t) => !state[t.id]?.chat);
  log(`batch submit: ${todo.length} to send (${tasks.length - todo.length} already have a chat), ${Math.round(gapMs / 1000)}s apart`);
  for (const [i, t] of todo.entries()) {
    if (i) await sleep(gapMs);
    log(`[${i + 1}/${todo.length}] ${t.kind} ${t.id}`);
    try {
      const chat = await submitOne(session, surfaceOf(t), t, promptOf(t));
      state[t.id] = { kind: t.kind, chat, submitted: new Date().toISOString() };
      saveBatch(file, state, t.id);
      log(`    -> ${chat}`);
    } catch (e) {
      const dir = await session.dumpDebug(t.id, e).catch(() => null);
      log(`  !! ${t.id}: ${e.message.split('\n')[0]}${dir ? ` (debug: ${dir})` : ''}`);
      if (e.abortRun) throw e;
    }
  }
  return state;
}

/** Reopen each recorded chat and capture its result into the asset's drop file. */
export async function harvestAll(session, { tasks, surfaceOf, file, log = console.log }) {
  const state = loadBatch(file);
  const byId = new Map(tasks.map((t) => [t.id, t]));
  // Already downloaded but not yet deleted: delete now (only the recorded id).
  for (const id of Object.keys(state).filter((id) => state[id].harvested && !state[id].deleted && state[id].chat)) {
    try {
      await session.newPage();
      await session.goto(state[id].chat);
      await sleep(6000);
      await deleteChat(session, state[id].chat);
      state[id].deleted = new Date().toISOString();
      saveBatch(file, state, id);
      log(`- ${id}: chat ${chatId(state[id].chat)} deleted`);
    } catch (e) { log(`  !! ${id}: chat not deleted: ${e.message.split('\n')[0]}`); }
  }
  const ids = Object.keys(state).filter((id) => state[id].chat && !state[id].harvested && byId.has(id));
  log(`batch harvest: ${ids.length} chat(s) to collect`);
  const left = [];
  for (const id of ids) {
    const t = byId.get(id);
    const surface = surfaceOf(t);
    log(`- ${id}  ${state[id].chat}`);
    try {
      await session.newPage();
      await session.goto(state[id].chat);
      await waitReady(session, surface, {});
      const st = surface.steps;
      if ((await resultInfo(session.page, st.result, surface.resultMinSize ?? 0)).count === 0) {
        // Still generating (or the reply is still loading): wait a little, then move on.
        await waitForResult(session, surface, 0, 60_000, 0).catch(() => {});
      }
      if ((await resultInfo(session.page, st.result, surface.resultMinSize ?? 0)).count === 0) {
        log('    not ready yet (still generating, or no result in this chat)');
        left.push(id);
        continue;
      }
      const got = await capture(session, surface, { vars: { aspect: t.aspect, id }, stepMs: surface.timeouts?.stepMs ?? 20_000 });
      await finish(session, t, got, surface);
      state[id].harvested = new Date().toISOString();
      saveBatch(file, state, id);
      try {
        await deleteChat(session, state[id].chat);
        state[id].deleted = new Date().toISOString();
        saveBatch(file, state, id);
        log(`    chat ${chatId(state[id].chat)} deleted`);
      } catch (e) {
        log(`  !! ${id}: downloaded, but the chat was not deleted: ${e.message.split('\n')[0]}`);
      }
    } catch (e) {
      log(`  !! ${id}: ${e.message.split('\n')[0]}`);
      left.push(id);
      if (e.abortRun) throw e;
    }
  }
  log(`harvest done: ${ids.length - left.length} saved, ${left.length} left${left.length ? ` (${left.join(', ')}); run --harvest again later` : ''}`);
  return left;
}
