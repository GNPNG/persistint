#!/usr/bin/env node
// Look at a live surface without generating anything: open it on the dedicated profile, wait for
// the page to settle, and dump the accessibility tree, every control (buttons, inputs, menu items
// with their aria-label / text / data-test-id), a redacted HTML copy and a screenshot to
// debug/inspect-<ts>/ (gitignored). Use it to fix selectors.json when Google changes its pages.
//
//   node inspect.mjs                               # gemini_image surface URL
//   node inspect.mjs --surface gemini_video
//   node inspect.mjs --url https://gemini.google.com/app --wait 20
//   node inspect.mjs --click "::-p-aria(Open upload file menu)"   # open a menu, dump again
//   node inspect.mjs --click A --click B --keep 60  # several clicks; keep the window open 60 s
//   node inspect.mjs --do "click:::-p-aria(Upload & tools)" --do press:Escape --do "type:a cat"
//
// Each --click is a Puppeteer selector (CSS, ::-p-aria(...), ::-p-text(...)). --do runs ordered
// actions: click:SEL, hover:SEL, press:KEY, type:TEXT (types into the prompt box; never presses
// Enter). After every action a new numbered snapshot is written. Nothing is sent unless you
// --do press:Enter yourself, which would spend a generation.
import fs from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { loadSettings, loadSelectors, SELECTORS_PATH } from './lib/config.mjs';
import { DEBUG_DIR, redactHtml } from './lib/engine.mjs';

const { values: a } = parseArgs({
  options: {
    surface: { type: 'string', default: 'gemini_image' },
    url: { type: 'string' },
    wait: { type: 'string', default: '15' },
    click: { type: 'string', multiple: true, default: [] },
    do: { type: 'string', multiple: true, default: [] },
    keep: { type: 'string', default: '0' },
    profile: { type: 'string' }, chrome: { type: 'string' }, 'browser-url': { type: 'string' },
    help: { type: 'boolean', short: 'h' },
  },
  strict: true,
});
if (a.help) {
  console.log(fs.readFileSync(new URL(import.meta.url), 'utf8').split('\n').filter((l) => l.startsWith('//')).map((l) => l.slice(3)).join('\n'));
  process.exit(0);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const settings = loadSettings({ chrome: a.chrome, profileDir: a.profile, browserURL: a['browser-url'] });
const cfg = loadSelectors(SELECTORS_PATH);
const url = a.url ?? cfg.surfaces[a.surface]?.url;
if (!url) { console.error(`unknown surface ${a.surface}`); process.exit(2); }
if (new URL(url).protocol !== 'https:') { console.error('https only'); process.exit(2); }

const ts = new Date().toISOString().replace(/[:.]/g, '-');
const outDir = path.join(DEBUG_DIR, `inspect-${ts}`);
fs.mkdirSync(outDir, { recursive: true });

// Runs in the page: every interactive element, including inside open shadow roots.
function listControls() {
  const out = [];
  const sel = 'button,input,textarea,select,a[href],[role=button],[role=menuitem],[role=menuitemradio],[role=menuitemcheckbox],[role=option],[role=tab],[role=switch],[role=textbox],[contenteditable=true],[aria-haspopup],img,video,audio';
  const walk = (root) => {
    root.querySelectorAll(sel).forEach((el) => {
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      const visible = r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none';
      const icon = el.querySelector('mat-icon,[fonticon],[data-mat-icon-name]');
      out.push({
        tag: el.tagName.toLowerCase(),
        role: el.getAttribute('role') || undefined,
        aria: el.getAttribute('aria-label') || undefined,
        title: el.getAttribute('title') || undefined,
        placeholder: el.getAttribute('placeholder') || undefined,
        text: (el.innerText || el.value || '').replace(/\s+/g, ' ').trim().slice(0, 80) || undefined,
        testId: el.getAttribute('data-test-id') || el.getAttribute('data-testid') || undefined,
        id: el.id || undefined,
        cls: (typeof el.className === 'string' ? el.className : '').split(/\s+/).filter(Boolean).slice(0, 6).join(' ') || undefined,
        icon: icon ? (icon.getAttribute('fonticon') || icon.getAttribute('data-mat-icon-name') || icon.textContent.trim()) : undefined,
        src: el.matches('img,video,audio') ? String(el.currentSrc || el.src || '').slice(0, 100) : undefined,
        natural: el.tagName === 'IMG' ? `${el.naturalWidth}x${el.naturalHeight}` : undefined,
        parent: (() => { const p = el.closest('model-response,user-query,mat-menu,.cdk-overlay-container,[role=menu],[role=dialog],side-navigation,bard-sidenav,input-area-v2,rich-textarea'); return p ? p.tagName.toLowerCase() + (p.getAttribute('role') ? `[role=${p.getAttribute('role')}]` : '') : undefined; })(),
        visible,
        rect: visible ? [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)] : undefined,
      });
    });
    root.querySelectorAll('*').forEach((el) => { if (el.shadowRoot) walk(el.shadowRoot); });
  };
  walk(document);
  return out;
}

