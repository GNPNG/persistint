// Tracker mode without network or browser: lib/tracker.mjs and render.mjs against a local mock
// of the Apps Script web app (tests/mock_tracker.mjs) on a fake clock.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { inspect, promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { startMockTracker } from './mock_tracker.mjs';
import {
  TrackerClient, TrackerError, LocalAttemptsLog, ATTEMPT_FIELDS, classifyOutcome, outcomePhrases,
  promptDiffNote, runTrackerLoop, checkTrackerUrl, redact,
} from '../lib/tracker.mjs';
import { StepError } from '../lib/engine.mjs';
import { loadSelectors, validateTracker, publicSettings, DEFAULTS } from '../lib/config.mjs';
import { discoverTasks } from '../lib/tasks.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RENDER = path.join(HERE, '..', 'render.mjs');
const SECRET = 'S3cr3t-' + 'x'.repeat(40) + '/+=&';   // URL-unsafe characters on purpose
const T0 = Date.parse('2026-10-23T08:00:00Z');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'webrender-tracker-'));
after(() => fs.rmSync(tmp, { recursive: true, force: true }));

const phrases = outcomePhrases(loadSelectors());
const task = (id, kind, extra = {}) => ({ id, kind, prompt: `prompt for ${id}`, drop: `prompts/x/${id}.png`, md_path: `prompts/x/${id}.md`, exists: false, beside: null, ...extra });
const row = (asset_id, kind, extra = {}) => ({ asset_id, kind, prompt: `prompt for ${asset_id}`, ...extra });

async function setup({ quotas = {}, rows = [] } = {}) {
  const clock = { t: T0 };
  const mock = await startMockTracker({ secret: SECRET, clock, quotas, rows });
  const client = new TrackerClient({ url: mock.url, secret: SECRET, allowLoopbackHttp: true, retries: 0 });
  const logs = [];
  const base = {
    client, now: () => clock.t, sleep: async (ms) => { clock.t += ms; }, log: (m) => logs.push(String(m)),
    phrases, runId: 'test-run',
  };
  return { mock, client, clock, logs, base };
}

const limitError = () => Object.assign(new StepError('wait', 'usage limit notice on the page (x): "You have reached your limit"'), { abortRun: true });
const timeoutError = () => new StepError('wait', 'no new result within 600s');
const selectorError = () => new StepError('mode[1] pick Create images', 'none of these matched a visible element: ::-p-text(Create images)');

test('client: queue polling, attempt_start / attempt_end through the 302 redirect, kind filter', async () => {
  const { mock, client } = await setup({ rows: [row('a1', 'image'), row('m1', 'music')] });
  try {
    const q = await client.getQueue();
    assert.deepEqual(q.rows.map((r) => r.asset_id), ['a1', 'm1']);
    assert.equal(q.kinds.image.remaining_today, 20);
    assert.equal(q.kinds.image.ready, true);
    const qi = await client.getQueue({ kind: 'image' });
    assert.deepEqual(Object.keys(qi.kinds), ['image']);
    assert.deepEqual(qi.rows.map((r) => r.asset_id), ['a1']);
    const s = await client.start({ asset_id: 'a1', kind: 'image' });
    assert.equal(s.status, 'Rendering');
    const e = await client.end({ asset_id: 'a1', kind: 'image' }, { outcome: 'done', file: 'prompts/x/a1.png', runId: 'r1', surface: 'gemini web: gemini_image' });
    assert.equal(e.status, 'Done');
    assert.equal(mock.row('a1').renderedFile, 'prompts/x/a1.png');
    assert.equal(mock.state.attempts[0].run_id, 'r1');
    assert.deepEqual((await client.getQueue()).rows.map((r) => r.asset_id), ['m1']);
    // all=0: a kind inside its min gap is left out
    assert.deepEqual((await client.getQueue({ all: false })).rows.map((r) => r.asset_id), ['m1']);
    await assert.rejects(client.end({ asset_id: 'a1', kind: 'image' }, { outcome: 'bogus' }), /unknown outcome/);
  } finally { await mock.close(); }
});

