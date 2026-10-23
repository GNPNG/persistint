// Render tracker: the author's Google Sheet as work queue and attempt log, reached through the
// Apps Script web app in tools/render_tracker/tracker_webapp.gs (see DEPLOY.md there).
//
//   TrackerClient       getQueue / start / end against the web app (shared secret, https only)
//   LocalAttemptsLog    the same start / end interface, appending to a local JSONL file
//   classifyOutcome     renderer error -> done | failed | quota | refused | timeout | selector | skipped
//   runTrackerLoop      the unattended loop: poll, throttle per kind, render, report, repeat
//
// No third-party imports, and fetch / clock / sleep are injectable, so the tests run against a
// local mock server without a browser or the network.
import fs from 'node:fs';
import path from 'node:path';
import { inspect } from 'node:util';

export const OUTCOMES = ['done', 'failed', 'quota', 'refused', 'timeout', 'selector', 'skipped'];
export const KINDS = ['image', 'video', 'music'];

export class TrackerError extends Error {
  constructor(message, { retryable = false, status = null } = {}) {
    super(message);
    this.retryable = retryable;
    this.status = status;
  }
}

/** Replace every occurrence of the secret (plain and URL-encoded) in `text`. */
export function redact(text, secret) {
  let s = String(text ?? '');
  if (!secret) return s;
  for (const form of new Set([secret, encodeURIComponent(secret)])) s = s.split(form).join('[secret]');
  return s;
}

const LOOPBACK = new Set(['127.0.0.1', 'localhost', '[::1]', '::1']);

/** https only; plain http is accepted for a loopback host only when allowLoopbackHttp (tests). */
export function checkTrackerUrl(url, { allowLoopbackHttp = false } = {}) {
  let u;
  try { u = new URL(url); } catch { throw new TrackerError('tracker URL is not a valid URL'); }
  if (u.protocol === 'https:') return u;
  if (allowLoopbackHttp && u.protocol === 'http:' && LOOPBACK.has(u.hostname)) return u;
  throw new TrackerError(`tracker URL must be https:// (got ${u.protocol}//${u.host})`);
}

const idOf = (a) => a.asset_id ?? a.id;

// ------------------------------------------------------------------ web app client

export class TrackerClient {
  #secret;

  /**
   * url: the web app's /exec URL. secret: TRACKER_SECRET. Neither the secret nor a URL that
   * carries it is ever put in a log line or error message.
   */
  constructor({ url, secret, fetchImpl = globalThis.fetch, allowLoopbackHttp = false,
    retries = 3, retryDelayMs = 3000, timeoutMs = 90_000, sleep = defaultSleep } = {}) {
    if (!url) throw new TrackerError('tracker URL is not set');
    if (!secret) throw new TrackerError('tracker secret is not set');
    this.url = checkTrackerUrl(url, { allowLoopbackHttp }).href;
    this.#secret = String(secret);
    this.allowLoopbackHttp = allowLoopbackHttp;
    this.fetchImpl = fetchImpl;
    this.retries = retries;
    this.retryDelayMs = retryDelayMs;
    this.timeoutMs = timeoutMs;
    this.sleep = sleep;
    this.kind = 'tracker';
  }

