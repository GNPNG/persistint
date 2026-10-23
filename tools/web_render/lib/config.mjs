// Settings (defaults < config.local.json < env < CLI) and selectors.json loading/validation.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { WEB_RENDER_DIR } from './tasks.mjs';

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
};

const ENV = {
  chrome: 'WEB_RENDER_CHROME', profileDir: 'WEB_RENDER_PROFILE', browserURL: 'WEB_RENDER_BROWSER_URL',
  downloadDir: 'WEB_RENDER_DOWNLOAD_DIR', downloadDirBrowser: 'WEB_RENDER_DOWNLOAD_DIR_BROWSER',
};

export function loadSettings(cli = {}) {
  let local = {};
  if (fs.existsSync(LOCAL_CONFIG_PATH)) local = JSON.parse(fs.readFileSync(LOCAL_CONFIG_PATH, 'utf8'));
  const s = { ...DEFAULTS, ...local };
  for (const [k, v] of Object.entries(ENV)) if (process.env[v]) s[k] = process.env[v];
  for (const [k, v] of Object.entries(cli)) if (v !== undefined && v !== null) s[k] = v;
  s.profileDir = expandHome(s.profileDir);
  s.downloadDir = expandHome(s.downloadDir);
  assertDedicatedProfile(s.profileDir);
  return s;
}

function expandHome(p) {
  return p && p.startsWith('~/') ? path.join(os.homedir(), p.slice(2)) : p;
}

// The author's everyday browser profile must never be used: refuse the standard locations.
const NORMAL_PROFILE_RE = [
  /[\\/]\.config[\\/](google-chrome|google-chrome-beta|chromium|BraveSoftware)([\\/]|$)/i,
  /[\\/]snap[\\/]chromium[\\/]/i,
  /Google[\\/]Chrome[\\/]User Data/i,
  /[\\/]Library[\\/]Application Support[\\/]Google[\\/]Chrome/i,
];
export function assertDedicatedProfile(dir) {
  if (!dir) throw new Error('profileDir is not set');
  if (NORMAL_PROFILE_RE.some((re) => re.test(dir))) {
    throw new Error(`refusing to use ${dir}: that is a normal browser profile; use a dedicated automation profile`);
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
  for (const k of KINDS) {
    const name = cfg.kinds[k];
    if (!name) errors.push(`kinds.${k}: missing`);
    else if (!cfg.surfaces[name]) errors.push(`kinds.${k}: surface "${name}" is not defined`);
    else if (cfg.surfaces[name].kind !== k) errors.push(`kinds.${k}: surface "${name}" has kind "${cfg.surfaces[name].kind}"`);
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
