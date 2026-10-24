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
  await newChat(session, surface);
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
  // Author, 2026-10-24: stay on this chat until the generation has really started (Gemini's Stop
  // button shows, or its reply is on the page) before recording it and moving on. Leaving earlier
  // can abandon the send, and the chat id is only final once the reply has begun.
  const deadline = Date.now() + 180_000;
  while (Date.now() < deadline) {
    const url = session.page.url();
    const started = await session.page.$('model-response') || await anyVisibleSel(session.page, st.busy);
    if (CHAT_RE.test(url) && started && await session.page.$('user-query')) {
      await sleep(5000);
      return session.page.url().split('?')[0];
    }
    await sleep(1000);
  }
  throw new StepError('submit', `sent, but no generation started within 3 min (page ${session.page.url()})`);
}

// Author, 2026-10-24: never reload the Gemini page. Navigate inside the app the way a person
// does: "New chat" and the chat links in the sidebar. A full load happens only when the tab is not
// on Gemini at all.
async function ensureGemini(session, url) {
  if (!session.page.url().startsWith('https://gemini.google.com/')) {
    await session.goto(url);
    await sleep(6000);
  }
}

async function newChat(session, surface) {
  await ensureGemini(session, surface.url);
  const link = await session.page.$("a[aria-label='New chat'], [data-test-id='new-chat-button'] a, side-nav-action-button[data-test-id='new-chat-button']")
    || await session.page.$('::-p-aria(New chat)');
  if (!link) throw new StepError('open', 'no New chat button in the sidebar');
  await link.click();
  await sleep(2500);
}

/** Open a recorded chat by clicking its sidebar link; returns false when it is not in the sidebar. */
async function openChat(session, surface, chatUrl) {
  await ensureGemini(session, surface.url);
  const id = chatId(chatUrl);
  if (chatId(session.page.url()) === id) return true;
  const link = await session.page.$(`a[href$="/app/${id}"]`);
  if (!link) return false;
  await link.click();
  for (let i = 0; i < 20 && chatId(session.page.url()) !== id; i++) await sleep(500);
  await sleep(4000);
  return chatId(session.page.url()) === id;
}

async function anyVisibleSel(page, sels = []) {
  for (const sel of sels) {
    try { for (const h of await page.$$(sel)) if (await h.isVisible()) return true; } catch { /* bad selector */ }
  }
  return false;
}

// Author, 2026-10-24: never delete a chat before its result is downloaded. The drop file must be on
// disk at a real size before deleteChat runs; otherwise the chat is kept.
function downloaded(task) {
  try { return !!task && fs.statSync(task.drop_abs).size > 100_000; } catch { return false; }
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
 * menu, after checking the page is that chat; then checks its sidebar link is gone (no reload).
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
  await sleep(4000);
  if (await page.$(`a[href$="/app/${want}"]`)) throw new StepError('delete', 'the chat is still in the sidebar after Delete');
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
  for (const id of Object.keys(state).filter((id) => state[id]?.harvested && !state[id].deleted && state[id].chat && downloaded(byId.get(id)))) {
    try {
      await session.newPage();
      if (!await openChat(session, surfaceOf(byId.get(id) || { kind: state[id].kind }), state[id].chat)) { log(`  !! ${id}: chat not in the sidebar; not deleted`); continue; }
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
      if (!await openChat(session, surface, state[id].chat)) {
        log('    not in the sidebar list (left as is; check by hand)');
        left.push(id);
        continue;
      }
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
        if (!downloaded(t)) throw new Error(`${t.drop} is not on disk; chat kept`);
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
