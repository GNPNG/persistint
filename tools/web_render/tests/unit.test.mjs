// Browser-free tests: parsing parity with tools/render_all_assets.py, selectors.json validation,
// drop path / extension mapping, format sniffing, path mapping, prompt preparation.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { ROOT, discoverTasks, parsePromptText, dropFormat, selectTasks, KIND_EXT } from '../lib/tasks.mjs';
import { loadSelectors, validateSelectors, assertDedicatedProfile, SELECTORS_PATH, DEFAULTS } from '../lib/config.mjs';
import { sniffExt, saveToDrop, hasFfmpeg, wslToWindows, windowsToWsl } from '../lib/media.mjs';
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

test('only a dedicated automation profile is accepted', () => {
  assert.doesNotThrow(() => assertDedicatedProfile(DEFAULTS.profileDir));
  for (const p of ['/home/u/.config/google-chrome', '/home/u/.config/chromium/Default', '/home/u/snap/chromium/common/chromium',
    'C:\\Users\\u\\AppData\\Local\\Google\\Chrome\\User Data']) {
    assert.throws(() => assertDedicatedProfile(p), /refusing/, p);
  }
});
