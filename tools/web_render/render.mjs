#!/usr/bin/env node
// Render the asset prompts in prompts/ through the Gemini web app (AI Ultra), driving a real
// Chrome on a dedicated profile with Puppeteer. See README.md in this folder.
import fs from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { ROOT, WEB_RENDER_DIR, discoverTasks, selectTasks, formatStatus, dropFormat } from './lib/tasks.mjs';
import { loadSettings, loadSelectors, SELECTORS_PATH, SettingsError, parseLimit, parseDelay } from './lib/config.mjs';

const HELP = `Usage: node tools/web_render/render.mjs <mode> [options]

Modes
  --status                 rendered vs missing, per asset (default)
  --check-selectors        validate selectors.json and exit
  --login                  open the dedicated Chrome profile so you can sign in to Google once
  --render                 render missing assets in the browser (automatic)
  --assist                 like --render, but you click send/download yourself; the script fills
                           the prompt and saves whatever you download or what appears on the page
  --convert                convert captures kept beside their drop in another format (status
                           CONVERT) with ffmpeg; no browser, no generation

Options
  --kind image|video|music|all   (default all)
  --only id,id             limit to these asset ids
  --force                  re-render even if the drop file exists
  --dry-run                list what would be rendered and the final prompt text; no browser
  --limit N                at most N generations this run, N >= 1 (also capped by maxPerRun, default 10)
  --delay SEC              pause between generations, SEC >= 0 (default 90)
  --pause-on-error         on a failure, wait for you to fix it in the window, then capture
  --sync                   run tools/sync_rendered_assets.py afterwards
  --chrome PATH            Chrome/Chromium executable (default: auto-detect)
  --profile DIR            automation profile (default ~/.local/share/persistint-web-render/chrome-profile)
  --browser-url URL        attach to a Chrome you started with --remote-debugging-port
                           (e.g. http://127.0.0.1:9222 for Windows Chrome)
  --selectors FILE         alternative selectors.json
`;

const { values: a } = parseArgs({
  options: {
    status: { type: 'boolean' }, login: { type: 'boolean' }, render: { type: 'boolean' },
    assist: { type: 'boolean' }, 'check-selectors': { type: 'boolean' }, convert: { type: 'boolean' },
    kind: { type: 'string', default: 'all' }, only: { type: 'string' }, force: { type: 'boolean' },
    'dry-run': { type: 'boolean' }, limit: { type: 'string' }, delay: { type: 'string' },
    'pause-on-error': { type: 'boolean' }, sync: { type: 'boolean' },
    chrome: { type: 'string' }, profile: { type: 'string' }, 'browser-url': { type: 'string' },
    selectors: { type: 'string' }, help: { type: 'boolean', short: 'h' },
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

  const tasks = discoverTasks();
  if (a.convert) return convertBeside(tasks);
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
  const runLog = { started: new Date().toISOString(), mode: a.assist ? 'assist' : 'render', kind: a.kind, settings: { ...settings }, results: [] };
  const runsDir = path.join(WEB_RENDER_DIR, 'runs');
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
      try {
        const r = await drivers[t.kind].render(session, surface, t, { assist: a.assist, pauseOnError: a['pause-on-error'] });
        Object.assign(rec, r.skipped ? { status: 'skipped' } : { status: 'ok', bytes: r.bytes, route: r.route, format: r.format, converted: r.converted });
      } catch (e) {
        Object.assign(rec, { status: 'failed', step: e.step, error: e.message, debugDir: e.debugDir ? path.relative(ROOT, e.debugDir) : null });
        if (e.abortRun) {
          stopping = true;
          console.log(`  !! stopping the run: ${e.message.split('\n')[0]}`);
        }
      }
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
  console.log(`\nDone: ${ok.length} saved, ${failed.length} failed, ${runLog.results.length - ok.length - failed.length} skipped. Run log: ${path.relative(ROOT, runLogPath)}`);
  for (const f of failed) console.log(`  failed ${f.id} at ${f.step}: ${f.error.split('\n')[0]}${f.debugDir ? `  (debug: ${f.debugDir})` : ''}`);
  if (a.sync && ok.length) {
    const r = spawnSync('python3', [path.join(ROOT, 'tools/sync_rendered_assets.py')], { stdio: 'inherit' });
    if (r.status !== 0) process.exitCode = 1;
  }
  if (failed.length) process.exitCode = 1;
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
