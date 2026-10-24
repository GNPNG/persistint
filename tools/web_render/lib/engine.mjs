// The generic web-UI render engine. Everything page-specific (URLs, selectors, step order)
// comes from a "surface" in selectors.json; this file only knows how to run steps, type the
// prompt, wait for a new media element, and capture the file.
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fill, SettingsError } from './config.mjs';
import { WEB_RENDER_DIR } from './tasks.mjs';
import { saveToDrop, extFromMime, windowsToWsl, wslToWindows, checkImage, sniffExt } from './media.mjs';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const DEBUG_DIR = path.join(WEB_RENDER_DIR, 'debug');

export class StepError extends Error {
  constructor(step, message) { super(`[${step}] ${message}`); this.step = step; }
}

// ------------------------------------------------------------------ session

export class Session {
  constructor(browser, settings, { log = console.log, allowFileUrls = false } = {}) {
    this.browser = browser;
    this.settings = settings;
    this.log = log;
    this.allowFileUrls = allowFileUrls;
    this.downloads = new Map();   // guid -> {name, state, seq}
    this.seq = 0;
    this.page = null;
    this.console = [];
  }

  async init() {
    const local = this.settings.downloadDir;
    if (this.settings.browserURL && !this.settings.downloadDirBrowser && !local.startsWith('/mnt/')) {
      // An attached Chrome (normally Windows Chrome) cannot write to a WSL-only folder, so every
      // download would time out before falling back. Fail now instead.
      throw new SettingsError(`attach mode (--browser-url): downloadDir ${local} is not visible to a Windows Chrome. ` +
        'Set "downloadDir": "/mnt/c/Users/<you>/persistint-downloads" in config.local.json (or set downloadDirBrowser ' +
        'to the same folder as the attached browser sees it).');
    }
    fs.mkdirSync(local, { recursive: true });
    let browserDir = this.settings.downloadDirBrowser;
    if (!browserDir && this.settings.browserURL && local.startsWith('/mnt/')) browserDir = wslToWindows(local);
    this.browserDownloadDir = browserDir || local;
    this.localDownloadDir = browserDir && /^[a-z]:/i.test(browserDir) ? (windowsToWsl(browserDir) ?? local) : local;
    this.cdp = await this.browser.target().createCDPSession();
    await this.cdp.send('Browser.setDownloadBehavior', {
      behavior: 'allowAndName', downloadPath: this.browserDownloadDir, eventsEnabled: true,
    });
    this.cdp.on('Browser.downloadWillBegin', (e) => {
      this.downloads.set(e.guid, { name: e.suggestedFilename, url: e.url, state: 'inProgress', seq: ++this.seq });
    });
    this.cdp.on('Browser.downloadProgress', (e) => {
      const d = this.downloads.get(e.guid);
      if (d) d.state = e.state;
    });
  }

  async newPage() {
    // Author, 2026-10-24: keep the tab count down. In attach mode (the author's own window) reuse
    // this session's tab, or the window's first tab, instead of opening a new tab per asset.
    if (this.settings.browserURL) {
      if (!this.page || this.page.isClosed()) this.page = (await this.browser.pages())[0] || await this.browser.newPage();
      this.page.setDefaultTimeout(60_000);
      return this.page;
    }
    if (this.page && !this.page.isClosed()) await this.page.close().catch(() => {});
    const page = await this.browser.newPage();
    this.console = [];
    page.on('console', (m) => this.console.push(`[${m.type()}] ${m.text()}`));
    page.on('pageerror', (e) => this.console.push(`[pageerror] ${e.message}`));
    page.setDefaultTimeout(60_000);
    this.page = page;
    return page;
  }

