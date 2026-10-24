// Browser-free tests: parsing parity with tools/render_all_assets.py, selectors.json validation,
// drop path / extension mapping, format sniffing, path mapping, prompt preparation.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { ROOT, discoverTasks, parsePromptText, dropFormat, selectTasks, formatStatus, besideFile, KIND_EXT } from '../lib/tasks.mjs';
import { loadSelectors, validateSelectors, assertDedicatedProfile, assertOutsideRepo, validateNumbers, parseLimit, parseDelay, SELECTORS_PATH, DEFAULTS } from '../lib/config.mjs';
import { sniffExt, saveToDrop, hasFfmpeg, wslToWindows, windowsToWsl, imageSize, checkImage } from '../lib/media.mjs';
import { Session, redactHtml } from '../lib/engine.mjs';
import { preparePrompt } from '../drivers/common.mjs';

const FIELDS = ['id', 'tool', 'drop', 'game', 'prompt', 'aspect', 'kind', 'md_path', 'exists'];

function pythonTasks() {
  const code = [
    'import sys, json',
    `sys.path.insert(0, ${JSON.stringify(path.join(ROOT, 'tools'))})`,
    'from render_all_assets import discover_tasks, ROOT',
    'ts = discover_tasks(ROOT / "prompts")',
    `print(json.dumps([{k: t.get(k) for k in ${JSON.stringify(FIELDS)}} for t in ts]))`,
  ].join('\n');
  const r = spawnSync('python3', ['-B', '-I', '-c', code], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  return JSON.parse(r.stdout);
}

test('prompt parsing matches render_all_assets.py on the real prompts/ tree', () => {
  const py = pythonTasks();
  const js = discoverTasks(undefined, { warn: () => {} }).map((t) => Object.fromEntries(FIELDS.map((k) => [k, t[k] ?? null])));
  assert.equal(js.length, 45, 'expected 45 asset prompts');
  assert.equal(py.length, 45);
  assert.deepEqual(js, py);
});

test('every asset has a drop extension matching its kind (png / mp4 / mp3)', () => {
  const tasks = discoverTasks(undefined, { warn: () => {} });
  const counts = {};
  for (const t of tasks) {
    const f = dropFormat(t);
    assert.ok(f.ok, `${t.id}: ${t.drop} (${t.kind})`);
    assert.ok(t.drop_abs.startsWith(ROOT + path.sep) && t.drop.startsWith('prompts/'), t.drop);
    counts[t.kind] = (counts[t.kind] || 0) + 1;
  }
  assert.deepEqual(counts, { image: 16, video: 9, music: 20 });
  assert.deepEqual(KIND_EXT, { image: '.png', video: '.mp4', music: '.mp3' });
});

test('parser edge cases: aspect from front matter, Notes, default; CRLF; missing fields', () => {
  const mk = (fm, body) => `---\n${fm}\n---\n\n# x\n\n${body}`;
  const p = (txt) => parsePromptText(txt, path.join(ROOT, 'prompts/x/a.md'));
  assert.equal(p(mk('id: a\ntool: Gemini image\ndrop: prompts/x/a.png\naspect: 4:3', '## Prompt\n\nhello\nworld\n\n## Notes\n\n1:1')).aspect, '4:3');
  assert.equal(p(mk('id: a\ntool: Gemini image\ndrop: prompts/x/a.png', '## Prompt\n\nhello\n\n## Notes\n\nsquare 1:1 icon')).aspect, '1:1');
  const d = p(mk('id: a\ntool: Gemini Lyria\ndrop: prompts/x/a.mp3', '## Prompt\n\nline one\nline two\n'));
  assert.equal(d.aspect, '16:9');
  assert.equal(d.prompt, 'line one line two');
  assert.equal(d.kind, 'music');
  assert.equal(p(mk('id: a\ntool: Gemini image\ndrop: x: y.png', '## Prompt\n\nhi').replace(/\n/g, '\r\n')).drop, 'x: y.png');
  assert.equal(p(mk('id: a\ntool: Gemini image', '## Prompt\n\nhi')), null);
  assert.equal(p(mk('id: a\ntool: Gemini image\ndrop: a.png', '## Notes\n\nhi')), null);
  assert.equal(p(mk('id: a\ntool: Something\ndrop: a.png', '## Prompt\n\nhi')).kind, 'other');
});

test('selectTasks filters by kind, ids and existing drops', () => {
  const ts = [
    { id: 'a', kind: 'image', exists: false }, { id: 'b', kind: 'image', exists: true },
    { id: 'c', kind: 'music', exists: false }, { id: 'd', kind: 'other', exists: false },
  ];
  assert.deepEqual(selectTasks(ts).map((t) => t.id), ['a', 'c']);
  assert.deepEqual(selectTasks(ts, { force: true }).map((t) => t.id), ['a', 'b', 'c']);
  assert.deepEqual(selectTasks(ts, { kind: 'image', force: true }).map((t) => t.id), ['a', 'b']);
  assert.deepEqual(selectTasks(ts, { only: 'c, b' }).map((t) => t.id), ['c']);
});

test('selectors.json is valid and maps every kind to an https surface', () => {
  const cfg = loadSelectors(SELECTORS_PATH);
  for (const k of ['image', 'video', 'music']) {
    const s = cfg.surfaces[cfg.kinds[k]];
    assert.equal(s.kind, k);
    assert.ok(s.url.startsWith('https://'));
  }
});

test('selector validation catches bad configs', () => {
  const good = JSON.parse(fs.readFileSync(SELECTORS_PATH, 'utf8'));
  const bad = (mutate) => { const c = structuredClone(good); mutate(c); return validateSelectors(c).join('\n'); };
  assert.match(bad((c) => { c.surfaces.gemini_image.url = 'http://gemini.google.com/app'; }), /only https/);
  assert.match(bad((c) => { c.surfaces.gemini_image.url = 'file:///tmp/x.html'; }), /only https/);
  assert.equal(validateSelectors((() => { const c = structuredClone(good); c.surfaces.gemini_image.url = 'file:///tmp/x.html'; return c; })(), { allowFileUrls: true }).length, 0);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.mode[0].action = 'tap'; }), /unknown action/);
  assert.match(bad((c) => { c.loginUrl = 'http://accounts.google.com/'; }), /loginUrl: only https/);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.input = []; }), /steps\.input: must be a non-empty array/);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.input = ['aria/Prompt']; }), /legacy aria\//);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.input = ['::-p-aria(Prompt']; }), /unbalanced/);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.result = ['::-p-aria(Image)']; }), /plain CSS/);
  assert.match(bad((c) => { c.kinds.video = 'gemini_music'; }), /kinds\.video: surface "gemini_music" has kind "music"/);
  assert.match(bad((c) => { c.kinds.music = 'nope'; }), /not defined/);
  assert.match(bad((c) => { delete c.surfaces.gemini_image.steps.download; }), /steps\.download is missing/);
  assert.match(bad((c) => { c.surfaces.gemini_image.capture = ['screenshot']; }), /capture/);
  assert.match(bad((c) => { c.surfaces.gemini_image.timeouts.generateMs = -1; }), /positive/);
  assert.match(bad((c) => { c.surfaces.gemini_image.steps.submit = [{ action: 'press' }]; }), /press needs "key"/);
});