function axLines(node, depth = 0, lines = []) {
  if (!node) return lines;
  const bits = [node.role, node.name ? JSON.stringify(node.name) : '', node.value ? `value=${JSON.stringify(String(node.value).slice(0, 60))}` : '',
    node.description ? `desc=${JSON.stringify(node.description)}` : '', node.focused ? 'focused' : '', node.disabled ? 'disabled' : '',
    node.haspopup ? `haspopup=${node.haspopup}` : '', node.expanded !== undefined ? `expanded=${node.expanded}` : ''].filter(Boolean);
  lines.push(`${'  '.repeat(depth)}${bits.join(' ')}`);
  for (const c of node.children || []) axLines(c, depth + 1, lines);
  return lines;
}

async function snapshot(page, label) {
  const base = path.join(outDir, label);
  try { await page.screenshot({ path: `${base}.png` }); } catch (e) { console.log(`  screenshot failed: ${e.message}`); }
  try {
    const ax = await page.accessibility.snapshot({ interestingOnly: true });
    fs.writeFileSync(`${base}.ax.txt`, redactHtml(axLines(ax).join('\n')));
  } catch (e) { fs.writeFileSync(`${base}.ax.txt`, `accessibility snapshot failed: ${e.message}`); }
  const controls = await page.evaluate(listControls);
  fs.writeFileSync(`${base}.controls.json`, redactHtml(JSON.stringify(controls, null, 1)));
  const lines = controls.filter((c) => c.visible).map((c) =>
    [c.tag, c.role && `role=${c.role}`, c.aria && `aria=${JSON.stringify(c.aria)}`, c.text && `text=${JSON.stringify(c.text)}`,
      c.placeholder && `ph=${JSON.stringify(c.placeholder)}`, c.testId && `test-id=${c.testId}`, c.icon && `icon=${c.icon}`,
      c.natural && `img=${c.natural}`, c.parent && `in=${c.parent}`, c.cls && `.${c.cls.replace(/ /g, '.')}`].filter(Boolean).join('  '));
  fs.writeFileSync(`${base}.controls.txt`, redactHtml(lines.join('\n')));
  if (controls.some((c) => c.tag === 'iframe') || /unusual traffic/i.test(await page.evaluate(() => document.body?.innerText || ''))) {
    console.log('  !! Google is showing an "unusual traffic" check page; solve it in the window (use --keep 300).');
  }
  fs.writeFileSync(`${base}.html`, redactHtml(await page.content()));
  console.log(`  ${label}: ${controls.length} controls (${lines.length} visible) -> ${path.relative(process.cwd(), base)}.*`);
}

async function settle(page, ms) {
  await page.waitForNetworkIdle({ idleTime: 1500, timeout: ms }).catch(() => {});
  // Hydration: the Angular app replaces the static shell; wait until the prompt box is live.
  // (The pre-hydration shell has a dead <textarea placeholder="Ask Gemini">, so that does not count.)
  await page.waitForFunction(() => document.readyState === 'complete' && !!document.querySelector("rich-textarea [contenteditable=true],textarea:not([placeholder='Ask Gemini'])"), { timeout: ms }).catch(() => {});
  await sleep(2000);
}

const { getBrowser } = await import('./lib/browser.mjs');
const b = await getBrowser(settings);
const consoleLines = [];
try {
  const page = await b.browser.newPage();
  page.on('console', (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => consoleLines.push(`[pageerror] ${e.message}`));
  console.log(`Opening ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 });
  const waitMs = Number(a.wait) * 1000;
  await settle(page, waitMs);
  await snapshot(page, '00-initial');
  const actions = [...a.click.map((s) => `click:${s}`), ...a.do];
  for (const [i, act] of actions.entries()) {
    const [, verb, arg] = /^(click|hover|press|type):([\s\S]*)$/.exec(act) || [];
    const label = `${String(i + 1).padStart(2, '0')}-after-${verb || 'bad'}`;
    try {
      if (!verb) throw new Error(`bad action ${act} (use click:SEL, hover:SEL, press:KEY, type:TEXT)`);
      if (verb === 'press') await page.keyboard.press(arg);
      else if (verb === 'type') {
        const h = await page.waitForSelector(cfg.surfaces[a.surface]?.steps.input[0] ?? '[contenteditable=true]', { visible: true, timeout: 15_000 });
        await h.click();
        await page.keyboard.type(arg);
      } else {
        const h = await page.waitForSelector(arg, { visible: true, timeout: 15_000 });
        if (verb === 'click') await h.click(); else await h.hover();
      }
      console.log(`  ${verb} ${arg}`);
    } catch (e) {
      console.log(`  ${act} failed: ${e.message.split('\n')[0]}`);
    }
    await sleep(2500);
    await snapshot(page, label);
  }
  fs.writeFileSync(path.join(outDir, 'console.log'), consoleLines.join('\n'));
  fs.writeFileSync(path.join(outDir, 'url.txt'), `${url}\nfinal: ${page.url()}\n`);
  if (Number(a.keep) > 0) { console.log(`  keeping the window open ${a.keep}s`); await sleep(Number(a.keep) * 1000); }
} finally {
  await b.close();
}
console.log(`Done: ${outDir}`);