  async goto(url) {
    const u = new URL(url);
    if (u.protocol !== 'https:' && !(this.allowFileUrls && u.protocol === 'file:')) {
      throw new Error(`refusing to open ${url}: https only`);
    }
    await this.page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 });
  }

  /** Wait for a download that started after `sinceSeq` to complete; returns its bytes. */
  async waitForDownload(sinceSeq, timeoutMs) {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      for (const [guid, d] of this.downloads) {
        if (d.seq <= sinceSeq) continue;
        if (d.state === 'canceled') throw new Error(`download ${d.name} was canceled`);
        if (d.state === 'completed') {
          const file = path.join(this.localDownloadDir, guid);
          for (let i = 0; i < 20 && !fs.existsSync(file); i++) await sleep(250);
          const buf = fs.readFileSync(file);
          fs.rmSync(file, { force: true });
          return { buf, name: d.name, mime: null };
        }
      }
      await sleep(500);
    }
    throw new Error(`no completed download within ${Math.round(timeoutMs / 1000)}s`);
  }

  async dumpDebug(taskId, err) {
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    const dir = path.join(DEBUG_DIR, `${taskId}-${ts}`);
    fs.mkdirSync(dir, { recursive: true });
    const p = this.page;
    try { await p.screenshot({ path: path.join(dir, 'screenshot.png'), fullPage: false }); } catch (e) { fs.writeFileSync(path.join(dir, 'screenshot.error.txt'), String(e)); }
    try { fs.writeFileSync(path.join(dir, 'page.html'), redactHtml(await p.content())); } catch (e) { fs.writeFileSync(path.join(dir, 'page.error.txt'), String(e)); }
    fs.writeFileSync(path.join(dir, 'console.log'), this.console.join('\n'));
    fs.writeFileSync(path.join(dir, 'error.txt'),
      `step: ${err.step ?? '?'}\nurl: ${p?.url?.() ?? '?'}\n\n${err.stack || err}\n`);
    return dir;
  }
}

/**
 * Strip what a signed-in Google page embeds about the account before a debug copy is written:
 * every <script> body (WIZ_global_data holds session and XSRF tokens), inline JSON, and email
 * addresses. The DOM structure needed to fix selectors is kept. The screenshot is not redacted.
 */
