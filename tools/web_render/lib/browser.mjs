// Starting / attaching to Chrome. We start a real Chrome ourselves with a dedicated
// --user-data-dir and attach with puppeteer.connect (no puppeteer.launch automation flags,
// no stealth plugins). Or we attach to a Chrome the author started (e.g. on Windows).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function which(cmd) {
  const r = spawnSync('sh', ['-c', `command -v ${cmd}`], { encoding: 'utf8' });
  return r.status === 0 ? r.stdout.trim() : null;
}

/** Candidate executables in preference order; first that exists wins. */
export function findChrome(explicit) {
  if (explicit) {
    if (!fs.existsSync(explicit)) throw new Error(`chrome executable not found: ${explicit}`);
    return { path: explicit, note: 'configured' };
  }
  for (const c of ['google-chrome-stable', 'google-chrome']) {
    const p = which(c);
    if (p) return { path: p, note: 'Google Chrome' };
  }
  const cache = path.join(os.homedir(), '.cache/puppeteer/chrome');
  if (fs.existsSync(cache)) {
    const builds = fs.readdirSync(cache).filter((d) => d.startsWith('linux-')).sort().reverse();
    for (const b of builds) {
      const p = path.join(cache, b, 'chrome-linux64/chrome');
      if (fs.existsSync(p)) return { path: p, note: `Chrome for Testing ${b.slice(6)} (Google sign-in from it is unverified)` };
    }
  }
  for (const p of ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/snap/bin/chromium']) {
    if (fs.existsSync(p)) return { path: p, note: p.startsWith('/snap') ? 'snap Chromium (confinement may interfere)' : 'Chromium' };
  }
  throw new Error('no Chrome found: install google-chrome-stable, set WEB_RENDER_CHROME, or attach with --browser-url');
}

function baseArgs(profileDir) {
  return [`--user-data-dir=${profileDir}`, '--no-first-run', '--no-default-browser-check'];
}

/**
 * --login: open the dedicated profile WITHOUT a debugging port so the author can sign in to
 * Google by hand. Resolves when the author closes the window.
 */
export async function openForLogin({ chrome, profileDir, urls, log = console.log }) {
  const exe = findChrome(chrome);
  fs.mkdirSync(profileDir, { recursive: true });
  log(`Opening ${exe.path} (${exe.note})\n  profile: ${profileDir}`);
  log('Sign in to the Google account that has AI Ultra, open each tab once (accept any prompts), then CLOSE the window.');
  const child = spawn(exe.path, [...baseArgs(profileDir), ...urls], { stdio: 'ignore' });
  await new Promise((res, rej) => { child.on('exit', res); child.on('error', rej); });
  log('Browser closed; the sign-in is saved in the profile.');
}

/**
 * Start Chrome on the dedicated profile with a debugging port (port 0 = Chrome picks one and
 * writes it to <profile>/DevToolsActivePort), then puppeteer.connect to it.
 */
export async function launchAndConnect({ chrome, profileDir, launchTimeoutSec = 120, extraArgs = [], log = console.log }) {
  const puppeteer = (await import('puppeteer-core')).default;
  const exe = findChrome(chrome);
  fs.mkdirSync(profileDir, { recursive: true });
  const portFile = path.join(profileDir, 'DevToolsActivePort');
  fs.rmSync(portFile, { force: true });
  log(`Starting ${exe.path} (${exe.note})\n  profile: ${profileDir}`);
  const child = spawn(exe.path, [...baseArgs(profileDir), '--remote-debugging-port=0', ...extraArgs, 'about:blank'],
    { stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = '';
  child.stderr.on('data', (d) => { stderr = (stderr + d).slice(-4000); });
  let exited = null;
  child.on('exit', (code) => { exited = code ?? 'signal'; });
  const deadline = Date.now() + launchTimeoutSec * 1000;
  let wsPath = null, port = null;
  while (Date.now() < deadline) {
    if (exited !== null) throw new Error(`Chrome exited (${exited}) before opening its DevTools port. Is another Chrome using this profile?\n${stderr}`);
    if (fs.existsSync(portFile)) {
      const [p, ws] = fs.readFileSync(portFile, 'utf8').split('\n');
      if (p && ws) { port = p.trim(); wsPath = ws.trim(); break; }
    }
    await sleep(500);
  }
  if (!wsPath) { child.kill(); throw new Error(`Chrome did not open a DevTools port within ${launchTimeoutSec}s\n${stderr}`); }
  const browser = await puppeteer.connect({
    browserWSEndpoint: `ws://127.0.0.1:${port}${wsPath}`,
    defaultViewport: null,
    protocolTimeout: 15 * 60_000,
  });
  return {
    browser,
    owned: true,
    async close() {
      try { await browser.close(); } catch { /* already gone */ }
      if (exited === null) child.kill();
    },
  };
}

/** Attach to a Chrome the author started with --remote-debugging-port (e.g. Windows Chrome). */
export async function attach({ browserURL }) {
  const puppeteer = (await import('puppeteer-core')).default;
  const u = new URL(browserURL);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(u.hostname)) {
    throw new Error(`refusing to attach to ${u.hostname}: only a local DevTools endpoint is allowed`);
  }
  const browser = await puppeteer.connect({ browserURL, defaultViewport: null, protocolTimeout: 15 * 60_000 });
  return { browser, owned: false, async close() { await browser.disconnect(); } };
}

export async function getBrowser(settings, log = console.log) {
  if (settings.browserURL) {
    log(`Attaching to ${settings.browserURL}`);
    return attach(settings);
  }
  return launchAndConnect({ ...settings, log });
}

// Windows Chrome in attach mode: sign in first WITHOUT a debugging port (Google may refuse
// sign-in while one is open), close it, then start it again with the port to render.
export const WINDOWS_LOGIN_HINT = String.raw`& "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="C:\Users\<you>\persistint-chrome-profile" --no-first-run https://accounts.google.com/ https://gemini.google.com/app`;
export const WINDOWS_LAUNCH_HINT = String.raw`& "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir="C:\Users\<you>\persistint-chrome-profile" --no-first-run`;
