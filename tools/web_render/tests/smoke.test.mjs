// End-to-end smoke test against a local fake of the Gemini page (tests/fixtures/fake_gemini.html).
// Starts a real headful Chrome on a throwaway profile (needs a display, e.g. WSLg DISPLAY=:0),
// attaches with puppeteer.connect exactly as render.mjs does, and runs the image (download
// button via CDP), video (two-step Share > Download menu) and music (in-page fetch of the
// blob: src) drivers, then a deliberately broken surface to check the debug dump.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { validateSelectors } from '../lib/config.mjs';
import { findChrome, launchAndConnect } from '../lib/browser.mjs';
import { Session, DEBUG_DIR } from '../lib/engine.mjs';
import { sniffExt } from '../lib/media.mjs';
import image from '../drivers/image.mjs';
import video from '../drivers/video.mjs';
import music from '../drivers/music.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE = pathToFileURL(path.join(HERE, 'fixtures/fake_gemini.html')).href;
const cfg = JSON.parse(fs.readFileSync(path.join(HERE, 'fixtures/fake_selectors.json'), 'utf8').replaceAll('{fixture}', FIXTURE));

let chromeOk = true, skipReason = '';
try { findChrome(process.env.WEB_RENDER_CHROME); } catch (e) { chromeOk = false; skipReason = e.message; }
if (!process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) { chromeOk = false; skipReason = 'no DISPLAY for a headful browser'; }

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-smoke-'));
let b, session;
const logs = [];
const log = (m) => { logs.push(m); console.log(m); };

before(async () => {
  if (!chromeOk) return;
  const settings = {
    chrome: process.env.WEB_RENDER_CHROME || null,
    profileDir: path.join(tmp, 'profile'),
    downloadDir: path.join(tmp, 'downloads'),
    launchTimeoutSec: 120,
  };
  b = await launchAndConnect({ ...settings, log });
  session = new Session(b.browser, settings, { log, allowFileUrls: true });
  await session.init();
});

after(async () => {
  if (b) await b.close();
  fs.rmSync(tmp, { recursive: true, force: true });
});

const task = (id, kind, ext) => ({
  id, kind, aspect: '16:9', prompt: `A pink seashell for ${id}, kawaii pixel art.`,
  drop: `prompts/test/${id}${ext}`, drop_abs: path.join(tmp, 'drops', `${id}${ext}`),
});

test('fake selectors config is valid (file:// allowed only for the test)', () => {
  assert.deepEqual(validateSelectors(cfg, { allowFileUrls: true }), []);
  assert.ok(validateSelectors(cfg).some((e) => /only https/.test(e)));
});

test('image: mode menu, execCommand input, fallback submit, wait, hover + download button', { skip: !chromeOk && skipReason, timeout: 180_000 }, async () => {
  const t = task('smoke_image', 'image', '.png');
  const r = await image.render(session, cfg.surfaces.fake_image, t);
  assert.equal(r.route, 'download');
  const buf = fs.readFileSync(t.drop_abs);
  assert.equal(sniffExt(buf), '.png');
  assert.ok(buf.length > 1000, `png is ${buf.length} bytes`);
  const sent = await session.page.evaluate(() => window.__prompts);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].mode, 'image');
  assert.equal(sent[0].prompt, 'Generate an image: A pink seashell for smoke_image, kawaii pixel art. 16:9 aspect ratio.');
  assert.ok(logs.some((l) => /matched fallback #2: ::-p-aria\(Send message\)/.test(l)), 'submit fallback was used');
});

test('video: Share > Download video menu through CDP download events', { skip: !chromeOk && skipReason, timeout: 180_000 }, async () => {
  const t = task('smoke_video', 'video', '.mp4');
  const r = await video.render(session, cfg.surfaces.fake_video, t);
  assert.equal(r.route, 'download');
  assert.equal(sniffExt(fs.readFileSync(t.drop_abs)), '.mp4');
  assert.deepEqual(fs.readdirSync(path.join(tmp, 'downloads')), [], 'temp download was moved out');
});

test('music: in-page fetch of the blob: src', { skip: !chromeOk && skipReason, timeout: 180_000 }, async () => {
  const t = task('smoke_music', 'music', '.mp3');
  const r = await music.render(session, cfg.surfaces.fake_music, t);
  assert.equal(r.route, 'src');
  assert.equal(sniffExt(fs.readFileSync(t.drop_abs)), '.mp3');
});

test('a broken selector fails at its step and leaves screenshot, HTML and console log', { skip: !chromeOk && skipReason, timeout: 180_000 }, async () => {
  const broken = structuredClone(cfg.surfaces.fake_music);
  broken.steps.input = ['#no-such-input'];
  broken.timeouts.stepMs = 1500;
  const t = task('smoke_broken', 'music', '.mp3');
  await assert.rejects(music.render(session, broken, t), (e) => {
    assert.equal(e.step, 'input');
    assert.ok(e.debugDir && e.debugDir.startsWith(DEBUG_DIR));
    for (const f of ['screenshot.png', 'page.html', 'console.log', 'error.txt']) assert.ok(fs.existsSync(path.join(e.debugDir, f)), f);
    const html = fs.readFileSync(path.join(e.debugDir, 'page.html'), 'utf8');
    assert.match(html, /Fake Gemini/);
    assert.match(html, /removed by web_render/);
    assert.doesNotMatch(html, /window\.__prompts = \[\]/, 'script bodies are stripped from the debug HTML');
    fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
  assert.ok(!fs.existsSync(t.drop_abs));
});

test('a text-only reply (refusal) fails fast at wait with the reply text, without waiting out generateMs', { skip: !chromeOk && skipReason, timeout: 60_000 }, async () => {
  const t = { ...task('smoke_refuse', 'music', '.mp3'), prompt: 'REFUSE this one.' };
  const t0 = Date.now();
  await assert.rejects(music.render(session, cfg.surfaces.fake_music, t), (e) => {
    assert.equal(e.step, 'wait');
    assert.match(e.message, /finished without any media.*can't generate that/);
    assert.ok(!e.abortRun);
    if (e.debugDir) fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
  assert.ok(Date.now() - t0 < 20_000, `took ${Date.now() - t0} ms (generateMs is 30 s)`);
  assert.ok(!fs.existsSync(t.drop_abs));
});

test('a usage-limit notice fails at wait and asks the run to stop', { skip: !chromeOk && skipReason, timeout: 60_000 }, async () => {
  const t = { ...task('smoke_limit', 'music', '.mp3'), prompt: 'LIMIT this one.' };
  await assert.rejects(music.render(session, cfg.surfaces.fake_music, t), (e) => {
    assert.equal(e.step, 'wait');
    assert.match(e.message, /usage limit notice.*reached your limit/);
    assert.equal(e.abortRun, true);
    if (e.debugDir) fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
});
