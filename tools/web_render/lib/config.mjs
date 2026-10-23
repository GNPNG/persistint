// Settings (defaults < config.local.json < env < CLI) and selectors.json loading/validation.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { WEB_RENDER_DIR, ROOT } from './tasks.mjs';

export const SELECTORS_PATH = path.join(WEB_RENDER_DIR, 'selectors.json');
export const LOCAL_CONFIG_PATH = path.join(WEB_RENDER_DIR, 'config.local.json');

export const DEFAULTS = {
  chrome: null,                 // executable; null = auto-detect (see browser.mjs)
  profileDir: path.join(os.homedir(), '.local/share/persistint-web-render/chrome-profile'),
  browserURL: null,             // e.g. http://127.0.0.1:9222 to attach to a Chrome you started yourself
  downloadDir: path.join(os.homedir(), '.local/share/persistint-web-render/downloads'),
  downloadDirBrowser: null,     // the same folder as the browser sees it (Windows Chrome: C:\...)
  delaySec: 90,                 // pause between generations
  maxPerRun: 10,                // hard cap on generations per run (--limit can lower it)
  launchTimeoutSec: 120,        // Chrome on WSLg can take ~20 s to open its DevTools port
  trackerUrl: null,             // render tracker web app /exec URL (tools/render_tracker/DEPLOY.md)
  trackerSecret: null,          // its TRACKER_SECRET; never printed or written to run logs
  trackerMaxWaitSec: 1800,      // tracker mode: wait in-process for a kind's min gap / retry up to this long, else exit
};

const ENV = {
  chrome: 'WEB_RENDER_CHROME', profileDir: 'WEB_RENDER_PROFILE', browserURL: 'WEB_RENDER_BROWSER_URL',
  downloadDir: 'WEB_RENDER_DOWNLOAD_DIR', downloadDirBrowser: 'WEB_RENDER_DOWNLOAD_DIR_BROWSER',
  trackerUrl: 'WEB_RENDER_TRACKER_URL', trackerSecret: 'WEB_RENDER_TRACKER_SECRET',
};

/** config.local.json, or the file named by WEB_RENDER_CONFIG (tests point it elsewhere). */
export function localConfigPath() {
  return process.env.WEB_RENDER_CONFIG || LOCAL_CONFIG_PATH;
}

/** Plain http to 127.0.0.1 is allowed for the tracker only with this env set (the test mock server). */
export const trackerAllowsLoopbackHttp = () => process.env.WEB_RENDER_TRACKER_ALLOW_LOOPBACK_HTTP === '1';

export function loadSettings(cli = {}) {
  let local = {};
  const cfgPath = localConfigPath();
  if (fs.existsSync(cfgPath)) local = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const s = { ...DEFAULTS, ...local };
  for (const [k, v] of Object.entries(ENV)) if (process.env[v]) s[k] = process.env[v];
  for (const [k, v] of Object.entries(cli)) if (v !== undefined && v !== null) s[k] = v;
  s.profileDir = expandHome(s.profileDir);
  s.downloadDir = expandHome(s.downloadDir);
  const bad = [...validateNumbers(s), ...validateTracker(s)];
  if (bad.length) throw new SettingsError(bad.join('\n'));
  assertDedicatedProfile(s.profileDir);
  assertOutsideRepo(s.profileDir, 'profileDir');
  assertOutsideRepo(s.downloadDir, 'downloadDir');
  return s;
}

/** A bad setting; render.mjs exits with code 2 on it. */
export class SettingsError extends Error {}

/**
 * delaySec and maxPerRun protect the quota, so a typo must not silently turn them off
 * (Number('abc') is NaN, and NaN > 0 is false).
 */
export function validateNumbers(s) {
  const errs = [];
  if (!(typeof s.delaySec === 'number' && Number.isFinite(s.delaySec) && s.delaySec >= 0)) {
    errs.push(`delaySec / --delay must be a number of seconds >= 0 (got ${JSON.stringify(s.delaySec)})`);
  }
  if (!(Number.isInteger(s.maxPerRun) && s.maxPerRun >= 1)) {
    errs.push(`maxPerRun must be a whole number >= 1 (got ${JSON.stringify(s.maxPerRun)})`);
  }
  return errs;
}