test('throttling: Min Gap per kind is honoured between renders', async () => {
  const { mock, clock, base } = await setup({ quotas: { image: { minGap: 90 } }, rows: ['i1', 'i2', 'i3'].map((id) => row(id, 'image')) });
  try {
    const at = [];
    const out = await runTrackerLoop({ ...base, tasks: ['i1', 'i2', 'i3'].map((id) => task(id, 'image')),
      renderOne: async () => { at.push(clock.t); clock.t += 30_000; return { bytes: 1 }; } });
    assert.equal(out.results.length, 3);
    assert.ok(out.results.every((r) => r.outcome === 'done'));
    for (let i = 1; i < at.length; i++) assert.ok(at[i] - (at[i - 1] + 30_000) >= 90_000, `gap ${i}: ${(at[i] - at[i - 1] - 30_000) / 1000}s`);
    assert.equal(out.reason, 'empty');
    assert.deepEqual(mock.state.rows.map((r) => r.status), ['Done', 'Done', 'Done']);
  } finally { await mock.close(); }
});

test('throttling: Daily Cap stops a kind; other kinds go on; kinds interleave', async () => {
  const { mock, base } = await setup({
    quotas: { image: { dailyCap: 2, minGap: 10 }, music: { minGap: 10 } },
    rows: [...['i1', 'i2', 'i3', 'i4'].map((id) => row(id, 'image')), row('m1', 'music'), row('m2', 'music')],
  });
  try {
    const order = [];
    const out = await runTrackerLoop({ ...base, tasks: [...['i1', 'i2', 'i3', 'i4'].map((id) => task(id, 'image')), task('m1', 'music'), task('m2', 'music')],
      renderOne: async (t) => { order.push(t.id); return {}; } });
    assert.deepEqual(order.filter((id) => id.startsWith('i')), ['i1', 'i2']);
    assert.deepEqual(order.filter((id) => id.startsWith('m')), ['m1', 'm2']);
    assert.notDeepEqual(order, ['i1', 'i2', 'm1', 'm2'], 'kinds take turns');
    assert.equal(out.reason, 'cap');
    assert.deepEqual(out.capped, ['image']);
    assert.equal(mock.row('i3').status, 'Pending');
  } finally { await mock.close(); }
});

test('quota outcome stops that kind for the run; the sheet gets Quota + cooldown', async () => {
  const { mock, clock, base } = await setup({ quotas: { image: { minGap: 5 }, music: { minGap: 5 } },
    rows: [row('i1', 'image'), row('i2', 'image'), row('m1', 'music'), row('m2', 'music')] });
  try {
    const rendered = [];
    const out = await runTrackerLoop({ ...base, tasks: [task('i1', 'image'), task('i2', 'image'), task('m1', 'music'), task('m2', 'music')],
      renderOne: async (t) => { rendered.push(t.id); if (t.kind === 'image') throw limitError(); return {}; } });
    assert.deepEqual(rendered.filter((id) => id.startsWith('i')), ['i1'], 'no second image after the quota hit');
    assert.deepEqual(rendered.filter((id) => id.startsWith('m')), ['m1', 'm2']);
    assert.deepEqual(out.stopped, ['image']);
    const r = mock.row('i1');
    assert.equal(r.status, 'Quota');
    assert.equal(r.lastOutcome, 'quota');
    assert.ok(r.nextEligible.getTime() >= clock.t + 200 * 60_000);
    assert.equal(mock.row('i2').status, 'Pending');
  } finally { await mock.close(); }
});

test('retry eligibility: a timeout is retried after the backoff in the same run', async () => {
  const { mock, base } = await setup({ quotas: { image: { minGap: 10, backoff: 120 } }, rows: [row('i1', 'image')] });
  try {
    let n = 0;
    const out = await runTrackerLoop({ ...base, tasks: [task('i1', 'image')], maxWaitSec: 1800,
      renderOne: async () => { if (n++ === 0) throw timeoutError(); return {}; } });
    assert.deepEqual(out.results.map((r) => r.outcome), ['timeout', 'done']);
    assert.equal(mock.row('i1').status, 'Done');
    assert.equal(mock.row('i1').attempts, 2);
    assert.deepEqual(mock.state.attempts.map((a) => a.outcome), ['timeout', 'done']);
  } finally { await mock.close(); }
});