export function redactHtml(html) {
  return String(html)
    .replace(/(<script\b[^>]*>)[\s\S]*?(<\/script\s*>)/gi, '$1/* removed by web_render */$2')
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[email removed]')
    .replace(/\b(SNlM0e|FdrFJe|cfb2h|WZsZ1e|at|xsrf[_-]?token|csrf[_-]?token)(["']?\s*[:=]\s*["'])[^"']{8,}(["'])/gi, '$1$2[token removed]$3');
}

// ------------------------------------------------------------------ element finding

async function isVisible(h) {
  try {
    if (!(await h.boundingBox())) return false;
    return await h.evaluate((el) => {
      const cs = getComputedStyle(el);
      return cs.visibility !== 'hidden' && cs.display !== 'none' && Number(cs.opacity) > 0;
    });
  } catch { return false; }
}

/**
 * Try each selector candidate in order until one has a visible match; returns the LAST visible
 * match (the newest one in a chat). Keeps retrying until timeoutMs.
 */
export async function find(page, selectors, { timeoutMs = 20_000, vars = {}, log = null, step = '?', rehover = null } = {}) {
  const deadline = Date.now() + timeoutMs;
  do {
    // Hover-revealed controls vanish if the hover is lost (e.g. the real mouse moves over the
    // window), so re-hover the last hovered element before every look.
    if (rehover) await rehover.hover().catch(() => {});
    for (let i = 0; i < selectors.length; i++) {
      const sel = fill(selectors[i], vars);
      let handles = [];
      try { handles = await page.$$(sel); } catch { continue; }
      const vis = [];
      for (const h of handles) if (await isVisible(h)) vis.push(h);
      if (vis.length) {
        if (log && i > 0) log(`    (${step}: matched fallback #${i + 1}: ${sel})`);
        return { handle: vis[vis.length - 1], selector: sel };
      }
    }
    await sleep(500);
  } while (Date.now() < deadline);
  throw new StepError(step, `none of these matched a visible element: ${selectors.map((s) => fill(s, vars)).join(' | ')}`);
}

async function anyVisible(page, selectors) {
  for (const sel of selectors || []) {
    let hs = [];
    try { hs = await page.$$(sel); } catch { continue; }
    for (const h of hs) if (await isVisible(h)) return sel;
  }
  return null;
}

// ------------------------------------------------------------------ steps

export async function runSteps(session, steps, name, ctx = {}) {
  const { page, log } = session;
  let hovered = null;
  for (const [i, st] of (steps || []).entries()) {
    const label = `${name}[${i}]${st.note ? ` ${st.note}` : ''}`;
    try {
      switch (st.action) {
        case 'goto': await session.goto(fill(st.url, ctx.vars || {})); break;
        case 'sleep': await sleep(st.ms); break;
        case 'press': await page.keyboard.press(st.key); break;
        case 'type': await page.keyboard.type(fill(st.text, ctx.vars || {}), { delay: 40 }); break;
        default: {
          let handle;
          if (st.target === 'result') {
            handle = ctx.resultHandle;
            if (!handle) throw new StepError(label, 'no result element to act on');
          } else {
            try {
              ({ handle } = await find(page, st.selectors, { timeoutMs: st.timeoutMs ?? ctx.stepMs ?? 20_000, vars: ctx.vars, log, step: label, rehover: hovered }));
            } catch (e) {
              // orPress: when the control is not there, press a key instead (Enter to send,
              // Escape to close a menu that has no matching item) and carry on.
              if (!st.orPress) throw e;
              log(`    (${label}: not found; pressing ${st.orPress} instead)`);
              await page.keyboard.press(st.orPress);
              if (st.afterMs) await sleep(st.afterMs);
              continue;
            }
          }
          if (st.action === 'click') { await handle.scrollIntoView().catch(() => {}); await handle.click(); hovered = null; }
          else if (st.action === 'hover') { await handle.scrollIntoView().catch(() => {}); await handle.hover(); hovered = handle; }
          // waitFor: finding it was the point
        }
      }
      if (st.afterMs) await sleep(st.afterMs);
    } catch (e) {
      if (st.optional) { log(`    (optional ${label} skipped: ${e.message.split('\n')[0]})`); continue; }
      throw e instanceof StepError ? e : new StepError(label, e.message);
    }
  }
}

/** Put text into a contenteditable (Quill) or textarea without the clipboard. */
export async function insertText(session, selectors, text, ctx = {}) {
  const { page, log } = session;
  const { handle } = await find(page, selectors, { timeoutMs: ctx.stepMs ?? 30_000, log, step: 'input' });
  await handle.click();
  // execCommand('insertText') goes through the browser's own editing path, so editors like
  // Quill update their model (synthetic input events and element.value = ... do not).
  const append = !!ctx.append;
  const ok = await handle.evaluate((el, t, append) => {
    const isField = el.tagName === 'TEXTAREA' || el.tagName === 'INPUT';
    const read = () => (isField ? el.value : el.innerText).replace(/\s+/g, ' ');
    const want = t.slice(0, 60).replace(/\s+/g, ' ');
    el.focus();
    if (!append) { if (isField) el.select(); else document.execCommand('selectAll', false, null); }
    else if (!isField) { const r = document.createRange(); r.selectNodeContents(el); r.collapse(false); const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r); }
    document.execCommand('insertText', false, t);
    if (read().includes(want)) return true;
    if (isField) {
      // A framework-controlled <textarea>: set the value through the native setter so the
      // framework sees the change, then fire input/change.
      const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, t);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return read().includes(want);
    }
    return false;
  }, text, append);
  if (!ok) {
    log('    (execCommand insert did not take; typing instead)');
    await page.keyboard.down('Control'); await page.keyboard.press('a'); await page.keyboard.up('Control');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(text);
  }
}

// ------------------------------------------------------------------ results

// Result elements are found in-page with plain CSS. Icons and avatars are excluded by size:
// an <img> only counts once it has loaded at >= minSize px on its longer side.
function pickResults(sels, minSize) {
  const set = new Set();
  for (const s of sels) { try { document.querySelectorAll(s).forEach((e) => set.add(e)); } catch { /* bad selector */ } }
  const big = (e) => {
    const m = e.matches('img,video,audio') ? e : e.querySelector('img,video,audio');
    if (!m || m.tagName !== 'IMG' || !m.complete) return true;
    return Math.max(m.naturalWidth, m.naturalHeight) >= minSize;
  };
  return [...set].filter(big).sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1));
}