/** Tracker settings: https URL (loopback http only for tests) and a secret, both or neither. */
export function validateTracker(s) {
  const errs = [];
  if (!s.trackerUrl && !s.trackerSecret) return errs;
  if (!s.trackerUrl) errs.push('trackerSecret is set but trackerUrl is not (config.local.json or WEB_RENDER_TRACKER_URL)');
  else {
    let u = null;
    try { u = new URL(s.trackerUrl); } catch { errs.push('trackerUrl is not a valid URL'); }
    if (u && u.protocol !== 'https:' && !(trackerAllowsLoopbackHttp() && u.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(u.hostname))) {
      errs.push(`trackerUrl must be https:// (got ${u.protocol}//${u.host})`);
    }
  }
  if (s.trackerUrl && !s.trackerSecret) errs.push('trackerUrl is set but trackerSecret is not (config.local.json or WEB_RENDER_TRACKER_SECRET)');
  if (s.trackerSecret && String(s.trackerSecret).length < 32) errs.push('trackerSecret must be at least 32 characters (tools/render_tracker/configure.mjs --new-secret makes one)');
  if (!(typeof s.trackerMaxWaitSec === 'number' && Number.isFinite(s.trackerMaxWaitSec) && s.trackerMaxWaitSec >= 0)) {
    errs.push(`trackerMaxWaitSec must be a number of seconds >= 0 (got ${JSON.stringify(s.trackerMaxWaitSec)})`);
  }
  return errs;
}

/** Settings without the tracker secret, for run logs. */
export function publicSettings(s) {
  const { trackerSecret, ...rest } = s;
  return { ...rest, trackerSecret: trackerSecret ? '[set]' : null };
}

/** Parse --limit: a whole number >= 1, or throw SettingsError. undefined stays undefined. */
export function parseLimit(v) {
  if (v === undefined) return undefined;
  const n = Number(v);
  if (!(String(v).trim() !== '' && Number.isInteger(n) && n >= 1)) throw new SettingsError(`--limit must be a whole number >= 1 (got ${JSON.stringify(v)})`);
  return n;
}

/** Parse --delay: seconds >= 0, or throw SettingsError. */
export function parseDelay(v) {
  if (v === undefined) return undefined;
  const n = Number(v);
  if (!(String(v).trim() !== '' && Number.isFinite(n) && n >= 0)) throw new SettingsError(`--delay must be a number of seconds >= 0 (got ${JSON.stringify(v)})`);
  return n;
}

function expandHome(p) {
  return p && p.startsWith('~/') ? path.join(os.homedir(), p.slice(2)) : p;
}

// The author's everyday browser profile must never be used: refuse the standard locations.
const NORMAL_PROFILE_RE = [
  /[\\/]\.config[\\/](google-chrome(-beta|-unstable|-for-testing)?|chromium|BraveSoftware|microsoft-edge(-beta|-dev)?|vivaldi(-snapshot)?|opera(-beta|-developer)?)([\\/]|$)/i,
  /[\\/]snap[\\/](chromium|brave|opera|vivaldi)[\\/]/i,
  /[\\/]\.var[\\/]app[\\/](com\.google\.Chrome|org\.chromium\.Chromium|com\.brave\.Browser|com\.microsoft\.Edge)([\\/]|$)/i,
  /Google[\\/]Chrome[\\/]User Data/i,
  /Microsoft[\\/]Edge[\\/]User Data/i,
  /BraveSoftware[\\/]Brave-Browser[\\/]User Data/i,
  /Vivaldi[\\/]User Data/i,
  /[\\/]Library[\\/]Application Support[\\/](Google[\\/]Chrome|Microsoft Edge|BraveSoftware|Vivaldi)/i,
];

/**
 * Resolve symlinks in `p`, also when `p` (or its tail) does not exist yet: the longest existing
 * ancestor is realpath'd and the rest appended.
 */
export function realpathLoose(p) {
  let cur = path.resolve(p);
  const rest = [];
  for (;;) {
    try { return path.join(fs.realpathSync(cur), ...rest); } catch { /* does not exist yet */ }
    const up = path.dirname(cur);
    if (up === cur) return path.resolve(p);
    rest.unshift(path.basename(cur));
    cur = up;
  }
}

