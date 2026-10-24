#!/usr/bin/env node
// Render the asset prompts in prompts/ through the Gemini web app (AI Ultra), driving a real
// Chrome on a dedicated profile with Puppeteer. See README.md in this folder.
import fs from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { ROOT, WEB_RENDER_DIR, discoverTasks, selectTasks, formatStatus, dropFormat } from './lib/tasks.mjs';
import { loadSettings, loadSelectors, SELECTORS_PATH, SettingsError, parseLimit, parseDelay, publicSettings, trackerAllowsLoopbackHttp } from './lib/config.mjs';

const HELP = `Usage: node tools/web_render/render.mjs <mode> [options]

Modes
  --status                 rendered vs missing, per asset (default)
  --check-selectors        validate selectors.json and exit
  --login                  open the dedicated Chrome profile so you can sign in to Google once
  --render                 render in the browser (automatic). With a tracker configured
                           (trackerUrl + trackerSecret) this is tracker mode, see --tracker;
                           add --local to ignore the tracker
  --tracker                work through the render tracker sheet unattended: eligible rows
                           only, the sheet's Min Gap / Daily Cap / cooldown / retries, every
                           attempt logged to the sheet; exits when nothing is eligible
  --queue                  print the tracker's per-kind state and eligible rows; no browser
  --reset id,id            make these tracker rows eligible again now (Status Pending, Next
                           Eligible cleared); with --run RUNID also relabel that run's 'quota'
                           attempts of these assets as 'blocked', which lifts the kind's quota
                           cooldown they caused. No browser
  --assist                 like --render, but you click send/download yourself; the script fills
                           the prompt and saves whatever you download or what appears on the page
  --convert                convert captures kept beside their drop in another format (status
                           CONVERT) with ffmpeg; no browser, no generation

Options
  --kind image|video|music|all   (default all)
  --only id,id             limit to these asset ids
  --force                  re-render even if the drop file exists
  --dry-run                list what would be rendered and the final prompt text; no browser
  --limit N                at most N generations this run, N >= 1 (local mode: also capped by
                           maxPerRun, default 10; tracker mode: the sheet's Daily Cap applies)
  --delay SEC              local mode: pause between generations, SEC >= 0 (default 90);
                           tracker mode uses the sheet's Min Gap per kind
  --local                  ignore a configured tracker (local queue, runs/attempts.jsonl log)
  --pause-on-error         on a failure, wait for you to fix it in the window, then capture
  --sync                   run tools/sync_rendered_assets.py afterwards
  --chrome PATH            Chrome/Chromium executable (default: auto-detect)
  --profile DIR            automation profile (default ~/.local/share/persistint-web-render/chrome-profile)
  --browser-url URL        attach to a Chrome you started with --remote-debugging-port
                           (e.g. http://127.0.0.1:9222 for Windows Chrome)
  --selectors FILE         alternative selectors.json
  --submit                 batch: send every missing prompt in its own Gemini chat without waiting
                           for results; each asset's chat URL is kept in runs/batch.json
  --harvest                batch: reopen each recorded chat and download its finished result into
                           the drop file; run again later for chats still generating
  --gap SEC                batch: seconds between sends with --submit (default 20)
  --wait                   batch: with --submit, stay on each chat until it completes, download it,
                           delete that chat, then send the next (one at a time)
  --run RUNID              with --reset: the run whose 'quota' attempts were really the check page

If Google shows its "unusual traffic" check page (reCAPTCHA), the run stops at once (outcome
"blocked", no cooldown). Solve it by hand with: node inspect.mjs --keep 300   then run again.
`;

const { values: a } = parseArgs({
  options: {
    status: { type: 'boolean' }, login: { type: 'boolean' }, render: { type: 'boolean' },
    assist: { type: 'boolean' }, 'check-selectors': { type: 'boolean' }, convert: { type: 'boolean' },
    tracker: { type: 'boolean' }, local: { type: 'boolean' }, queue: { type: 'boolean' },
    reset: { type: 'string' }, run: { type: 'string' },
    kind: { type: 'string', default: 'all' }, only: { type: 'string' }, force: { type: 'boolean' },
    'dry-run': { type: 'boolean' }, limit: { type: 'string' }, delay: { type: 'string' },
    'pause-on-error': { type: 'boolean' }, sync: { type: 'boolean' },
    chrome: { type: 'string' }, profile: { type: 'string' }, 'browser-url': { type: 'string' },
    selectors: { type: 'string' }, submit: { type: 'boolean' }, harvest: { type: 'boolean' }, gap: { type: 'string' }, wait: { type: 'boolean' }, help: { type: 'boolean', short: 'h' },
  },
  strict: true,
});