async function newestResult(page, selectors, minSize) {
  // Puppeteer serializes pickResults itself, so nothing is eval'd in the page (CSP-safe).
  const arr = await page.evaluateHandle(pickResults, selectors, minSize);
  const count = await arr.evaluate((a) => a.length);
  const last = count ? (await arr.evaluateHandle((a) => a[a.length - 1])).asElement() : null;
  await arr.dispose();
  return { count, last };
}

/** Newest result element (CSS selectors), how many there are, its src and whether it is loaded. */
export async function resultInfo(page, selectors, minSize = 0) {
  const { count, last } = await newestResult(page, selectors, minSize);
  if (!last) return { count: 0 };
  const info = await last.evaluate((el) => {
    const media = el.matches('img,video,audio') ? el : el.querySelector('img,video,audio');
    if (!media) return { tag: el.tagName.toLowerCase(), src: '', ready: true };
    const src = media.currentSrc || media.src || media.querySelector('source')?.src || '';
    const tag = media.tagName.toLowerCase();
    return { tag, src, ready: tag === 'img' ? media.complete && media.naturalWidth > 0 : !!src };
  });
  await last.dispose();
  return { count, ...info };
}

export async function resultHandle(page, selectors, minSize = 0) {
  return (await newestResult(page, selectors, minSize)).last;
}

/** How many elements match the CSS `selectors`, and the newest one's text (for a reply with no media). */
export async function responseInfo(page, selectors) {
  if (!selectors?.length) return { count: 0, text: '' };
  return page.evaluate((sels) => {
    const set = new Set();
    for (const s of sels) { try { document.querySelectorAll(s).forEach((e) => set.add(e)); } catch { /* bad selector */ } }
    const all = [...set].sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1));
    const last = all[all.length - 1];
    return { count: all.length, text: last ? (last.innerText || '').replace(/\s+/g, ' ').trim() : '' };
  }, selectors);
}

/**
 * Wait for a new, loaded, stable media result. Fails fast instead of waiting out generateMs when
 * - a usage-limit notice (steps.limitNotice) shows: the error has abortRun = true, so the run
 *   stops instead of spending the next assets on the same notice;
 * - a new reply (steps.response) has finished (not busy) but still holds no media after
 *   timeouts.textOnlyMs: a refusal, "can't generate", or a signed-out page.
 */