test('format sniffing from magic bytes', () => {
  const b = (...xs) => Buffer.from(xs);
  assert.equal(sniffExt(b(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)), '.png');
  assert.equal(sniffExt(b(0xff, 0xd8, 0xff, 0xe0)), '.jpg');
  assert.equal(sniffExt(Buffer.from('RIFF\0\0\0\0WEBPVP8 ', 'latin1')), '.webp');
  assert.equal(sniffExt(Buffer.from('\0\0\0\x18ftypisom\0\0\0\0', 'latin1')), '.mp4');
  assert.equal(sniffExt(Buffer.from('\0\0\0\x18ftypM4A \0\0\0\0', 'latin1')), '.m4a');
  assert.equal(sniffExt(Buffer.from('ID3\x04\0\0\0\0', 'latin1')), '.mp3');
  assert.equal(sniffExt(b(0xff, 0xfb, 0x90, 0x64)), '.mp3');
  assert.equal(sniffExt(b(0x1a, 0x45, 0xdf, 0xa3)), '.webm');
  assert.equal(sniffExt(Buffer.from('hello world')), null);
  assert.equal(sniffExt(Buffer.from('<!doctype html><html>')), null);
  assert.equal(sniffExt(Buffer.from('\0\0\0\x1cftypavif\0\0\0\0', 'latin1')), '.avif');
  assert.equal(sniffExt(Buffer.from('\0\0\0\x1cftypheic\0\0\0\0', 'latin1')), '.heic');
  assert.equal(sniffExt(Buffer.from('\0\0\0\x1cftypmif1\0\0\0\0', 'latin1')), '.heic');
});