export function assertDedicatedProfile(dir) {
  if (!dir) throw new SettingsError('profileDir is not set');
  // Windows paths (C:\...) are only pattern-matched; POSIX paths are also checked after
  // following symlinks, so a link to ~/.config/google-chrome is refused too.
  const forms = /^[a-z]:[\\/]/i.test(dir) ? [dir] : [dir, realpathLoose(dir)];
  for (const f of forms) {
    if (NORMAL_PROFILE_RE.some((re) => re.test(f))) {
      throw new SettingsError(`refusing to use ${dir}${f !== dir ? ` (= ${f})` : ''}: that is a normal browser profile; use a dedicated automation profile`);
    }
  }
}

/** Cookies, session data and downloads must never land in the repo, where they could be committed. */
export function assertOutsideRepo(dir, what, root = ROOT) {
  if (!dir || /^[a-z]:[\\/]/i.test(dir)) return;
  const real = realpathLoose(dir);
  const repo = realpathLoose(root);
  if (real === repo || real.startsWith(repo + path.sep)) {
    throw new SettingsError(`refusing ${what} ${dir}: it is inside the repository (${repo}); put it outside, e.g. under ~/.local/share/persistint-web-render/`);
  }
}

// ---------------- selectors.json ----------------

export const STEP_ACTIONS = new Set(['goto', 'click', 'hover', 'waitFor', 'press', 'sleep']);
export const CAPTURE_ROUTES = new Set(['download', 'src']);
const KINDS = ['image', 'video', 'music'];

export function loadSelectors(file = SELECTORS_PATH, opts = {}) {
  const cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
  const errors = validateSelectors(cfg, opts);
  if (errors.length) throw new Error(`${file} is invalid:\n  - ${errors.join('\n  - ')}`);
  return cfg;
}