export async function waitForResult(session, surface, baseline, timeoutMs, respBaseline = null) {
  const { page, log } = session;
  const st = surface.steps;
  const textOnlyMs = surface.timeouts?.textOnlyMs ?? 90_000;
  const t0 = Date.now();
  let lastLog = t0, prevSrc = null, stable = 0, quietSince = null;
  while (Date.now() - t0 < timeoutMs) {
    const info = await resultInfo(page, st.result, surface.resultMinSize ?? 0);
    const busy = await anyVisible(page, st.busy);
    if (info.count > baseline && info.ready && !busy) {
      stable = info.src === prevSrc ? stable + 1 : 0;
      prevSrc = info.src;
      if (stable >= 1) return info;
    }
    if (info.count <= baseline) {
      const limitSel = await anyVisible(page, st.limitNotice);
      if (limitSel) {
        const text = (await responseInfo(page, st.response ?? ['model-response'])).text;
        const e = new StepError('wait', `usage limit notice on the page (${limitSel}): "${text.slice(0, 300)}"`);
        e.abortRun = true;
        e.replyText = text;
        throw e;
      }
      if (!busy && st.response && respBaseline !== null) {
        const r = await responseInfo(page, st.response);
        if (r.count > respBaseline) {
          quietSince ??= Date.now();
          if (Date.now() - quietSince >= textOnlyMs) {
            const e = new StepError('wait', `the reply finished without any media after ${Math.round(textOnlyMs / 1000)}s: "${r.text.slice(0, 300) || '(no text)'}"`);
            e.textOnly = true;          // lib/tracker.mjs classifies the reply text (refused / quota / failed)
            e.replyText = r.text;
            throw e;
          }
        } else quietSince = null;
      } else quietSince = null;
    } else quietSince = null;
    if (Date.now() - lastLog >= 30_000) {
      lastLog = Date.now();
      log(`    ... waiting ${Math.round((Date.now() - t0) / 1000)}s (results ${info.count}/${baseline + 1}${busy ? ', busy' : ''}${info.count > baseline && !info.ready ? ', loading' : ''}${quietSince ? ', reply has no media yet' : ''})`);
    }
    await sleep(2000);
  }
  throw new StepError('wait', `no new result within ${Math.round(timeoutMs / 1000)}s`);
}

/** Read a media element's src from inside the page (works for blob:, data: and cookie-gated https). */
export async function fetchSrc(page, src) {
  const r = await page.evaluate(async (url) => {
    const res = await fetch(url, { credentials: 'include' });
    if (!res.ok) throw new Error(`fetch ${res.status}`);
    const blob = await res.blob();
    const b64 = await new Promise((ok) => { const fr = new FileReader(); fr.onload = () => ok(String(fr.result).split(',')[1]); fr.readAsDataURL(blob); });
    return { b64, type: blob.type };
  }, src);
  return { buf: Buffer.from(r.b64, 'base64'), mime: r.type };
}

/** Run the surface's capture routes in order; returns bytes from the first that works. */
export async function capture(session, surface, ctx) {
  const routes = surface.capture ?? ['download', 'src'];
  const errs = [];
  for (const route of routes) {
    try {
      if (route === 'download') {
        const since = session.seq;
        const resultH = await resultHandle(session.page, surface.steps.result, surface.resultMinSize ?? 0);
        await runSteps(session, surface.steps.download, 'download', { ...ctx, resultHandle: resultH });
        return { ...(await session.waitForDownload(since, surface.timeouts?.downloadMs ?? 180_000)), route };
      }
      if (route === 'src') {
        const info = await resultInfo(session.page, surface.steps.result, surface.resultMinSize ?? 0);
        if (!info.src) throw new Error('newest result has no src');
        return { ...(await fetchSrc(session.page, info.src)), route };
      }
    } catch (e) {
      errs.push(`${route}: ${e.message.split('\n')[0]}`);
      session.log(`    (capture route ${route} failed: ${e.message.split('\n')[0]})`);
    }
  }
  throw new StepError('capture', errs.join('; '));
}

// ------------------------------------------------------------------ human in the loop

function askCancellable(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const promise = new Promise((res) => {
    rl.question(question, (a) => { rl.close(); res(a.trim().toLowerCase()); });
    rl.on('close', () => res(''));
  });
  return { promise, cancel: () => rl.close() };
}
const ask = (q) => askCancellable(q).promise;

/**
 * Wait for the author to finish in the browser window. Returns bytes from a download the author
 * triggered, or from the newest result element when they press Enter. null = skipped.
 */