if (a.help) { console.log(HELP); process.exit(0); }
if (!['image', 'video', 'music', 'all'].includes(a.kind)) { console.error(`--kind must be image, video, music or all`); process.exit(2); }

let settings, limit;
try {
  limit = parseLimit(a.limit);
  settings = loadSettings({
    chrome: a.chrome, profileDir: a.profile, browserURL: a['browser-url'], delaySec: parseDelay(a.delay),
  });
} catch (e) {
  if (!(e instanceof SettingsError)) throw e;
  console.error(e.message);
  process.exit(2);
}
const selectorsFile = a.selectors ? path.resolve(a.selectors) : SELECTORS_PATH;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const trackerConfigured = !!settings.trackerUrl;
if ((a.tracker || a.queue || a.reset) && !trackerConfigured) {
  console.error('No render tracker configured: set trackerUrl and trackerSecret in tools/web_render/config.local.json\n' +
    '(or WEB_RENDER_TRACKER_URL / WEB_RENDER_TRACKER_SECRET). See tools/render_tracker/DEPLOY.md.');
  process.exit(2);
}
if (a.tracker && a.local) { console.error('--tracker and --local exclude each other'); process.exit(2); }
// --render uses the tracker when one is configured; --assist (needs the author) stays local unless --tracker.
const trackerMode = !!a.tracker || (!!a.render && !a.assist && trackerConfigured && !a.local);
const RUNS_DIR = process.env.WEB_RENDER_RUNS_DIR || path.join(WEB_RENDER_DIR, 'runs');   // tests point it elsewhere
const ATTEMPTS_JSONL = path.join(RUNS_DIR, 'attempts.jsonl');
const BLOCKED_SUMMARY = 'Stopped: Google is showing its "unusual traffic" check page (reCAPTCHA). Nothing else was tried.\n' +
  '  Solve it by hand in the renderer\'s Chrome profile:  node inspect.mjs --keep 300   (tick the box, then wait for Gemini to load)\n' +
  '  Then run again. The asset(s) got no cooldown; the attempt is logged with outcome "blocked".';
const newRunId = () => `${new Date().toISOString().replace(/[:.]/g, '-')}-${process.pid}`;

async function makeTrackerClient() {
  const { TrackerClient } = await import('./lib/tracker.mjs');
  return new TrackerClient({ url: settings.trackerUrl, secret: settings.trackerSecret, allowLoopbackHttp: trackerAllowsLoopbackHttp() });
}

async function runBatch(tasks) {
  const { submitAll, harvestAll } = await import('./lib/batch.mjs');
  const { Session } = await import('./lib/engine.mjs');
  const { getBrowser } = await import('./lib/browser.mjs');
  const selectors = loadSelectors(selectorsFile);
  const drivers = {
    image: (await import('./drivers/image.mjs')).default,
    video: (await import('./drivers/video.mjs')).default,
    music: (await import('./drivers/music.mjs')).default,
  };
  const surfaceOf = (t) => selectors.surfaces[selectors.kinds[t.kind]];
  const file = path.join(RUNS_DIR, 'batch.json');
  const b = await getBrowser(settings);
  const session = new Session(b.browser, settings);
  await session.init();
  try {
    if (a.submit) {
      const todo = selectTasks(tasks, { kind: a.kind, only: a.only, force: a.force });
      const gap = a.gap === undefined ? 20 : Number(a.gap);
      await submitAll(session, { tasks: todo, surfaceOf, promptOf: (t) => drivers[t.kind].preparePrompt(t, surfaceOf(t)), file, gapMs: gap * 1000, wait: !!a.wait });
    }
    if (a.harvest) await harvestAll(session, { tasks: a.only ? tasks.filter((t) => a.only.split(',').map((x) => x.trim()).includes(t.id)) : tasks, surfaceOf, file });
  } catch (e) {
    if (!e.blocked) throw e;
    console.log('Stopped: Google is showing its "unusual traffic" check page (reCAPTCHA). Nothing else was tried.\n' +
      (settings.browserURL
        ? '  Solve it by hand in the attached Chrome window (tick the box, then wait for Gemini to load).\n'
        : '  Solve it by hand in the renderer\'s Chrome profile:  node inspect.mjs --keep 300   (tick the box, then wait for Gemini to load)\n') +
      '  Then run the same command again: chats already recorded in runs/batch.json are kept, and no chat was deleted.');
    process.exitCode = 1;
  } finally {
    // Attach mode reuses the window's tab: leave it open; only disconnect.
    if (!settings.browserURL && session.page && !session.page.isClosed()) await session.page.close().catch(() => {});
    if (b.close) await b.close().catch(() => {});
  }
  if (a.sync && a.harvest) spawnSync('python3', [path.join(ROOT, 'tools/sync_rendered_assets.py')], { stdio: 'inherit' });
}

