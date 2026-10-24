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
import { Session, DEBUG_DIR, capture, finish, resultInfo } from '../lib/engine.mjs';
import { sniffExt, imageSize, checkImage } from '../lib/media.mjs';
import image from '../drivers/image.mjs';
import video from '../drivers/video.mjs';
import music from '../drivers/music.mjs';
import { classifyOutcome, outcomePhrases } from '../lib/tracker.mjs';
import { loadSelectors } from '../lib/config.mjs';

const phrases = outcomePhrases(loadSelectors());

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
  fs.rmSync(tmp, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
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
  // Only this session's downloads are checked: the folder can briefly hold Chrome temp files of
  // other downloads (seen while another Chrome ran on the machine).
  const left = fs.readdirSync(path.join(tmp, 'downloads'));
  for (const guid of session.downloads.keys()) assert.ok(!left.includes(guid) && !left.includes(`${guid}.crdownload`), `temp download ${guid} was moved out`);
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
  broken.timeouts.readyMs = 1500;
  const t = task('smoke_broken', 'music', '.mp3');
  await assert.rejects(music.render(session, broken, t), (e) => {
    assert.equal(e.step, 'ready', 'a missing prompt box is caught while waiting for the page to hydrate');
    assert.equal(classifyOutcome(e, phrases), 'selector', 'tracker outcome');
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
    assert.equal(classifyOutcome(e, phrases), 'refused', 'tracker outcome');
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
    assert.equal(classifyOutcome(e, phrases), 'quota', 'tracker outcome');
    if (e.debugDir) fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
});

// ---------------------------------------------------------------- Google's check page

test('check page mid-generation (reCAPTCHA iframe) stops at wait as "blocked"', { skip: !chromeOk && skipReason, timeout: 60_000 }, async () => {
  const t = { ...task('smoke_captcha', 'image', '.png'), prompt: 'CAPTCHA this one.' };
  await assert.rejects(image.render(session, cfg.surfaces.fake_image, t), (e) => {
    assert.equal(e.step, 'wait');
    assert.equal(e.blocked, true);
    assert.equal(e.abortRun, true);
    assert.match(e.message, /check page.*inspect\.mjs --keep 300/);
    assert.equal(classifyOutcome(e, phrases), 'blocked', 'tracker outcome');
    if (e.debugDir) fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
  assert.ok(!fs.existsSync(t.drop_abs));
});

test('download redirected to www.google.com/sorry fails at once as "blocked", not after downloadMs', { skip: !chromeOk && skipReason, timeout: 60_000 }, async () => {
  const t = { ...task('smoke_sorry', 'image', '.png'), prompt: 'SORRY this one.' };
  let t0;
  const surface = { ...cfg.surfaces.fake_image, capture: ['download'] };
  await assert.rejects((async () => { t0 = Date.now(); return image.render(session, surface, t); })(), (e) => {
    assert.equal(e.step, 'capture');
    assert.equal(e.blocked, true);
    assert.equal(e.abortRun, true);
    assert.match(e.message, /google\.com\/sorry/);
    assert.equal(classifyOutcome(e, phrases), 'blocked');
    if (e.debugDir) fs.rmSync(e.debugDir, { recursive: true, force: true });
    return true;
  });
  assert.ok(Date.now() - t0 < 12_000, `took ${Date.now() - t0} ms (downloadMs is 15 s; generation 1.5 s)`);
  assert.ok(!fs.existsSync(t.drop_abs));
});

// ---------------------------------------------------------------- the live image result DOM

test('gemini_image (real selectors.json) captures from the live result DOM: hover, Download full size, verify, PNG', { skip: !chromeOk && skipReason, timeout: 120_000 }, async () => {
  const real = loadSelectors().surfaces.gemini_image;
  await session.newPage();
  await session.goto(pathToFileURL(path.join(HERE, 'fixtures/gemini_image_result.html')).href);
  // Stand in for the app: a loaded preview in the <img>, and a full-size JPEG (16:9, noisy so it
  // is well over 20 KB) saved as a browser download when the real download button is clicked.
  await session.page.evaluate(async () => {
    const draw = (w, h) => {
      const c = document.createElement('canvas'); c.width = w; c.height = h;
      const g = c.getContext('2d'); const d = g.createImageData(w, h);
      for (let i = 0; i < d.data.length; i += 4) { d.data[i] = (i * 7) % 255; d.data[i + 1] = Math.random() * 255; d.data[i + 2] = 180; d.data[i + 3] = 255; }
      g.putImageData(d, 0, 0); return c;
    };
    const img = document.querySelector('generated-image img.image');
    img.src = draw(688, 384).toDataURL('image/png');
    await img.decode();
    const full = await new Promise((r) => draw(1376, 768).toBlob(r, 'image/jpeg', 0.92));
    window.__clicks = 0;
    document.querySelector("download-generated-image-button button[aria-label='Download full size image']").addEventListener('click', () => {
      window.__clicks++;
      const a = document.createElement('a'); a.href = URL.createObjectURL(full); a.download = 'Gemini_Generated_Image.jpeg'; document.body.appendChild(a); a.click(); a.remove();
    });
  });
  const surface = { ...real, timeouts: { ...real.timeouts, stepMs: 5000, downloadMs: 20_000 } };
  const info = await resultInfo(session.page, real.steps.result, real.resultMinSize);
  assert.equal(info.count, 1, 'the generated <img> is the result (avatars and icons are not)');
  assert.equal(info.tag, 'img');
  const got = await capture(session, surface, { vars: { aspect: '16:9' }, stepMs: 5000 });
  assert.equal(got.route, 'download');
  assert.equal(await session.page.evaluate(() => window.__clicks), 1, 'the Download full size button was clicked once');
  assert.equal(sniffExt(got.buf), '.jpg');
  const t = { ...task('smoke_gemini_dom', 'image', '.png'), aspect: '16:9' };
  const r = await finish(session, t, got, surface);
  const buf = fs.readFileSync(t.drop_abs);
  assert.equal(sniffExt(buf), '.png', 're-encoded to PNG');
  assert.deepEqual(imageSize(buf), { w: 1376, h: 768, ext: '.png' });
  assert.deepEqual(checkImage(buf, '16:9'), [], 'passes the default image checks (>= 20 KB, >= 512 px, ratio)');
  assert.equal(r.route, 'download');
});