test('saveToDrop writes matching formats and never leaves a wrong format at the drop', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-'));
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);
  const r = saveToDrop(png, path.join(dir, 'a/b/x.png'), { log: () => {} });
  assert.equal(r.format, '.png');
  assert.deepEqual(fs.readFileSync(path.join(dir, 'a/b/x.png')), png);
  if (!hasFfmpeg()) {
    const jpg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 1]);
    assert.throws(() => saveToDrop(jpg, path.join(dir, 'y.png'), { log: () => {} }), /got \.jpg but the drop wants \.png/);
    assert.ok(!fs.existsSync(path.join(dir, 'y.png')));
    assert.ok(fs.existsSync(path.join(dir, 'y.jpg')));
  }
  fs.rmSync(dir, { recursive: true, force: true });
});

test('saveToDrop refuses bytes it cannot identify (sign-in / error pages) and leaves the asset missing', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-'));
  const drop = path.join(dir, 'key_art.png');
  const html = Buffer.from('<!doctype html><html><title>Sign in - Google Accounts</title></html>');
  assert.throws(() => saveToDrop(html, drop, { log: () => {} }), /not a recognised media file.*Sign in/);
  assert.ok(!fs.existsSync(drop));
  assert.ok(fs.existsSync(`${drop}.unknown`));
  const t = parsePromptText('---\nid: k\ntool: Gemini image\ndrop: key_art.png\n---\n\n## Prompt\n\nx\n', path.join(dir, 'k.md'), dir);
  assert.equal(t.exists, false);
  assert.equal(t.beside, null, '.unknown is not a convertible capture');
  // a real PNG body served as text/html is refused too
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]);
  assert.throws(() => saveToDrop(png, drop, { log: () => {}, mime: 'text/html; charset=utf-8' }), /not a recognised media file/);
  assert.ok(!fs.existsSync(drop));
  fs.rmSync(dir, { recursive: true, force: true });
});