async function main() {
  if (a['check-selectors']) {
    loadSelectors(selectorsFile);
    console.log(`${selectorsFile}: OK`);
    return;
  }

  if (a.login) {
    const { openForLogin, WINDOWS_LAUNCH_HINT, WINDOWS_LOGIN_HINT } = await import('./lib/browser.mjs');
    if (settings.browserURL) {
      console.log('In attach mode you start Chrome yourself on Windows, on its own profile folder (never your normal one).');
      console.log('1. Sign in WITHOUT a debugging port (Google may refuse sign-in while one is open), then close that window:');
      console.log(`     PowerShell: ${WINDOWS_LOGIN_HINT}`);
      console.log('2. Start it again with the debugging port and leave it running while you render:');
      console.log(`     PowerShell: ${WINDOWS_LAUNCH_HINT}`);
      console.log('The dedicated-profile check cannot see which profile an attached Chrome uses; Chrome 136+ refuses');
      console.log('remote debugging on its default profile, so step 2 fails if --user-data-dir is missing.');
      return;
    }
    // Tabs to open: Google sign-in plus every surface URL in selectors.json.
    const cfg = loadSelectors(selectorsFile);
    const urls = [...new Set([cfg.loginUrl || 'https://accounts.google.com/', ...Object.values(cfg.surfaces).map((s) => s.url)])];
    await openForLogin({ ...settings, urls });
    return;
  }

  if (a.queue) {
    const { describeQueue, KINDS } = await import('./lib/tracker.mjs');
    const kinds = a.kind === 'all' ? KINDS : [a.kind];
    const q = await (await makeTrackerClient()).getQueue({ kind: a.kind === 'all' ? null : a.kind, all: true });
    console.log(`Tracker at ${q.now}:\n${describeQueue(q, kinds)}`);
    for (const r of q.rows) if (kinds.includes(r.kind)) console.log(`  ${r.kind.padEnd(6)} ${String(r.asset_id).padEnd(38)} ${r.status}${r.attempts ? `, ${r.attempts} attempt(s)` : ''}`);
    return;
  }

  if (a.reset) {
    const ids = a.reset.split(',').map((s) => s.trim()).filter(Boolean);
    const kindOf = new Map(discoverTasks(undefined, { warn: () => {} }).map((t) => [t.id, t.kind]));
    const client = await makeTrackerClient();
    for (const id of ids) {
      const r = await client.reset({ asset_id: id, kind: kindOf.get(id) ?? null },
        a.run ? { runId: a.run, from: 'quota', to: 'blocked' } : {});
      console.log(`  ${id}: ${r.status}${r.relabeled ? `, ${r.relabeled} attempt(s) of run ${a.run} relabeled quota -> blocked` : ''}`);
    }
    return;
  }

  const tasks = discoverTasks();
  if (a.convert) return convertBeside(tasks);
  if (trackerMode) return runTracker(tasks);
  if (a.submit || a.harvest) return runBatch(tasks);
  const doRender = a.render || a.assist;
  if (!doRender) {
    const shown = a.only ? tasks.filter((t) => a.only.split(',').map((s) => s.trim()).includes(t.id)) : tasks;
    console.log(formatStatus(shown));
    if (a.sync) spawnSync('python3', [path.join(ROOT, 'tools/sync_rendered_assets.py')], { stdio: 'inherit' });
    return;
  }

  const selectors = loadSelectors(selectorsFile);
  const cap = Math.min(limit ?? Infinity, settings.maxPerRun);
  const todo = selectTasks(tasks, { kind: a.kind, only: a.only, force: a.force });
  const needConv = tasks.filter((t) => t.beside && !a.force && (a.kind === 'all' || t.kind === a.kind));
  if (needConv.length) console.warn(`[note] ${needConv.length} asset(s) already captured in another format and not re-rendered: ${needConv.map((t) => t.id).join(', ')}. Install ffmpeg and run --convert (or --force to generate again).`);
  for (const t of todo) {
    const f = dropFormat(t);
    if (!f.ok) console.warn(`[warn] ${t.id}: drop ${t.drop} has ${f.ext}, expected ${f.expected} for ${t.kind}`);
  }
  const batch = todo.slice(0, cap);
  console.log(`${todo.length} to render (kind=${a.kind}${a.force ? ', forced' : ''}); this run: ${batch.length} (cap ${cap === Infinity ? '-' : cap}), ${settings.delaySec}s apart.`);

  const drivers = {
    image: (await import('./drivers/image.mjs')).default,
    video: (await import('./drivers/video.mjs')).default,
    music: (await import('./drivers/music.mjs')).default,
  };

  if (a['dry-run']) {
    for (const t of batch) {
      const surfaceName = selectors.kinds[t.kind];
      const prompt = drivers[t.kind].preparePrompt(t, selectors.surfaces[surfaceName]);
      console.log(`\n[${t.kind}] ${t.id} -> ${t.drop}\n  surface: ${surfaceName} (${selectors.surfaces[surfaceName].url}), aspect ${t.aspect}\n  prompt (${prompt.length} chars): ${prompt.slice(0, 160)}${prompt.length > 160 ? '...' : ''}`);
    }
    return;
  }
  if (!batch.length) return;

  const { getBrowser } = await import('./lib/browser.mjs');
  const { Session } = await import('./lib/engine.mjs');
  const runLog = { started: new Date().toISOString(), mode: a.assist ? 'assist' : 'render', kind: a.kind, settings: publicSettings(settings), results: [] };
  const { LocalAttemptsLog, classifyOutcome, outcomePhrases } = await import('./lib/tracker.mjs');
  const attempts = new LocalAttemptsLog(ATTEMPTS_JSONL);
  const phrases = outcomePhrases(selectors);
  const runId = newRunId();
  const runsDir = RUNS_DIR;
  fs.mkdirSync(runsDir, { recursive: true });
  const runLogPath = path.join(runsDir, `${runLog.started.replace(/[:.]/g, '-')}.json`);
  const writeRunLog = () => fs.writeFileSync(runLogPath, JSON.stringify(runLog, null, 2));

  const b = await getBrowser(settings);
  let stopping = false;
  process.on('SIGINT', () => { if (stopping) process.exit(130); stopping = true; console.log('\nStopping after this asset (Ctrl-C again to quit now).'); });
  try {
    const session = new Session(b.browser, settings);
    await session.init();
    for (const [i, t] of batch.entries()) {
      if (stopping) break;
      const surfaceName = selectors.kinds[t.kind];
      const surface = selectors.surfaces[surfaceName];
      console.log(`\n[${i + 1}/${batch.length}] ${t.kind} ${t.id} on ${surfaceName}`);
      const t0 = Date.now();
      const rec = { id: t.id, kind: t.kind, surface: surfaceName, drop: t.drop, started: new Date().toISOString() };
      await attempts.start(t);
      try {
        const r = await drivers[t.kind].render(session, surface, t, { assist: a.assist, pauseOnError: a['pause-on-error'] });
        Object.assign(rec, r.skipped ? { status: 'skipped' } : { status: 'ok', bytes: r.bytes, route: r.route, format: r.format, converted: r.converted });
        rec.outcome = classifyOutcome(r, phrases);
      } catch (e) {
        Object.assign(rec, { status: 'failed', step: e.step, error: e.message, debugDir: e.debugDir ? path.relative(ROOT, e.debugDir) : null });
        rec.outcome = classifyOutcome(e, phrases);
        if (e.abortRun) {
          stopping = true;
          console.log(`  !! stopping the run: ${e.message.split('\n')[0]}`);
        }
      }
      await attempts.end(t, {
        outcome: rec.outcome, error: rec.error ? rec.error.split('\n')[0] : '', file: rec.status === 'ok' ? t.drop : '',
        debugDir: rec.debugDir || '', runId, surface: `gemini web: ${surfaceName}`,
      });
      rec.seconds = Math.round((Date.now() - t0) / 1000);
      runLog.results.push(rec);
      writeRunLog();
      if (i < batch.length - 1 && !stopping && !a.assist && settings.delaySec > 0) {
        console.log(`  waiting ${settings.delaySec}s before the next generation ...`);
        await sleep(settings.delaySec * 1000);
      }
    }
  } finally {
    runLog.finished = new Date().toISOString();
    writeRunLog();
    await b.close();
  }

  const failed = runLog.results.filter((r) => r.status === 'failed');
  const ok = runLog.results.filter((r) => r.status === 'ok');
  console.log(`\nDone: ${ok.length} saved, ${failed.length} failed, ${runLog.results.length - ok.length - failed.length} skipped. Run log: ${path.relative(ROOT, runLogPath)}; attempts: ${path.relative(ROOT, ATTEMPTS_JSONL)}`);
  for (const f of failed) console.log(`  failed ${f.id} at ${f.step}: ${f.error.split('\n')[0]}${f.debugDir ? `  (debug: ${f.debugDir})` : ''}`);
  if (runLog.results.some((r) => r.outcome === 'blocked')) console.log(BLOCKED_SUMMARY);
  if (a.sync && ok.length) {
    const r = spawnSync('python3', [path.join(ROOT, 'tools/sync_rendered_assets.py')], { stdio: 'inherit' });
    if (r.status !== 0) process.exitCode = 1;
  }
  if (failed.length) process.exitCode = 1;
}

