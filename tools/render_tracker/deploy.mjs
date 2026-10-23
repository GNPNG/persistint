#!/usr/bin/env node
// Keyboard-only deployment of tracker_webapp.gs as a web app with clasp. See DEPLOY.md.
//
//   node tools/render_tracker/deploy.mjs login    once: clasp login (sign-in page opens in the
//                                                 renderer's Chrome profile)
//   node tools/render_tracker/deploy.mjs          create (first time) + push + deploy; writes
//                                                 trackerUrl / trackerSecret into
//                                                 tools/web_render/config.local.json; opens the
//                                                 web app once for Google's authorization page
//                                                 and waits until the tracker answers
//   node tools/render_tracker/deploy.mjs --new-secret   rotate the shared secret, then push + redeploy
//   options: --no-open (print URLs instead of opening them), --sheet ID
//
// The secret is never printed. Files written here are gitignored: tracker_secret.local.gs,
// .clasp.json, deploy.local.json, tools/web_render/config.local.json.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const WEB_RENDER = path.resolve(HERE, '..', 'web_render');
const CONFIG = process.env.WEB_RENDER_CONFIG || path.join(WEB_RENDER, 'config.local.json');
const SECRET_GS = path.join(HERE, 'tracker_secret.local.gs');
const STATE = path.join(HERE, 'deploy.local.json');
const CLASP_JSON = path.join(HERE, '.clasp.json');
const CLASP = ['--yes', '@google/clasp@3.4.1'];
const DEFAULT_SHEET = '1WNbk19jM4_gVMklRA4rdA8Im9K_v8rb7VdvDFVc8geA';

const { values: a, positionals } = parseArgs({
  options: { 'new-secret': { type: 'boolean' }, 'no-open': { type: 'boolean' }, sheet: { type: 'string', default: DEFAULT_SHEET }, help: { type: 'boolean', short: 'h' } },
  allowPositionals: true,
});
if (a.help) { console.log(fs.readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(1, 16).map((l) => l.replace(/^\/\/ ?/, '')).join('\n')); process.exit(0); }

const readJson = (f, d = {}) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return d; } };
const writeJson = (f, o) => { fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n', { mode: 0o600 }); fs.chmodSync(f, 0o600); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Run clasp; stdout is returned (and echoed unless quiet). onLine sees every output line. */
function clasp(args, { cwd = HERE, quiet = false, onLine = null } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('npx', [...CLASP, ...args], { cwd, stdio: ['inherit', 'pipe', 'pipe'] });
    let out = '';
    const feed = (stream, echo) => {
      let buf = '';
      stream.on('data', (d) => {
        const s = String(d);
        out += s;
        if (!quiet) echo.write(s);
        buf += s;
        let i;
        while ((i = buf.indexOf('\n')) >= 0) { onLine?.(buf.slice(0, i)); buf = buf.slice(i + 1); }
      });
    };
    feed(child.stdout, process.stdout);
    feed(child.stderr, process.stderr);
    child.on('error', reject);
    child.on('exit', (code) => (code === 0 ? resolve(out) : reject(Object.assign(new Error(`clasp ${args.filter((x) => !x.startsWith('-'))[0]} failed (exit ${code})`), { output: out }))));
  });
}

/** Open a URL in the renderer's dedicated Chrome profile (already signed in to Google after --login). */
async function openUrl(url, what) {
  if (a['no-open']) { console.log(`Open this ${what} in a browser signed in to the Google account:\n  ${url}`); return; }
  try {
    const { loadSettings } = await import('../web_render/lib/config.mjs');
    const { findChrome } = await import('../web_render/lib/browser.mjs');
    const s = loadSettings();
    if (s.browserURL) throw new Error('attach mode: the renderer does not start Chrome itself');
    const exe = findChrome(s.chrome);
    fs.mkdirSync(s.profileDir, { recursive: true });
    spawn(exe.path, [`--user-data-dir=${s.profileDir}`, '--no-first-run', '--no-default-browser-check', url], { stdio: 'ignore', detached: true }).unref();
    console.log(`Opened the ${what} in the renderer's Chrome profile.`);
  } catch (e) {
    console.log(`Could not open a browser (${e.message.split('\n')[0]}). Open this ${what} yourself:\n  ${url}`);
  }
}

/** The secret lives in tracker_secret.local.gs until a deploy succeeds; only then is it copied to config.local.json. */
function ensureSecret(rotate) {
  const have = !!readSecret();
  if (have && !rotate) return false;
  const secret = crypto.randomBytes(36).toString('base64url');   // 48 chars
  fs.writeFileSync(SECRET_GS, `// Written by deploy.mjs. Gitignored: never commit. Read by checkSecret_ in tracker_webapp.gs.\nvar TRACKER_SECRET_LOCAL = '${secret}';\n`, { mode: 0o600 });
  console.log(`${have ? 'New' : 'Generated a'} shared secret in ${path.relative(process.cwd(), SECRET_GS)} (not shown).`);
  return true;
}

function readSecret() {
  try { return /TRACKER_SECRET_LOCAL = '([\w-]{32,})'/.exec(fs.readFileSync(SECRET_GS, 'utf8'))?.[1] || null; } catch { return null; }
}