test('a capture kept beside the drop in another format reports CONVERT and is not re-rendered', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-'));
  fs.mkdirSync(path.join(dir, 'm'));
  fs.writeFileSync(path.join(dir, 'm/theme.mp4'), Buffer.from('\0\0\0\x18ftypisom', 'latin1'));
  const t = parsePromptText('---\nid: theme\ntool: Gemini Lyria\ndrop: m/theme.mp3\n---\n\n## Prompt\n\nx\n', path.join(dir, 'theme.md'), dir);
  assert.equal(t.exists, false);
  assert.equal(t.beside, path.join(dir, 'm/theme.mp4'));
  assert.equal(besideFile(path.join(dir, 'm/other.mp3')), null);
  assert.deepEqual(selectTasks([t]), []);
  assert.deepEqual(selectTasks([t], { force: true }).map((x) => x.id), ['theme']);
  assert.match(formatStatus([t]), /\[CONVERT\].*theme.*run --convert/);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('--delay, --limit, delaySec and maxPerRun reject non-numbers instead of disabling pacing', () => {
  assert.throws(() => parseDelay('abc'), /--delay/);
  assert.throws(() => parseDelay('-5'), /--delay/);
  assert.throws(() => parseDelay(''), /--delay/);
  assert.equal(parseDelay('0'), 0);
  assert.equal(parseDelay('12.5'), 12.5);
  assert.equal(parseDelay(undefined), undefined);
  for (const v of ['abc', '0', '-1', '2.5', '']) assert.throws(() => parseLimit(v), /--limit/, v);
  assert.equal(parseLimit('3'), 3);
  assert.deepEqual(validateNumbers(DEFAULTS), []);
  assert.equal(validateNumbers({ ...DEFAULTS, delaySec: NaN }).length, 1);
  assert.equal(validateNumbers({ ...DEFAULTS, delaySec: '90' }).length, 1);
  assert.equal(validateNumbers({ ...DEFAULTS, maxPerRun: 0 }).length, 1);
  assert.equal(validateNumbers({ ...DEFAULTS, maxPerRun: 'lots' }).length, 1);
  const run = (...args) => spawnSync(process.execPath, [path.join(ROOT, 'tools/web_render/render.mjs'), ...args], { encoding: 'utf8' });
  const r = run('--render', '--dry-run', '--delay', 'abc');
  assert.equal(r.status, 2, r.stdout + r.stderr);
  assert.match(r.stderr, /--delay must be/);
  assert.equal(run('--render', '--dry-run', '--limit', 'abc').status, 2);
  assert.equal(run('--render', '--dry-run', '--profile', path.join(ROOT, 'profile')).status, 2);
});

test('attach mode refuses a download folder the Windows Chrome cannot see', async () => {
  const s = new Session({}, { browserURL: 'http://127.0.0.1:9222', downloadDir: '/home/u/.local/share/persistint-web-render/downloads' }, { log: () => {} });
  await assert.rejects(s.init(), /downloadDir .* is not visible to a Windows Chrome/);
});

test('debug HTML has script bodies, tokens and email addresses removed', () => {
  const html = '<html><head><script nonce="x">window.WIZ_global_data = {"SNlM0e":"AKlE_secret_token_123","oPEP7c":"me@example.com"};</script></head>'
    + '<body><div data-email="someone.else@gmail.com">Signed in as Some One (someone.else@gmail.com)</div><button aria-label="Send message"></button></body></html>';
  const out = redactHtml(html);
  assert.doesNotMatch(out, /secret_token|example\.com|gmail\.com/);
  assert.match(out, /aria-label="Send message"/);
  assert.match(out, /<script nonce="x">\/\* removed by web_render \*\/<\/script>/);
});

test('WSL <-> Windows path mapping for a Windows-side Chrome', () => {
  assert.equal(wslToWindows('/mnt/c/Users/brett/dl'), 'C:\\Users\\brett\\dl');
  assert.equal(wslToWindows('/home/brett'), null);
  assert.equal(windowsToWsl('C:\\Users\\brett\\dl'), '/mnt/c/Users/brett/dl');
  assert.equal(windowsToWsl('D:/x/y'), '/mnt/d/x/y');
  assert.equal(windowsToWsl('/home/x'), null);
});

test('prompt preparation adds the ratio only when the prompt lacks one', () => {
  const surface = { aspectInPrompt: true, promptSuffix: '{aspect} aspect ratio.' };
  assert.equal(preparePrompt({ prompt: 'A cat.', aspect: '16:9' }, surface), 'A cat. 16:9 aspect ratio.');
  assert.equal(preparePrompt({ prompt: 'A cat, 1:1 square.', aspect: '1:1' }, surface), 'A cat, 1:1 square.');
  assert.equal(preparePrompt({ prompt: 'A cat.', aspect: '16:9' }, { ...surface, aspectInPrompt: false }), 'A cat.');
  assert.equal(preparePrompt({ prompt: 'A cat.', aspect: '16:9' }, { promptPrefix: 'Generate an image:' }), 'Generate an image: A cat.');
});

test('every Gemini prompt carries @persistint-asset-prompts; only the image surface adds "Create an image:"; no on-page preview is saved as final', () => {
  // Author, 2026-10-24: the author's Gemini skill goes in every Gemini render prompt.
  const cfg = loadSelectors(SELECTORS_PATH);
  for (const [name, s] of Object.entries(cfg.surfaces)) {
    const want = !name.startsWith('gemini_') ? undefined
      : name === cfg.kinds.image ? '@persistint-asset-prompts Create an image:' : '@persistint-asset-prompts';
    assert.equal(s.promptPrefix, want, name);
  }
  assert.deepEqual(cfg.surfaces[cfg.kinds.image].capture, ['download']);
  assert.deepEqual(cfg.surfaces[cfg.kinds.music].capture, ['download']);
});

test('only a dedicated automation profile is accepted', () => {
  assert.doesNotThrow(() => assertDedicatedProfile(DEFAULTS.profileDir));
  for (const p of ['/home/u/.config/google-chrome', '/home/u/.config/chromium/Default', '/home/u/snap/chromium/common/chromium',
    'C:\\Users\\u\\AppData\\Local\\Google\\Chrome\\User Data']) {
    assert.throws(() => assertDedicatedProfile(p), /refusing/, p);
  }
  for (const p of ['/home/u/.config/microsoft-edge/Default', '/home/u/.config/vivaldi', '/home/u/.config/google-chrome-for-testing',
    'C:\\Users\\u\\AppData\\Local\\Microsoft\\Edge\\User Data', '/mnt/c/Users/u/AppData/Local/Google/Chrome/User Data']) {
    assert.throws(() => assertDedicatedProfile(p), /refusing/, p);
  }
  // a symlink that points at a normal profile is refused after resolving it
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-'));
  fs.mkdirSync(path.join(dir, '.config/google-chrome'), { recursive: true });
  fs.symlinkSync(path.join(dir, '.config/google-chrome'), path.join(dir, 'innocent'));
  assert.throws(() => assertDedicatedProfile(path.join(dir, 'innocent')), /refusing.*google-chrome/);
  assert.throws(() => assertDedicatedProfile(path.join(dir, 'innocent/Default')), /refusing/);
  // nothing inside the repo, not even through a symlink
  assert.throws(() => assertOutsideRepo(path.join(ROOT, 'profile'), 'profileDir'), /inside the repository/);
  assert.throws(() => assertOutsideRepo(path.join(ROOT, 'tools/web_render/downloads/x'), 'downloadDir'), /inside the repository/);
  fs.symlinkSync(ROOT, path.join(dir, 'repo-link'));
  assert.throws(() => assertOutsideRepo(path.join(dir, 'repo-link/p'), 'profileDir'), /inside the repository/);
  assert.doesNotThrow(() => assertOutsideRepo(DEFAULTS.profileDir, 'profileDir'));
  assert.doesNotThrow(() => assertOutsideRepo(DEFAULTS.downloadDir, 'downloadDir'));
  fs.rmSync(dir, { recursive: true, force: true });
});

test('imageSize reads PNG / JPEG / WebP headers and checkImage rejects previews and wrong ratios', () => {
  const png = (w, h, pad = 0) => {
    const b = Buffer.alloc(33 + pad);
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(b, 0);
    b.writeUInt32BE(13, 8); b.write('IHDR', 12, 'latin1'); b.writeUInt32BE(w, 16); b.writeUInt32BE(h, 20);
    return b;
  };
  assert.deepEqual(imageSize(png(2048, 1152)), { w: 2048, h: 1152, ext: '.png' });
  const jpg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x04, 0x00, 0x08, 0x00, 0x03, 0, 0, 0, 0, 0, 0]);
  assert.deepEqual(imageSize(jpg), { w: 2048, h: 1024, ext: '.jpg' });
  const webp = Buffer.alloc(30); webp.write('RIFF', 0, 'latin1'); webp.write('WEBPVP8X', 8, 'latin1');
  webp.writeUIntLE(1023, 24, 3); webp.writeUIntLE(1023, 27, 3);
  assert.deepEqual(imageSize(webp), { w: 1024, h: 1024, ext: '.webp' });
  assert.equal(imageSize(Buffer.from('<html>')), null);
  assert.deepEqual(checkImage(png(1024, 1024, 30_000), '1:1'), []);
  assert.match(checkImage(png(1024, 1024, 30_000), '16:9').join(), /is not 16:9/);
  assert.match(checkImage(png(256, 256, 30_000), '1:1').join(), /smaller than 512/);
  assert.match(checkImage(png(1024, 1024), '1:1').join(), /only 33 bytes/);
  assert.match(checkImage(Buffer.from('<!doctype html>'), '1:1').join(), /not a PNG/);
});