test('retries stop at Max Retries; a later retry than maxWaitSec ends the run with its time', async () => {
  const { mock, base } = await setup({ quotas: { image: { minGap: 10, backoff: 60, maxRetries: 3 } }, rows: [row('i1', 'image')] });
  try {
    const out = await runTrackerLoop({ ...base, tasks: [task('i1', 'image')], renderOne: async () => { throw selectorError(); } });
    assert.deepEqual(out.results.map((r) => r.outcome), ['selector', 'selector', 'selector']);
    assert.equal(mock.row('i1').status, 'Failed');
    assert.equal(mock.row('i1').nextEligible, null, 'retries exhausted');
    assert.equal(out.reason, 'empty');
  } finally { await mock.close(); }

  const s2 = await setup({ quotas: { image: { minGap: 10, backoff: 3600 } }, rows: [row('i1', 'image')] });
  try {
    const out = await runTrackerLoop({ ...s2.base, tasks: [task('i1', 'image')], maxWaitSec: 600, renderOne: async () => { throw timeoutError(); } });
    assert.equal(out.results.length, 1);
    assert.equal(out.reason, 'later');
    assert.equal(out.nextEligible, s2.mock.row('i1').nextEligible.getTime());
    assert.equal(out.wakes[0].why, 'retry backoff');
  } finally { await s2.mock.close(); }
});

test('repo prompt wins: a differing sheet prompt is noted; unknown ids skipped; existing drops marked done', async () => {
  const { mock, base } = await setup({ quotas: { image: { minGap: 1 } },
    rows: [row('i1', 'image', { prompt: 'an OLD sheet prompt' }), row('ghost', 'image'), row('have', 'image')] });
  try {
    const got = [];
    const out = await runTrackerLoop({ ...base, tasks: [task('i1', 'image'), task('have', 'image', { exists: true })],
      renderOne: async (t) => { got.push(t.prompt); return {}; } });
    assert.deepEqual(got, ['prompt for i1'], 'only i1 is generated, with the repo prompt');
    assert.match(mock.row('i1').notes, /differs from prompts\/x\/i1\.md; rendered the repo prompt/);
    assert.equal(mock.state.attempts.find((a) => a.id === 'i1').note.length > 0, true);
    assert.equal(mock.row('ghost').status, 'Skipped');
    assert.match(mock.row('ghost').lastError, /no prompt file/);
    assert.equal(mock.row('have').status, 'Done');
    assert.equal(mock.row('have').renderedFile, 'prompts/x/have.png');
    assert.equal(out.results.length, 3);
    assert.equal(promptDiffNote('  same   text ', 'same text'), '');
    assert.equal(promptDiffNote('', 'x'), '');
  } finally { await mock.close(); }
});

test('a stale Rendering row (renderer died mid-asset) is offered again after 120 min', async () => {
  const { mock, client, clock } = await setup({ rows: [row('i1', 'image')] });
  try {
    await client.start({ asset_id: 'i1', kind: 'image' });
    assert.deepEqual((await client.getQueue()).rows, []);
    clock.t += 121 * 60_000;
    assert.deepEqual((await client.getQueue()).rows.map((r) => r.asset_id), ['i1']);
  } finally { await mock.close(); }
});