function checkSelectorList(list, where, errors) {
  if (!Array.isArray(list) || list.length === 0) { errors.push(`${where}: must be a non-empty array of selectors`); return; }
  list.forEach((s, i) => {
    if (typeof s !== 'string' || !s.trim()) errors.push(`${where}[${i}]: must be a non-empty string`);
    else {
      let depth = 0;
      for (const ch of s) { if (ch === '(') depth++; else if (ch === ')') depth--; if (depth < 0) break; }
      if (depth !== 0) errors.push(`${where}[${i}]: unbalanced parentheses in ${JSON.stringify(s)}`);
      if (/^(aria|text|xpath|pierce)\//.test(s)) errors.push(`${where}[${i}]: use ::-p-aria(...) / ::-p-text(...) instead of the legacy ${s.split('/')[0]}/ prefix`);
    }
  });
}

export function checkUrl(url, where, errors, { allowFileUrls = false } = {}) {
  let u;
  try { u = new URL(url); } catch { errors.push(`${where}: not a URL: ${url}`); return; }
  if (u.protocol === 'https:') return;
  if (allowFileUrls && u.protocol === 'file:') return;
  errors.push(`${where}: only https:// URLs are allowed (got ${u.protocol})`);
}

function checkSteps(steps, where, errors, opts) {
  if (!Array.isArray(steps)) { errors.push(`${where}: must be an array of steps`); return; }
  steps.forEach((st, i) => {
    const w = `${where}[${i}]`;
    if (!st || typeof st !== 'object') { errors.push(`${w}: must be an object`); return; }
    if (!STEP_ACTIONS.has(st.action)) { errors.push(`${w}: unknown action ${JSON.stringify(st.action)} (use ${[...STEP_ACTIONS].join(', ')})`); return; }
    if (st.action === 'goto') checkUrl(st.url, `${w}.url`, errors, opts);
    if (st.action === 'press' && (typeof st.key !== 'string' || !st.key)) errors.push(`${w}: press needs "key"`);
    if (st.action === 'sleep' && !(st.ms > 0)) errors.push(`${w}: sleep needs "ms" > 0`);
    if (['click', 'hover', 'waitFor'].includes(st.action) && st.target !== 'result') checkSelectorList(st.selectors, `${w}.selectors`, errors);
    if ('optional' in st && typeof st.optional !== 'boolean') errors.push(`${w}.optional: must be true/false`);
  });
}

/** Return a list of human-readable problems (empty = valid). */
export function validateSelectors(cfg, opts = {}) {
  const errors = [];
  if (!cfg || typeof cfg !== 'object') return ['top level must be an object'];
  if (!cfg.surfaces || typeof cfg.surfaces !== 'object') errors.push('"surfaces" object is missing');
  if (!cfg.kinds || typeof cfg.kinds !== 'object') errors.push('"kinds" object is missing');
  if (errors.length) return errors;
  if (cfg.loginUrl !== undefined) checkUrl(cfg.loginUrl, 'loginUrl', errors, opts);
  for (const k of KINDS) {
    const name = cfg.kinds[k];
    if (!name) errors.push(`kinds.${k}: missing`);
    else if (!cfg.surfaces[name]) errors.push(`kinds.${k}: surface "${name}" is not defined`);
    else if (cfg.surfaces[name].kind !== k) errors.push(`kinds.${k}: surface "${name}" has kind "${cfg.surfaces[name].kind}"`);
  }
  if (cfg.outcomeText !== undefined) {
    for (const k of ['quota', 'refused']) {
      const l = cfg.outcomeText?.[k];
      if (l !== undefined && !(Array.isArray(l) && l.every((p) => typeof p === 'string' && p.trim()))) errors.push(`outcomeText.${k}: must be an array of non-empty phrases`);
    }
  }
  for (const [name, s] of Object.entries(cfg.surfaces)) {
    const w = `surfaces.${name}`;
    if (!KINDS.includes(s.kind)) errors.push(`${w}.kind: must be one of ${KINDS.join(', ')}`);
    checkUrl(s.url, `${w}.url`, errors, opts);
    const st = s.steps || {};
    for (const key of ['open', 'mode', 'options']) if (st[key] !== undefined) checkSteps(st[key], `${w}.steps.${key}`, errors, opts);
    checkSelectorList(st.input, `${w}.steps.input`, errors);
    if (st.submit !== undefined) checkSteps(st.submit, `${w}.steps.submit`, errors, opts);
    else errors.push(`${w}.steps.submit: missing`);
    if (st.busy !== undefined && !(Array.isArray(st.busy) && st.busy.length === 0)) checkSelectorList(st.busy, `${w}.steps.busy`, errors);
    checkSelectorList(st.result, `${w}.steps.result`, errors);
    (st.result || []).forEach((sel, i) => {
      if (typeof sel === 'string' && sel.includes('::-p-')) errors.push(`${w}.steps.result[${i}]: result selectors must be plain CSS (they run in document.querySelectorAll)`);
    });
    if (st.response !== undefined) {
      checkSelectorList(st.response, `${w}.steps.response`, errors);
      (st.response || []).forEach((sel, i) => {
        if (typeof sel === 'string' && sel.includes('::-p-')) errors.push(`${w}.steps.response[${i}]: response selectors must be plain CSS (they run in document.querySelectorAll)`);
      });
    }
    if (st.limitNotice !== undefined) checkSelectorList(st.limitNotice, `${w}.steps.limitNotice`, errors);
    if (st.download !== undefined) checkSteps(st.download, `${w}.steps.download`, errors, opts);
    const cap = s.capture ?? ['download', 'src'];
    if (!Array.isArray(cap) || !cap.length || cap.some((c) => !CAPTURE_ROUTES.has(c))) {
      errors.push(`${w}.capture: must be a non-empty array of ${[...CAPTURE_ROUTES].join(' / ')}`);
    }
    if (cap.includes?.('download') && !st.download) errors.push(`${w}: capture includes "download" but steps.download is missing`);
    if (s.timeouts) for (const [k, v] of Object.entries(s.timeouts)) if (!(Number.isFinite(v) && v > 0)) errors.push(`${w}.timeouts.${k}: must be a positive number of ms`);
  }
  return errors;
}

/** Fill {aspect}, {prompt}, ... placeholders. */
export function fill(template, vars) {
  return String(template).replace(/\{(\w+)\}/g, (m, k) => (k in vars ? String(vars[k]) : m));
}