test('orPress and blocked are validated', () => {
  const good = JSON.parse(fs.readFileSync(SELECTORS_PATH, 'utf8'));
  const c = structuredClone(good);
  c.surfaces.gemini_image.steps.submit[0].orPress = '';
  assert.ok(validateSelectors(c).some((e) => /orPress/.test(e)));
  const d = structuredClone(good);
  d.surfaces.gemini_image.steps.blocked = [];
  assert.ok(validateSelectors(d).some((e) => /steps\.blocked/.test(e)));
});

// ---------------------------------------------------------------- Google's check page in batch mode

/** A page stand-in: on `url`, no results, and `visible` selectors each match one visible element. */
function fakePage(url, visible = []) {
  const handle = { boundingBox: async () => ({ x: 0, y: 0, width: 10, height: 10 }), evaluate: async () => true };
  return {
    url: () => url,
    $: async () => null,
    $$: async (sel) => (visible.includes(sel) ? [handle] : []),
    evaluateHandle: async () => ({ evaluate: async () => 0, dispose: async () => {} }),
  };
}

test('markIfBlocked turns a failure during check-page redirects into a blocked, run-stopping error', async () => {
  const { markIfBlocked } = await import('../lib/engine.mjs');
  const plain = markIfBlocked({ sorry: [] }, new Error('no download within 180s'));
  assert.equal(plain.blocked, undefined);
  const e = markIfBlocked({ sorry: ['request', 'console'] }, new Error('no download within 180s\nmore'));
  assert.equal(e.blocked, true);
  assert.equal(e.abortRun, true);
  assert.match(e.message, /^no download within 180s -- while Google was redirecting .*2x/);
});