export async function manualCapture(session, surface, baseline, message) {
  const since = session.seq;
  session.log(message);
  let answered = null;
  const q = askCancellable('  Press Enter when the result is visible or downloaded (s = skip): ');
  const asking = q.promise.then((a) => { answered = a; });
  const watchDownload = (async () => {
    while (answered === null) {
      for (const [, d] of session.downloads) if (d.seq > since && d.state === 'completed') return true;
      await sleep(1000);
    }
    return false;
  })();
  const downloaded = await Promise.race([asking.then(() => false), watchDownload]);
  if (downloaded) { q.cancel(); process.stdout.write('\n'); }
  if (answered === 's') return null;
  if ([...session.downloads.values()].some((d) => d.seq > since && d.state !== 'canceled')) {
    if (downloaded) session.log('  (download seen; capturing it)');
    const got = await session.waitForDownload(since, 120_000);
    return { ...got, route: 'manual-download' };
  }
  const info = await resultInfo(session.page, surface.steps.result, surface.resultMinSize ?? 0);
  if (info.src && !(surface.capture ?? ['download', 'src']).includes('src')) {
    session.log(`  warning: saving the on-page ${info.tag} (this surface normally takes only its download button; for an image this is the downscaled preview). Use --force later to replace it.`);
  }
  if (info.count > baseline && info.src) return { ...(await fetchSrc(session.page, info.src)), route: 'manual-src' };
  if (info.src) {
    const a = await ask(`  No NEW result found, but the newest one on the page is ${info.tag}. Use it? [y/N] `);
    if (a === 'y') return { ...(await fetchSrc(session.page, info.src)), route: 'manual-src' };
  }
  return null;
}

// ------------------------------------------------------------------ page ready

/**
 * After opening the surface: let the network settle, then wait until the prompt box (steps.input)
 * is visible, i.e. the app has hydrated. The static shell Gemini serves first has a plain
 * "Ask Gemini" box and none of the real controls, so acting before this point fails.
 * A Google "unusual traffic" / reCAPTCHA page (steps.blocked) stops the run: it needs a human.
 */
export async function waitReady(session, surface, ctx = {}) {
  const { page } = session;
  const st = surface.steps;
  await page.waitForNetworkIdle({ idleTime: 1000, timeout: 15_000 }).catch(() => {});
  const deadline = Date.now() + (surface.timeouts?.readyMs ?? 60_000);
  do {
    const blockedSel = await anyVisible(page, st.blocked);
    if (blockedSel) {
      const e = new StepError('ready', `Google is showing a check page (${blockedSel}), e.g. "unusual traffic" with a reCAPTCHA. ` +
        'Solve it by hand in the dedicated profile (node inspect.mjs --keep 300), then run again.');
      e.abortRun = true;
      throw e;
    }
    for (const sel of st.input) {
      let hs = [];
      try { hs = await page.$$(fill(sel, ctx.vars || {})); } catch { continue; }
      for (const h of hs) if (await isVisible(h)) return sel;
    }
    await sleep(1000);
  } while (Date.now() < deadline);
  throw new StepError('ready', `the prompt box never appeared (page not hydrated?): ${st.input.join(' | ')}`);
}

// ------------------------------------------------------------------ one asset

/**
 * Render one task on one surface. `prompt` is the final text to put in the box.
 * opts: { assist, pauseOnError, taskId }
 */