/**
 * Tracker mode: the sheet decides what is eligible and when; prompts/ supplies the prompt text.
 * Fully unattended: no prompts to the author (pause-on-error only if asked for).
 */
async function runTracker(tasks) {
  const T = await import('./lib/tracker.mjs');
  const client = await makeTrackerClient();
  const selectors = loadSelectors(selectorsFile);
  const kinds = a.kind === 'all' ? T.KINDS : [a.kind];
  const only = a.only ? new Set(a.only.split(',').map((s) => s.trim()).filter(Boolean)) : null;
  const drivers = {
    image: (await import('./drivers/image.mjs')).default,
    video: (await import('./drivers/video.mjs')).default,
    music: (await import('./drivers/music.mjs')).default,
  };

  if (a['dry-run']) {
    const q = await client.getQueue({ kind: kinds.length === 1 ? kinds[0] : null, all: true });
    console.log(`Tracker at ${q.now} (dry run: nothing is rendered or written):\n${T.describeQueue(q, kinds)}`);
    const byId = new Map(tasks.map((t) => [t.id, t]));
    for (const r of q.rows) {
      if (!kinds.includes(r.kind) || (only && !only.has(r.asset_id))) continue;
      const t = byId.get(r.asset_id);
      if (!t) { console.log(`\n[${r.kind}] ${r.asset_id}: no prompt file in prompts/ (would be marked skipped)`); continue; }
      if (t.exists && !a.force) { console.log(`\n[${r.kind}] ${r.asset_id}: ${t.drop} exists (would be marked done)`); continue; }
      const surface = selectors.surfaces[selectors.kinds[r.kind]];
      const prompt = drivers[r.kind].preparePrompt(t, surface);
      const note = T.promptDiffNote(r.prompt, t.prompt, t.md_path);
      console.log(`\n[${r.kind}] ${r.asset_id} -> ${t.drop}${note ? `\n  note: ${note}` : ''}\n  prompt (${prompt.length} chars): ${prompt.slice(0, 160)}${prompt.length > 160 ? '...' : ''}`);
    }
    return;
  }

  // One Chrome and one Session for the whole run, started on the first render: a quota on one
  // kind, or switching kinds, only opens a new tab (Session.newPage), never a new browser.
  let b = null, session = null;
  const renderOne = async (task) => {
    if (!session) {
      const { getBrowser } = await import('./lib/browser.mjs');
      const { Session } = await import('./lib/engine.mjs');
      b = await getBrowser(settings);
      session = new Session(b.browser, settings);
      await session.init();
    }
    const surface = selectors.surfaces[selectors.kinds[task.kind]];
    try {
      return await drivers[task.kind].render(session, surface, task, { pauseOnError: a['pause-on-error'] });
    } catch (e) {
      if (e.debugDir) e.debugDir = path.relative(ROOT, e.debugDir);
      throw e;
    }
  };

  const runId = newRunId();
  const state = {};
  let stopping = false;
  process.on('SIGINT', () => {
    if (stopping) {
      // Second Ctrl-C: report the asset in flight as failed (it is retried later), then quit.
      const cur = state.current;
      if (!cur) process.exit(130);
      console.log('\nQuitting; marking the current asset as interrupted in the tracker ...');
      const bail = setTimeout(() => process.exit(130), 15_000);
      client.end(cur.row, { outcome: 'failed', error: 'interrupted (Ctrl-C)', started: cur.started, runId, surface: `gemini web: ${selectors.kinds[cur.row.kind]}` })
        .catch((e) => console.error(e.message)).finally(() => { clearTimeout(bail); process.exit(130); });
      return;
    }
    stopping = true;
    console.log('\nStopping after this asset (Ctrl-C again to quit now).');
  });

  const runsDir = RUNS_DIR;
  fs.mkdirSync(runsDir, { recursive: true });
  console.log(`Tracker mode (kind=${kinds.join(',')}${only ? `, only ${[...only].join(',')}` : ''}${limit ? `, limit ${limit}` : ''}); run ${runId}`);
  let out;
  try {
    out = await T.runTrackerLoop({
      client, tasks, renderOne, kinds, only, force: !!a.force, limit: limit ?? Infinity,
      maxWaitSec: settings.trackerMaxWaitSec, runId, surfaceFor: (k) => `gemini web: ${selectors.kinds[k]}`,
      phrases: T.outcomePhrases(selectors), localLog: new T.LocalAttemptsLog(ATTEMPTS_JSONL),
      isStopping: () => stopping, state,
    });
  } finally {
    if (b) await b.close();
  }
  const runLogPath = path.join(runsDir, `${runId}.json`);
  fs.writeFileSync(runLogPath, JSON.stringify({ runId, mode: 'tracker', kinds, settings: publicSettings(settings), ...out }, null, 2));
  printTrackerSummary(out, T, path.relative(ROOT, runLogPath));
  if (a.sync && out.results.some((r) => r.outcome === 'done' && r.file)) {
    const r = spawnSync('python3', [path.join(ROOT, 'tools/sync_rendered_assets.py')], { stdio: 'inherit' });
    if (r.status !== 0) process.exitCode = 1;
  }
  if (out.reason === 'blocked' || out.results.some((r) => !['done', 'skipped', 'quota'].includes(r.outcome))) process.exitCode = 1;
}