test('outcome mapping from the renderer\'s errors', () => {
  assert.equal(classifyOutcome({ bytes: 3 }, phrases), 'done');
  assert.equal(classifyOutcome({ skipped: true }, phrases), 'skipped');
  assert.equal(classifyOutcome(limitError(), phrases), 'quota');
  const textOnly = (txt) => Object.assign(new StepError('wait', `the reply finished without any media after 90s: "${txt}"`), { textOnly: true, replyText: txt });
  assert.equal(classifyOutcome(textOnly("Sorry, I can't generate that image because it may violate our policies."), phrases), 'refused');
  assert.equal(classifyOutcome(textOnly('I can’t create images of that.'), phrases), 'refused', 'curly apostrophe');
  assert.equal(classifyOutcome(textOnly("You've reached your limit for video generation. Your limit resets tomorrow."), phrases), 'quota');
  assert.equal(classifyOutcome(textOnly('Sign in to continue'), phrases), 'failed', 'a signed-out page is retried, not parked');
  assert.equal(classifyOutcome(new StepError('wait', 'the reply finished without any media after 90s: "I can\'t generate that"'), phrases), 'refused', 'message only (no replyText)');
  assert.equal(classifyOutcome(timeoutError(), phrases), 'timeout');
  assert.equal(classifyOutcome(new StepError('capture', 'download: no completed download within 180s'), phrases), 'timeout');
  assert.equal(classifyOutcome(Object.assign(new Error('Navigation timeout of 120000 ms exceeded'), { name: 'TimeoutError' }), phrases), 'timeout');
  assert.equal(classifyOutcome(selectorError(), phrases), 'selector');
  assert.equal(classifyOutcome(new StepError('download[0]', 'no result element to act on'), phrases), 'selector');
  assert.equal(classifyOutcome(new Error('captured bytes are not a media file'), phrases), 'failed');
  assert.ok(phrases.quota.includes('reached your limit'), 'quota phrases come from limitNotice');
});

test('https only: tracker URLs and redirects', async () => {
  assert.throws(() => checkTrackerUrl('http://script.google.com/macros/s/x/exec'), /https/);
  assert.throws(() => checkTrackerUrl('http://127.0.0.1:1/exec'), /https/);
  assert.ok(checkTrackerUrl('http://127.0.0.1:1/exec', { allowLoopbackHttp: true }));
  assert.throws(() => checkTrackerUrl('http://example.com/exec', { allowLoopbackHttp: true }), /https/);
  assert.ok(checkTrackerUrl('https://script.google.com/macros/s/x/exec'));
  // a redirect to plain http is refused
  const fetchImpl = async () => new Response(null, { status: 302, headers: { location: 'http://evil.example/x' } });
  const c = new TrackerClient({ url: 'https://script.google.com/macros/s/x/exec', secret: SECRET, fetchImpl, retries: 0 });
  await assert.rejects(c.getQueue(), /must be https/);
  // an HTML page (web app not shared / not authorized) is explained, not echoed
  const html = new TrackerClient({ url: 'https://script.google.com/macros/s/x/exec', secret: SECRET, retries: 0,
    fetchImpl: async () => new Response(`<html>Sign in ${SECRET}</html>`, { status: 200, headers: { 'content-type': 'text/html' } }) });
  await assert.rejects(html.getQueue(), (e) => /not JSON but an HTML page/.test(e.message) && !e.message.includes(SECRET));
  assert.deepEqual(validateTracker({ ...DEFAULTS }), []);
  assert.match(validateTracker({ ...DEFAULTS, trackerUrl: 'http://x.example/exec', trackerSecret: SECRET }).join(), /https/);
  assert.match(validateTracker({ ...DEFAULTS, trackerUrl: 'https://x.example/exec' }).join(), /trackerSecret is not/);
  assert.match(validateTracker({ ...DEFAULTS, trackerUrl: 'https://x.example/exec', trackerSecret: 'short' }).join(), /at least 32/);
});