async function loggedIn() {
  try {
    const out = await clasp(['--json', 'show-authorized-user'], { quiet: true });
    return /"loggedIn"\s*:\s*true/.test(out);
  } catch { return false; }
}

async function login() {
  let opened = false;
  await clasp(['login'], {
    onLine: (line) => {
      const m = /(https:\/\/accounts\.google\.com\/\S+)/.exec(line);
      if (m && !opened) { opened = true; openUrl(m[1], 'clasp sign-in page'); }
    },
  });
}

async function createProject() {
  if (fs.existsSync(CLASP_JSON)) return;
  // clasp create-script pulls the new project's default files into its rootDir; do that in a
  // scratch folder so it cannot overwrite appsscript.json here. A standalone create with
  // --parentId <spreadsheet id> makes a script bound to that spreadsheet.
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'render-tracker-clasp-'));
  try {
    await clasp(['create-script', '--type', 'standalone', '--title', 'Render tracker web app', '--parentId', a.sheet, '--rootDir', '.'], { cwd: tmp });
    const { scriptId } = readJson(path.join(tmp, '.clasp.json'));
    if (!scriptId) throw new Error('clasp did not write a scriptId');
    writeJson(CLASP_JSON, { scriptId, rootDir: '.' });
    console.log(`Created the Apps Script project ${scriptId}, bound to spreadsheet ${a.sheet}.`);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

async function deploy() {
  const state = readJson(STATE);
  const args = ['--json', 'create-deployment', '--description', `render tracker ${new Date().toISOString().slice(0, 16)}`];
  if (state.deploymentId) args.push('--deploymentId', state.deploymentId);   // same URL on every redeploy
  const out = await clasp(args, { quiet: true });
  const id = /"deploymentId"\s*:\s*"([\w-]+)"/.exec(out)?.[1] || /\b(AKfy[\w-]{20,})/.exec(out)?.[1];
  if (!id) throw new Error(`could not read the deployment id from clasp's output:\n${out}`);
  writeJson(STATE, { ...state, deploymentId: id });
  const url = `https://script.google.com/macros/s/${id}/exec`;
  // URL and secret go into the renderer's config together, only after a successful deploy, so a
  // failed first deploy never leaves a half-configured tracker that blocks render.mjs.
  writeJson(CONFIG, { ...readJson(CONFIG), trackerUrl: url, trackerSecret: readSecret() });
  console.log(`Deployed web app ${id}\n  trackerUrl and trackerSecret written to ${path.relative(process.cwd(), CONFIG)}: ${url}`);
  return url;
}

/** Poll the tracker until it answers with JSON (i.e. the one-time authorization is done). */
async function waitForTracker(url, minutes = 15) {
  const { TrackerClient, describeQueue } = await import('../web_render/lib/tracker.mjs');
  const client = new TrackerClient({ url, secret: readJson(CONFIG).trackerSecret, retries: 0, timeoutMs: 60_000 });
  const deadline = Date.now() + minutes * 60_000;
  let said = false;
  while (Date.now() < deadline) {
    try {
      const q = await client.getQueue();
      console.log(`\nThe tracker answers. Queue state:\n${describeQueue(q)}\n\nRender unattended with:  node tools/web_render/render.mjs --render`);
      return true;
    } catch (e) {
      if (!said) { console.log(`Waiting for the tracker to answer (${e.message.split('\n')[0]}) ...`); said = true; }
      await sleep(10_000);
    }
  }
  console.log('The tracker did not answer yet. Finish the authorization page, then check with:  node tools/web_render/render.mjs --queue');
  return false;
}

async function main() {
  if (positionals[0] === 'login') {
    await login();
    console.log('clasp is signed in. Next:  node tools/render_tracker/deploy.mjs');
    return;
  }
  if (positionals.length) throw new Error(`unknown command ${positionals[0]} (use: login)`);
  if (!(await loggedIn())) {
    console.log('clasp is not signed in yet. Run once:  node tools/render_tracker/deploy.mjs login');
    process.exitCode = 1;
    return;
  }
  const firstTime = !readJson(STATE).deploymentId;
  ensureSecret(!!a['new-secret']);
  try {
    await createProject();
    await clasp(['push', '--force']);
  } catch (e) {
    if (/Apps Script API/i.test(e.output || '')) {
      console.log('\nOne-time step: the Apps Script API is switched off for this account. On the page that opens,');
      console.log('switch "Google Apps Script API" on (Tab to the switch, Space), then run this command again.');
      await openUrl('https://script.google.com/home/usersettings', 'Apps Script settings page');
      process.exitCode = 1;
      return;
    }
    throw e;
  }
  const url = await deploy();
  if (firstTime) {
    console.log('\nOne-time step: Google asks you to authorize the script to edit the spreadsheet.');
    console.log('On that page: choose the account, then "Advanced" > "Go to Render tracker web app", then "Allow"');
    console.log('(Tab / Enter work everywhere). Afterwards the page shows {"ok":false,"error":"unauthorized"}: that is correct.');
    await openUrl(url, 'web app authorization page');
  }
  await waitForTracker(url, firstTime ? 15 : 2);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
