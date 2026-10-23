// A local stand-in for tools/render_tracker/tracker_webapp.gs: the same JSON contract (doGet
// queue, doPost attempt_start / attempt_end, shared secret) and the same arithmetic (daily cap,
// min gap, quota cooldown, retry backoff, max retries, stale Rendering), on an injectable clock.
// Like Apps Script, a POST is answered with a 302 to a URL that serves the result with GET.
import http from 'node:http';

const COUNTED = ['done', 'failed', 'refused', 'timeout', 'selector'];
const RETRY = ['failed', 'timeout', 'selector'];
const OUTCOMES = ['done', 'failed', 'quota', 'refused', 'timeout', 'selector', 'skipped'];
const DEFAULT_QUOTA = { dailyCap: 20, minGap: 60, cooldown: 240, maxRetries: 3, backoff: 120 };
const STALE_RENDERING_MIN = 120;

export async function startMockTracker({ secret, clock = { t: Date.now() }, quotas = {}, rows = [], redirect = true } = {}) {
  const state = {
    rows: rows.map((r, i) => ({
      step: i + 1, status: 'Pending', attempts: 0, lastAttempt: null, lastOutcome: '', lastError: '',
      nextEligible: null, renderedFile: '', notes: '', prompt: '', ...r,
    })),
    attempts: [],
    requests: [],
  };
  const now = () => new Date(clock.t);
  const quotaFor = (kind) => ({ ...DEFAULT_QUOTA, ...(quotas[kind] || {}) });
  const iso = (d) => (d ? new Date(d).toISOString() : null);
  const day = (d) => new Date(d).toISOString().slice(0, 10);
  const failures = (kind, id) => state.attempts.filter((a) => a.kind === kind && a.id === id && RETRY.includes(a.outcome)).length;
  const find = (kind, id) => {
    const r = state.rows.find((x) => x.asset_id === id && (!kind || x.kind === kind));
    if (!r) throw new Error(`asset not found: ${id}`);
    return r;
  };

  function kindState(kind) {
    const q = quotaFor(kind);
    const t = now();
    let used = 0, lastQuota = null, lastEnd = null;
    for (const a of state.attempts) {
      if (a.kind !== kind) continue;
      if (COUNTED.includes(a.outcome) && day(a.ts) === day(t)) used++;
      if (a.outcome === 'quota' && (!lastQuota || a.ts > lastQuota)) lastQuota = a.ts;
      if (!lastEnd || a.ended > lastEnd) lastEnd = a.ended;
    }
    let nextT = 0;
    if (lastQuota) nextT = Math.max(nextT, lastQuota.getTime() + q.cooldown * 60_000);
    if (lastEnd) nextT = Math.max(nextT, lastEnd.getTime() + q.minGap * 1000);
    const remaining = Math.max(0, q.dailyCap - used);
    return {
      daily_cap: q.dailyCap, used_today: used, remaining_today: remaining, min_gap_s: q.minGap,
      cooldown_min: q.cooldown, max_retries: q.maxRetries, retry_backoff_s: q.backoff,
      last_quota_hit: iso(lastQuota), last_attempt_end: iso(lastEnd),
      kind_next_eligible: nextT ? iso(nextT) : null, next_row_eligible: null,
      ready: remaining > 0 && nextT <= t.getTime(),
    };
  }

  function queue(onlyKind, all, limit) {
    const t = now();
    const kinds = {};
    let out = [];
    for (const kind of ['image', 'video', 'music']) {
      if (onlyKind && kind !== onlyKind) continue;
      const k = kindState(kind);
      kinds[kind] = k;
      let picked = 0;
      for (const r of state.rows.filter((x) => x.kind === kind)) {
        const retryable = r.status === 'Failed' || r.status === 'Quota';
        if (retryable && r.nextEligible && r.nextEligible > t &&
            (!k.next_row_eligible || r.nextEligible < new Date(k.next_row_eligible))) k.next_row_eligible = iso(r.nextEligible);
        const eligible = r.status === 'Pending' || (retryable && r.nextEligible && r.nextEligible <= t) ||
          (r.status === 'Rendering' && (!r.lastAttempt || r.lastAttempt.getTime() < t.getTime() - STALE_RENDERING_MIN * 60_000));
        if (!eligible) continue;
        if (!all && (!k.ready || picked >= k.remaining_today)) continue;
        out.push({ asset_id: r.asset_id, kind, step: r.step, status: r.status, attempts: r.attempts,
          failures: failures(kind, r.asset_id), spec: '', drop: '', game: '', prompt: r.prompt, next_eligible: iso(r.nextEligible) });
        picked++;
      }
    }
    if (limit > 0) out = out.slice(0, limit);
    return { ok: true, now: iso(t), kinds, rows: out };
  }

  function attemptStart(b) {
    const r = find(b.kind, b.asset_id);
    r.attempts += 1;
    r.status = 'Rendering';
    r.lastAttempt = now();
    return { ok: true, asset_id: b.asset_id, kind: r.kind, status: 'Rendering', attempts: r.attempts };
  }

  function attemptEnd(b) {
    const outcome = String(b.outcome || '').toLowerCase();
    if (!OUTCOMES.includes(outcome)) throw new Error(`unknown outcome: ${b.outcome}`);
    const r = find(b.kind, b.asset_id);
    const t = now();
    const q = quotaFor(r.kind);
    let started;
    if (r.status !== 'Rendering') { r.attempts += 1; started = b.started ? new Date(b.started) : t; }
    else started = b.started ? new Date(b.started) : (r.lastAttempt || t);
    state.attempts.push({ ts: t, id: b.asset_id, kind: r.kind, n: r.attempts, started, ended: t, outcome,
      error: b.error || '', surface: b.surface || '', debug_dir: b.debug_dir || '', run_id: b.run_id || '', file: b.file || '', note: b.note || '' });
    const f = failures(r.kind, b.asset_id);
    let status, next = null;
    if (outcome === 'done') status = 'Done';
    else if (outcome === 'quota') { status = 'Quota'; next = new Date(t.getTime() + q.cooldown * 60_000); }
    else if (outcome === 'refused') status = 'Needs prompt edit';
    else if (outcome === 'skipped') status = 'Skipped';
    else {
      status = 'Failed';
      if (f < q.maxRetries) next = new Date(t.getTime() + q.backoff * 2 ** Math.max(0, f - 1) * 1000);
    }
    Object.assign(r, { status, lastAttempt: started, lastOutcome: outcome, lastError: outcome === 'done' ? '' : (b.error || ''), nextEligible: next });
    if (outcome === 'done' && b.file) r.renderedFile = b.file;
    if (b.note && !r.notes.includes(b.note)) r.notes = r.notes ? `${r.notes}\n${b.note}` : b.note;
    return { ok: true, asset_id: b.asset_id, kind: r.kind, status, attempts: r.attempts, failures: f, next_eligible: iso(next) };
  }

  const results = new Map();
  let seq = 0;
  const send = (res, code, obj, headers = {}) => { res.writeHead(code, { 'Content-Type': 'application/json', ...headers }); res.end(JSON.stringify(obj)); };

  const server = http.createServer((req, res) => {
    const u = new URL(req.url, 'http://127.0.0.1');
    let raw = '';
    req.on('data', (d) => { raw += d; });
    req.on('end', () => {
      if (req.method === 'GET' && u.pathname.startsWith('/echo/')) {
        const r = results.get(u.pathname.slice(6));
        return r ? send(res, 200, r) : send(res, 404, { ok: false, error: 'gone' });
      }
      if (u.pathname !== '/exec') return send(res, 404, { ok: false, error: 'not found' });
      if (req.method === 'GET') {
        state.requests.push({ method: 'GET', params: Object.fromEntries(u.searchParams) });
        if (u.searchParams.get('secret') !== secret) return send(res, 200, { ok: false, error: 'unauthorized' });
        return send(res, 200, queue(u.searchParams.get('kind'), ['1', 'true'].includes(u.searchParams.get('all')), Number(u.searchParams.get('limit') || 0)));
      }
      let body = {};
      let result;
      try { body = JSON.parse(raw || '{}'); } catch { result = { ok: false, error: 'invalid JSON body' }; }
      state.requests.push({ method: 'POST', body });
      if (!result) {
        if (body.secret !== secret) result = { ok: false, error: 'unauthorized' };
        else {
          try {
            if (body.action === 'attempt_start') result = attemptStart(body);
            else if (body.action === 'attempt_end') result = attemptEnd(body);
            else result = { ok: false, error: `unknown action: ${body.action}` };
          } catch (e) { result = { ok: false, error: e.message }; }
        }
      }
      if (!redirect) return send(res, 200, result);
      const token = String(++seq);
      results.set(token, result);
      res.writeHead(302, { Location: `/echo/${token}` });
      res.end();
    });
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${server.address().port}/exec`;
  return {
    url, state, clock,
    row: (id) => state.rows.find((r) => r.asset_id === id),
    close: () => new Promise((r) => server.close(r)),
  };
}