test('the secret is never printed: errors, inspect, JSON, loop logs, run-log settings', async () => {
  const { mock, base, logs } = await setup({ rows: [row('i1', 'image')] });
  try {
    const seen = [];
    const wrong = new TrackerClient({ url: mock.url, secret: SECRET + 'X', allowLoopbackHttp: true, retries: 0 });
    await assert.rejects(wrong.getQueue(), (e) => { seen.push(e.message, e.stack); return /unauthorized/.test(e.message); });
    const dead = new TrackerClient({ url: 'http://127.0.0.1:9/exec', secret: SECRET, allowLoopbackHttp: true, retries: 1, retryDelayMs: 1 });
    await assert.rejects(dead.getQueue(), (e) => { seen.push(e.message, e.stack); return /network error/.test(e.message); });
    seen.push(inspect(base.client), JSON.stringify(base.client), JSON.stringify(publicSettings({ ...DEFAULTS, trackerSecret: SECRET })));
    // an error text that happens to contain the secret is redacted before it reaches the sheet
    await runTrackerLoop({ ...base, tasks: [task('i1', 'image')], renderOne: async () => { throw new Error(`boom ${SECRET}`); } });
    seen.push(...logs, ...mock.state.attempts.map((a) => a.error), mock.row('i1').lastError);
    for (const s of seen) {
      assert.ok(!String(s).includes(SECRET), `secret leaked in: ${String(s).slice(0, 120)}`);
      assert.ok(!String(s).includes(encodeURIComponent(SECRET)), `encoded secret leaked in: ${String(s).slice(0, 120)}`);
    }
    assert.match(mock.row('i1').lastError, /boom \[secret\]/);
    assert.equal(redact(`a ${SECRET} b`, SECRET), 'a [secret] b');
  } finally { await mock.close(); }
});