export async function renderOnSurface(session, surface, task, prompt, opts = {}) {
  const st = surface.steps;
  const stepMs = surface.timeouts?.stepMs ?? 20_000;
  const vars = { aspect: task.aspect, id: task.id };
  const ctx = { vars, stepMs };
  const log = session.log;
  let baseline = 0;
  let step = 'open';
  try {
    await session.newPage();
    await session.goto(surface.url);
    step = 'ready'; await waitReady(session, surface, ctx);
    step = 'open'; await runSteps(session, st.open, 'open', ctx);
    if (surface.skillFirst) {
      // The author's Gemini skill replaces the tool mode: pick it, then append the prompt after its chip.
      step = 'skill'; await runSteps(session, st.skill, 'skill', ctx);
      step = 'input'; await insertText(session, st.input, prompt, { ...ctx, append: true });
    } else {
      step = 'mode'; await runSteps(session, st.mode, 'mode', ctx);
      step = 'options'; await runSteps(session, st.options, 'options', ctx);
      step = 'input'; await insertText(session, st.input, prompt, ctx);
    }
    baseline = (await resultInfo(session.page, st.result, surface.resultMinSize ?? 0)).count;
    const respBaseline = st.response ? (await responseInfo(session.page, st.response)).count : null;
    if (opts.assist) {
      const got = await manualCapture(session, surface, baseline,
        `  [assist] Prompt is in the box. Check the settings, click send, wait, then press Enter (or click the download button).`);
      if (!got) return { skipped: true };
      return await finish(session, task, got, surface);
    }
    step = 'submit'; await runSteps(session, st.submit, 'submit', ctx);
    step = 'wait';
    const gms = surface.timeouts?.generateMs ?? 900_000;
    log(`    submitted; waiting for the result (up to ${gms < 120_000 ? `${Math.round(gms / 1000)} s` : `${Math.round(gms / 60_000)} min`})`);
    await waitForResult(session, surface, baseline, gms, respBaseline);
    step = 'capture';
    const got = await capture(session, surface, ctx);
    return await finish(session, task, got, surface);
  } catch (e) {
    if (!e.step) e.step = step;
    const dir = await session.dumpDebug(task.id, e).catch(() => null);
    log(`  !! ${task.id}: failed at ${e.step}: ${e.message.split('\n')[0]}`);
    if (dir) log(`     debug saved to ${path.relative(process.cwd(), dir) || dir}`);
    if (opts.pauseOnError && session.page && !session.page.isClosed()) {
      const got = await manualCapture(session, surface, baseline,
        '  [pause-on-error] Fix it by hand in the browser window (send the prompt, wait for the result).');
      if (got) return await finish(session, task, got, surface);
    }
    e.debugDir = dir;
    throw e;
  }
}

/** Re-encode image bytes as PNG in the page (no ffmpeg needed): JPEG/WebP download -> .png drop. */
export async function toPngInPage(page, buf) {
  const b64 = await page.evaluate(async (data) => {
    const bin = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
    const bmp = await createImageBitmap(new Blob([bin]));
    const c = new OffscreenCanvas(bmp.width, bmp.height);
    c.getContext('2d').drawImage(bmp, 0, 0);
    const out = new Uint8Array(await (await c.convertToBlob({ type: 'image/png' })).arrayBuffer());
    let s = '';
    for (let i = 0; i < out.length; i += 0x8000) s += String.fromCharCode(...out.subarray(i, i + 0x8000));
    return btoa(s);
  }, buf.toString('base64'));
  return Buffer.from(b64, 'base64');
}

export async function finish(session, task, got, surface = {}) {
  const log = session.log;
  if (task.kind === 'image') {
    const problems = checkImage(got.buf, task.aspect, surface.verify ?? {});
    if (problems.length) throw new StepError('verify', `captured image rejected: ${problems.join('; ')}`);
    const want = path.extname(task.drop_abs).toLowerCase();
    const have = sniffExt(got.buf);
    if (want === '.png' && have !== '.png' && session.page && !session.page.isClosed()) {
      got = { ...got, buf: await toPngInPage(session.page, got.buf), mime: 'image/png' };
      log(`    re-encoded ${have} -> .png in the browser`);
    }
  }
  const saved = saveToDrop(got.buf, task.drop_abs, { log, mime: got.mime });
  const mimeExt = extFromMime(got.mime);
  log(`  -> ${task.drop} (${got.buf.length} bytes via ${got.route}${mimeExt ? `, ${got.mime}` : ''})`);
  return { saved: saved.path, bytes: got.buf.length, route: got.route, format: saved.format, converted: saved.converted };
}