  toJSON() { return { url: this.url, secret: '[secret]' }; }
  [inspect.custom]() { return `TrackerClient { url: '${this.url}', secret: '[secret]' }`; }
  redact(text) { return redact(text, this.#secret); }

  /** Queue state: { now, kinds: {image: {...}, ...}, rows: [...] }. all=true includes rows of kinds that are not ready. */
  async getQueue({ kind = null, all = true, limit = 0 } = {}) {
    const u = new URL(this.url);
    u.searchParams.set('secret', this.#secret);
    if (kind) u.searchParams.set('kind', kind);
    if (all) u.searchParams.set('all', '1');
    if (limit) u.searchParams.set('limit', String(limit));
    const r = await this.#call('GET', u.href, null, 'queue');
    return { now: r.now, kinds: r.kinds || {}, rows: r.rows || [] };
  }

  async start(asset) {
    return this.#call('POST', this.url, { action: 'attempt_start', asset_id: idOf(asset), kind: asset.kind }, `attempt_start ${idOf(asset)}`);
  }

  /** info: { outcome, error, file, debugDir, runId, surface, started, note } */
  async end(asset, info = {}) {
    if (!OUTCOMES.includes(info.outcome)) throw new TrackerError(`unknown outcome: ${info.outcome}`);
    const body = {
      action: 'attempt_end', asset_id: idOf(asset), kind: asset.kind, outcome: info.outcome,
      error: this.redact(info.error || ''), file: info.file || '', debug_dir: info.debugDir || '',
      run_id: info.runId || '', surface: info.surface || '',
    };
    if (info.started) body.started = new Date(info.started).toISOString();
    if (info.note) body.note = this.redact(info.note);
    return this.#call('POST', this.url, body, `attempt_end ${idOf(asset)}`);
  }

  async #call(method, url, body, what) {
    let last;
    for (let i = 0; i <= this.retries; i++) {
      try {
        return await this.#once(method, url, body);
      } catch (e) {
        const err = e instanceof TrackerError ? e : new TrackerError(`network error: ${e.cause?.code || e.name || ''} ${e.message}`, { retryable: true });
        err.message = `tracker ${what}: ${this.redact(err.message)}`;
        err.stack = this.redact(err.stack);
        last = err;
        if (!err.retryable || i === this.retries) break;
        await this.sleep(this.retryDelayMs * 2 ** i);
      }
    }
    throw last;
  }

  async #once(method, url, body) {
    let target = url, m = method;
    let payload = body ? JSON.stringify({ ...body, secret: this.#secret }) : undefined;
    // Apps Script answers /exec with a 302 to script.googleusercontent.com; a POST is then read
    // with GET. Redirects are followed by hand so every hop is checked for https.
    for (let hop = 0; hop < 6; hop++) {
      checkTrackerUrl(target, { allowLoopbackHttp: this.allowLoopbackHttp });
      const res = await this.fetchImpl(target, {
        method: m,
        headers: payload ? { 'Content-Type': 'application/json' } : {},
        body: payload,
        redirect: 'manual',
        signal: AbortSignal.timeout(this.timeoutMs),
      });
      if ([301, 302, 303, 307, 308].includes(res.status)) {
        const loc = res.headers.get('location');
        if (!loc) throw new TrackerError(`HTTP ${res.status} without a Location header`);
        target = new URL(loc, target).href;
        if (res.status <= 303 && m !== 'GET') { m = 'GET'; payload = undefined; }
        continue;
      }
      const text = await res.text();
      let json;
      try { json = JSON.parse(text); } catch {
        const html = /^\s*</.test(text);
        throw new TrackerError(`HTTP ${res.status}: reply is not JSON${html ? ' but an HTML page (is the web app deployed with access "Anyone" and authorized once? see tools/render_tracker/DEPLOY.md)' : ''}`,
          { retryable: res.status >= 500 || res.status === 429, status: res.status });
      }
      if (!res.ok) throw new TrackerError(`HTTP ${res.status}: ${json.error || 'error'}`, { retryable: res.status >= 500 || res.status === 429, status: res.status });
      if (!json.ok) throw new TrackerError(String(json.error || 'request failed'), { retryable: /busy|lock|timed? ?out|service/i.test(String(json.error)) });
      return json;
    }
    throw new TrackerError('too many redirects');
  }
}

// ------------------------------------------------------------------ local JSONL log

/**
 * Offline fallback with the tracker's interface. One line per finished attempt, with the
 * Attempts tab's fields (timestamp, asset_id, kind, attempt, started, ended, duration_s,
 * outcome, error, surface, debug_dir, run_id) plus file and note.
 */
export class LocalAttemptsLog {
  constructor(file, { now = () => Date.now() } = {}) {
    this.file = file;
    this.now = now;
    this.kind = 'local';
    this.started = new Map();
    this.counts = new Map();
    try {
      for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
        if (!line.trim()) continue;
        try { const r = JSON.parse(line); this.counts.set(r.asset_id, Math.max(this.counts.get(r.asset_id) || 0, r.attempt || 0)); } catch { /* skip */ }
      }
    } catch { /* no log yet */ }
  }

  async start(asset) {
    this.started.set(idOf(asset), this.now());
    return { ok: true, asset_id: idOf(asset), kind: asset.kind };
  }

  async end(asset, info = {}) {
    if (!OUTCOMES.includes(info.outcome)) throw new TrackerError(`unknown outcome: ${info.outcome}`);
    const id = idOf(asset);
    const ended = this.now();
    const started = info.started ? new Date(info.started).getTime() : (this.started.get(id) ?? ended);
    const attempt = (this.counts.get(id) || 0) + 1;
    this.counts.set(id, attempt);
    this.started.delete(id);
    const rec = attemptRecord({ asset_id: id, kind: asset.kind, attempt, started, ended, ...info });
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.appendFileSync(this.file, JSON.stringify(rec) + '\n');
    return { ok: true, asset_id: id, kind: asset.kind, attempts: attempt };
  }
}

export const ATTEMPT_FIELDS = ['timestamp', 'asset_id', 'kind', 'attempt', 'started', 'ended', 'duration_s',
  'outcome', 'error', 'surface', 'debug_dir', 'run_id', 'file', 'note'];

export function attemptRecord(r) {
  const iso = (t) => new Date(t).toISOString();
  return {
    timestamp: iso(r.ended), asset_id: r.asset_id, kind: r.kind, attempt: r.attempt,
    started: iso(r.started), ended: iso(r.ended), duration_s: Math.round((r.ended - r.started) / 1000),
    outcome: r.outcome, error: r.error || '', surface: r.surface || '', debug_dir: r.debugDir || '',
    run_id: r.runId || '', file: r.file || '', note: r.note || '',
  };
}

// ------------------------------------------------------------------ outcome mapping

/** Phrases for outcome detection: quota from every limitNotice ::-p-text(...) plus selectors.json outcomeText. */
export function outcomePhrases(selectors = {}) {
  const quota = new Set(), refused = new Set();
  for (const s of Object.values(selectors.surfaces || {})) {
    for (const sel of s.steps?.limitNotice || []) {
      const m = /::-p-text\(([^)]+)\)/.exec(sel);
      if (m) quota.add(m[1].trim().toLowerCase());
    }
  }
  for (const p of selectors.outcomeText?.quota || []) quota.add(String(p).toLowerCase());
  for (const p of selectors.outcomeText?.refused || []) refused.add(String(p).toLowerCase());
  return { quota: [...quota], refused: [...refused] };
}

const has = (text, list) => { const t = String(text || '').toLowerCase().replace(/[’‘]/g, "'"); return (list || []).some((p) => p && t.includes(p)); };

/**
 * Map a render result or error to a tracker outcome.
 *   quota    usage-limit notice (limitNotice selectors -> e.abortRun), or a reply with no media
 *            whose text matches a quota phrase
 *   refused  a reply with no media whose text matches a refusal phrase (policy / can't generate).
 *            A reply with no media and no such phrase (e.g. a signed-out page) is "failed", so it
 *            is retried instead of being parked as "Needs prompt edit".
 *   timeout  no result / no download in time, or a navigation timeout
 *   selector a step's selectors matched nothing
 *   skipped  assist mode, the author typed s
 *   failed   anything else
 */
export function classifyOutcome(errOrResult, phrases = { quota: [], refused: [] }) {
  if (errOrResult == null) return 'done';
  if (!(errOrResult instanceof Error)) return errOrResult.skipped ? 'skipped' : 'done';
  const e = errOrResult;
  const msg = String(e.message || '');
  const textOnly = e.textOnly || /finished without any media/.test(msg);
  const reply = e.replyText ?? msg;
  if (e.abortRun || /usage limit notice/.test(msg)) return 'quota';
  if (textOnly) {
    if (has(reply, phrases.quota)) return 'quota';
    if (has(reply, phrases.refused)) return 'refused';
    return 'failed';
  }
  if (e.name === 'TimeoutError' || /no new result within|no completed download within|timed? ?out|timeout/i.test(msg)) return 'timeout';
  if (/none of these matched a visible element|no result element to act on|never appeared \(page not hydrated/.test(msg)) return 'selector';
  return 'failed';
}

const norm = (s) => String(s ?? '').replace(/\s+/g, ' ').trim();

/** A note for end() when the sheet's prompt is not the repo prompt (the repo prompt is what gets rendered). */
export function promptDiffNote(sheetPrompt, repoPrompt, mdPath = '') {
  if (!norm(sheetPrompt) || norm(sheetPrompt) === norm(repoPrompt)) return '';
  return `prompt in sheet differs from ${mdPath || 'the repo prompt'}; rendered the repo prompt`;
}

// ------------------------------------------------------------------ the loop

function defaultSleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
const ms = (iso) => (iso ? new Date(iso).getTime() : 0);
export const fmtTime = (t) => `${new Date(t).toLocaleString()} (${new Date(t).toISOString()})`;

/**
 * Run until nothing is eligible. Per poll (getQueue all=1):
 *   - a kind is skipped when Remaining Today is 0 (until tomorrow), when it hit a quota this run,
 *   - it waits while its Min Gap or quota cooldown (kind_next_eligible, and the local time since
 *     this process last finished one of that kind) has not passed,
 *   - otherwise the first eligible row of the kind that rendered least recently is rendered,
 *     wrapped in start() / end(). Then the queue is polled again.
 * When nothing is eligible: wait if the next eligible time is within maxWaitSec, else return.
 *
 * opts: client (TrackerClient or LocalAttemptsLog-like with getQueue), tasks, renderOne(task, row),
 *   kinds, only (Set of ids), force, limit, maxWaitSec, runId, surfaceFor(kind), phrases,
 *   localLog (LocalAttemptsLog mirror), now, sleep, log, isStopping, state ({current} for Ctrl-C)
 * returns { results, reason, nextEligible }
 */
export async function runTrackerLoop(opts) {
  const {
    client, tasks, renderOne, kinds = KINDS, only = null, force = false, limit = Infinity,
    maxWaitSec = 1800, runId = '', surfaceFor = (k) => k, phrases = { quota: [], refused: [] },
    localLog = null, now = () => Date.now(), sleep = defaultSleep, log = console.log,
    isStopping = () => false, state = {}, perAssetMax = 5, idleMax = 200,
  } = opts;
  const byId = new Map(tasks.map((t) => [t.id, t]));
  const scrub = (txt) => (typeof client.redact === 'function' ? client.redact(txt) : String(txt));
  const lastEnd = {};
  const stopped = new Set();
  const perId = new Map();
  const results = [];
  let renders = 0, idle = 0;

  const finish = async (row, info) => {
    const full = { runId, surface: surfaceFor(row.kind), ...info };
    let res = null;
    try {
      res = await client.end(row, full);
    } finally {
      if (localLog) await localLog.end(row, full).catch(() => {});
    }
    results.push({ id: row.asset_id, kind: row.kind, ...info, status: res?.status, next_eligible: res?.next_eligible ?? null });
    return res;
  };

  for (;;) {
    if (isStopping()) return { results, reason: 'stopped', nextEligible: null };
    if (renders >= limit) return { results, reason: 'limit', nextEligible: null };
    const q = await client.getQueue({ kind: kinds.length === 1 ? kinds[0] : null, all: true });
    const t = now();
    const candidates = [], wakes = [], capped = [];
    for (const kind of kinds) {
      const s = q.kinds[kind];
      if (!s || stopped.has(kind)) continue;
      const rows = q.rows.filter((r) => r.kind === kind && (!only || only.has(r.asset_id)) && (perId.get(r.asset_id) || 0) < perAssetMax);
      if (!(s.remaining_today > 0)) { if (rows.length || s.next_row_eligible) capped.push(kind); continue; }
      let blockedUntil = Math.max(ms(s.kind_next_eligible), lastEnd[kind] ? lastEnd[kind] + (s.min_gap_s || 0) * 1000 : 0);
      const why = ms(s.last_quota_hit) && ms(s.last_quota_hit) + (s.cooldown_min || 0) * 60_000 >= blockedUntil ? 'quota cooldown' : 'min gap';
      if (rows.length) {
        if (blockedUntil > t) wakes.push({ at: blockedUntil, kind, why });
        else candidates.push({ kind, row: rows[0] });
      } else if (s.next_row_eligible) {
        wakes.push({ at: Math.max(ms(s.next_row_eligible), blockedUntil), kind, why: 'retry backoff' });
      }
    }

    if (candidates.length) {
      idle = 0;
      candidates.sort((a, b) => (lastEnd[a.kind] || 0) - (lastEnd[b.kind] || 0));
      const { kind, row } = candidates[0];
      const id = row.asset_id;
      perId.set(id, (perId.get(id) || 0) + 1);
      const task = byId.get(id);
      if (!task || task.kind !== kind) {
        const error = task ? `asset ${id} is ${task.kind} in prompts/ but on the ${kind} tab` : `no prompt file in prompts/ with id ${id}`;
        log(`[skip] ${kind} ${id}: ${error}`);
        await finish(row, { outcome: 'skipped', error });
        continue;
      }
      if (!force && task.exists) {
        log(`[done] ${kind} ${id}: ${task.drop} already exists; marked done without generating`);
        await finish(row, { outcome: 'done', file: task.drop, note: 'drop file already existed; not generated again' });
        continue;
      }
      if (!force && task.beside) {
        const error = `captured in another format (${path.extname(task.beside)}) beside the drop; run --convert`;
        log(`[skip] ${kind} ${id}: ${error}`);
        await finish(row, { outcome: 'skipped', error });
        continue;
      }
      const note = promptDiffNote(row.prompt, task.prompt, task.md_path);
      if (note) log(`  note: ${note}`);
      await client.start(row);
      const started = now();
      state.current = { row, started };
      const info = { started, note };
      log(`\n[${renders + 1}] ${kind} ${id} (attempt ${(row.attempts || 0) + 1})`);
      try {
        const r = await renderOne(task, row);
        info.outcome = classifyOutcome(r, phrases);
        if (info.outcome === 'done') info.file = task.drop;
      } catch (e) {
        info.outcome = classifyOutcome(e, phrases);
        info.error = scrub(String(e.message || e).split('\n').slice(0, 3).join(' ').slice(0, 900));
        if (e.debugDir) info.debugDir = e.debugDir;
      } finally {
        state.current = null;
      }
      renders++;
      const res = await finish(row, info);
      lastEnd[kind] = now();
      log(`  -> ${info.outcome}${info.error ? `: ${info.error.slice(0, 200)}` : ''}${res?.next_eligible ? ` (retry after ${fmtTime(ms(res.next_eligible))})` : ''}`);
      if (info.outcome === 'quota') {
        stopped.add(kind);
        log(`  !! ${kind}: usage limit reached; no more ${kind} this run (the sheet applies its cooldown)`);
      }
      continue;
    }

    if (++idle > idleMax) return { results, reason: 'idle', nextEligible: null };
    if (wakes.length) {
      wakes.sort((a, b) => a.at - b.at);
      const w = wakes[0];
      const wait = Math.max(w.at - t, 0) + 2000;
      if (wait <= maxWaitSec * 1000) {
        log(`  waiting ${Math.round(wait / 1000)}s for ${w.kind} (${w.why}) ...`);
        await sleep(wait);
        continue;
      }
      return { results, reason: 'later', nextEligible: w.at, wakes, capped, stopped: [...stopped] };
    }
    return { results, reason: capped.length ? 'cap' : 'empty', nextEligible: null, capped, stopped: [...stopped] };
  }
}

/** One line per kind for --queue and the end-of-run summary. */
export function describeQueue(q, kinds = KINDS) {
  const lines = [];
  for (const k of kinds) {
    const s = q.kinds[k];
    if (!s) continue;
    const n = q.rows.filter((r) => r.kind === k).length;
    lines.push(`${k.padEnd(6)} eligible ${String(n).padStart(3)}  used ${s.used_today}/${s.daily_cap} today  min gap ${s.min_gap_s}s` +
      `${s.ready ? '  ready' : `  not ready${s.kind_next_eligible ? ` until ${fmtTime(ms(s.kind_next_eligible))}` : ''}`}` +
      `${s.last_quota_hit ? `  last quota ${fmtTime(ms(s.last_quota_hit))}` : ''}` +
      `${s.next_row_eligible ? `  next retry ${fmtTime(ms(s.next_row_eligible))}` : ''}`);
  }
  return lines.join('\n');
}