function printTrackerSummary(out, T, runLogRel) {
  const by = {};
  for (const r of out.results) by[r.outcome] = (by[r.outcome] || 0) + 1;
  console.log(`\nDone: ${Object.entries(by).map(([k, v]) => `${v} ${k}`).join(', ') || 'nothing rendered'}. Run log: ${runLogRel}`);
  for (const r of out.results) if (r.error) console.log(`  ${r.outcome} ${r.id}: ${r.error.slice(0, 200)}${r.debugDir ? `  (debug: ${r.debugDir})` : ''}`);
  if (out.reason === 'blocked') { console.log(BLOCKED_SUMMARY); return; }
  if (out.stopped?.length) console.log(`Stopped on a usage limit: ${out.stopped.join(', ')}.`);
  if (out.capped?.length) console.log(`Daily cap used up: ${out.capped.join(', ')} (resets at midnight in the sheet's time zone).`);
  if (out.reason === 'later') console.log(`Next eligible: ${T.fmtTime(out.nextEligible)} (${out.wakes[0].kind}, ${out.wakes[0].why}). Run again then.`);
  else if (out.reason === 'empty' && !out.stopped?.length) console.log('Nothing left to render in the tracker.');
  else if (out.reason === 'limit') console.log('Stopped at --limit.');
}

/** --convert: turn captures kept beside their drop (another format) into the drop format. */
async function convertBeside(tasks) {
  const { convertFile, hasFfmpeg, sniffExt } = await import('./lib/media.mjs');
  const todo = tasks.filter((t) => t.beside && (!a.only || a.only.split(',').map((x) => x.trim()).includes(t.id)) && (a.kind === 'all' || t.kind === a.kind));
  if (!todo.length) { console.log('Nothing to convert.'); return; }
  if (!hasFfmpeg()) { console.error(`${todo.length} file(s) need conversion but ffmpeg is not installed (sudo apt install ffmpeg).`); process.exitCode = 1; return; }
  for (const t of todo) {
    const got = sniffExt(fs.readFileSync(t.beside)) ?? path.extname(t.beside);
    try {
      convertFile(t.beside, t.drop_abs, got, { log: (m) => console.log(m) });
      console.log(`  -> ${t.drop} (from ${path.relative(ROOT, t.beside)})`);
    } catch (e) {
      console.error(`  !! ${t.id}: ${e.message}`);
      process.exitCode = 1;
    }
  }
}

main().catch((e) => { console.error(e.message); process.exit(e instanceof SettingsError ? 2 : 1); });