test('offline fallback: LocalAttemptsLog writes the Attempts fields as JSONL, numbering attempts per asset', async () => {
  const file = path.join(tmp, 'runs', 'attempts.jsonl');
  let t = T0;
  const log1 = new LocalAttemptsLog(file, { now: () => t });
  await log1.start({ id: 'a', kind: 'image' });
  t += 42_000;
  await log1.end({ id: 'a', kind: 'image' }, { outcome: 'timeout', error: 'no new result', debugDir: 'tools/web_render/debug/a', runId: 'r', surface: 's' });
  const log2 = new LocalAttemptsLog(file, { now: () => t });   // a later run continues the numbering
  await log2.end({ id: 'a', kind: 'image' }, { outcome: 'done', file: 'prompts/x/a.png', runId: 'r2', surface: 's' });
  await assert.rejects(log2.end({ id: 'a', kind: 'image' }, { outcome: 'nope' }), TrackerError);
  const lines = fs.readFileSync(file, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  assert.equal(lines.length, 2);
  for (const l of lines) assert.deepEqual(Object.keys(l), ATTEMPT_FIELDS);
  assert.deepEqual(lines.map((l) => [l.attempt, l.outcome]), [[1, 'timeout'], [2, 'done']]);
  assert.equal(lines[0].duration_s, 42);
  assert.equal(lines[0].debug_dir, 'tools/web_render/debug/a');

  // the tracker loop mirrors every attempt into the same JSONL format
  const { mock, base } = await setup({ rows: [row('i1', 'image')] });
  try {
    const mirror = path.join(tmp, 'mirror.jsonl');
    await runTrackerLoop({ ...base, tasks: [task('i1', 'image')], localLog: new LocalAttemptsLog(mirror, { now: base.now }), renderOne: async () => ({}) });
    const m = JSON.parse(fs.readFileSync(mirror, 'utf8').trim());
    assert.deepEqual(Object.keys(m), ATTEMPT_FIELDS);
    assert.equal(m.outcome, 'done');
    assert.equal(m.run_id, 'test-run');
  } finally { await mock.close(); }
});

// ---------------------------------------------------------------- render.mjs CLI

const run = promisify(execFile);
async function cli(args, env = {}) {
  try {
    const r = await run(process.execPath, [RENDER, ...args], {
      env: { ...process.env, WEB_RENDER_CONFIG: path.join(tmp, 'no-config.json'), WEB_RENDER_RUNS_DIR: path.join(tmp, 'cli-runs'),
        WEB_RENDER_TRACKER_URL: '', WEB_RENDER_TRACKER_SECRET: '', ...env },
      timeout: 60_000,
    });
    return { code: 0, out: r.stdout + r.stderr };
  } catch (e) { return { code: e.code, out: (e.stdout || '') + (e.stderr || '') }; }
}

test('CLI: --tracker without a configured tracker exits 2; --render without one stays local', async () => {
  const r = await cli(['--tracker']);
  assert.equal(r.code, 2);
  assert.match(r.out, /No render tracker configured/);
  const d = await cli(['--render', '--dry-run', '--only', 'app_icon']);
  assert.equal(d.code, 0);
  assert.match(d.out, /\[image\] app_icon -> prompts\/image\/ui\/icon\/assets\/app_icon\.png/);
  const bad = await cli(['--queue'], { WEB_RENDER_TRACKER_URL: 'http://127.0.0.1:9/exec', WEB_RENDER_TRACKER_SECRET: SECRET });
  assert.equal(bad.code, 2, 'plain http is refused outside tests');
  assert.match(bad.out, /must be https/);
});

test('CLI: --queue and --render --dry-run read the mock tracker; the secret never appears', async () => {
  const ids = discoverTasks(undefined, { warn: () => {} });
  const img = ids.find((t) => t.kind === 'image' && !t.exists && !t.beside);
  const mus = ids.find((t) => t.kind === 'music' && !t.exists && !t.beside);
  const mock = await startMockTracker({ secret: SECRET, rows: [
    { asset_id: img.id, kind: 'image', prompt: 'a different sheet prompt' },
    { asset_id: mus.id, kind: 'music', prompt: mus.prompt },
  ] });
  const env = { WEB_RENDER_TRACKER_URL: mock.url, WEB_RENDER_TRACKER_SECRET: SECRET, WEB_RENDER_TRACKER_ALLOW_LOOPBACK_HTTP: '1' };
  try {
    const q = await cli(['--queue'], env);
    assert.equal(q.code, 0, q.out);
    assert.match(q.out, /image\s+eligible\s+1\s+used 0\/20 today/);
    assert.ok(q.out.includes(img.id) && q.out.includes(mus.id));
    const d = await cli(['--render', '--dry-run'], env);   // --render picks tracker mode when configured
    assert.equal(d.code, 0, d.out);
    assert.match(d.out, /dry run: nothing is rendered/);
    assert.match(d.out, new RegExp(`\\[image\\] ${img.id} -> .*\\n  note: prompt in sheet differs`));
    assert.match(d.out, new RegExp(`\\[music\\] ${mus.id} -> `));
    assert.ok(!mock.state.requests.some((r) => r.method === 'POST'), 'a dry run writes nothing');
    const l = await cli(['--render', '--dry-run', '--local', '--only', img.id], env);
    assert.doesNotMatch(l.out, /Tracker/);
    const dead = await cli(['--queue'], { ...env, WEB_RENDER_TRACKER_URL: 'http://127.0.0.1:9/exec' });
    assert.equal(dead.code, 1);
    for (const o of [q.out, d.out, l.out, dead.out]) {
      assert.ok(!o.includes(SECRET) && !o.includes(encodeURIComponent(SECRET)), 'secret in CLI output');
    }
  } finally { await mock.close(); }
});

test('CLI: a tracker run reports to the sheet, writes the run log and JSONL, and never the secret', async () => {
  const mock = await startMockTracker({ secret: SECRET, quotas: { image: { minGap: 1 } }, rows: [{ asset_id: 'no_such_asset', kind: 'image' }] });
  const env = { WEB_RENDER_TRACKER_URL: mock.url, WEB_RENDER_TRACKER_SECRET: SECRET, WEB_RENDER_TRACKER_ALLOW_LOOPBACK_HTTP: '1' };
  try {
    const r = await cli(['--render', '--kind', 'image'], env);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /Tracker mode \(kind=image\)/);
    assert.match(r.out, /1 skipped/);
    assert.equal(mock.row('no_such_asset').status, 'Skipped');
    const runs = path.join(tmp, 'cli-runs');
    const files = fs.readdirSync(runs);
    assert.ok(files.includes('attempts.jsonl'));
    const runLog = files.find((f) => f.endsWith('.json'));
    const text = fs.readFileSync(path.join(runs, runLog), 'utf8') + fs.readFileSync(path.join(runs, 'attempts.jsonl'), 'utf8') + r.out;
    assert.ok(!text.includes(SECRET), 'secret in run log / JSONL / output');
    assert.equal(JSON.parse(fs.readFileSync(path.join(runs, runLog), 'utf8')).settings.trackerSecret, '[set]');
  } finally { await mock.close(); }
});