test('checkPageShowing sees the reCAPTCHA iframe or a www.google.com/sorry tab, nothing else', async () => {
  const { checkPageShowing } = await import('../lib/engine.mjs');
  const sel = "iframe[title='reCAPTCHA']";
  assert.equal(await checkPageShowing(fakePage('https://gemini.google.com/app'), [sel]), null);
  assert.equal(await checkPageShowing(fakePage('https://gemini.google.com/app', [sel]), [sel]), sel);
  assert.match(await checkPageShowing(fakePage('https://www.google.com/sorry/index?continue=x'), [sel]), /sorry/);
});

test('batch harvest stops the run on a check page instead of calling the chat "not ready yet"', async () => {
  const { harvestAll } = await import('../lib/batch.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wr-batch-'));
  const file = path.join(dir, 'batch.json');
  const chat = 'https://gemini.google.com/app/0123456789abcdef';
  fs.writeFileSync(file, JSON.stringify({ track: { kind: 'music', chat, submitted: '2026-10-24T00:00:00Z' } }));
  const sel = "iframe[title='reCAPTCHA']";
  const page = fakePage(chat, [sel]);
  const session = { page, sorry: [], log: () => {}, newPage: async () => page };
  const surface = { url: 'https://gemini.google.com/app', steps: { result: ['audio'], busy: [], blocked: [sel] } };
  const logs = [];
  await assert.rejects(
    harvestAll(session, { tasks: [{ id: 'track', kind: 'music', drop_abs: path.join(dir, 'none.mp3') }], surfaceOf: () => surface, file, log: (m) => logs.push(m) }),
    (e) => e.blocked === true && e.abortRun === true,
  );
  assert.ok(!logs.some((m) => /not ready yet/.test(m)), logs.join('\n'));
  const after = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.equal(after.track.harvested, undefined);
  assert.equal(after.track.deleted, undefined);
  fs.rmSync(dir, { recursive: true, force: true });
});
