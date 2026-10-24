/**
 * Render tracker web app (Google Apps Script).
 *
 * Write-back endpoint for an asset render queue kept in a Google Sheet:
 * one tab per asset kind (image / video / music), an append-only "Attempts"
 * log and a "Quotas" tab with per-kind caps, gaps, cooldowns and retry limits.
 * Generic: tab names, header names and outcome rules are all in CONFIG below,
 * so the same script works for another project's tracker (e.g. seedfall).
 *
 * Setup: see DEPLOY.md next to this file (keyboard-only, with clasp: deploy.sh does it all).
 *   By hand instead:
 *   1. Extensions > Apps Script in the tracker spreadsheet, paste this file.
 *   2. Project Settings > Script Properties: add TRACKER_SECRET = <long random string>.
 *      (Optional) SPREADSHEET_ID if the script is standalone rather than bound.
 *      Or push a tracker_secret.local.gs defining TRACKER_SECRET_LOCAL (written by
 *      deploy.mjs, gitignored); the first request copies it into the Script Property.
 *   3. Deploy > New deployment > Web app; Execute as: Me; Who has access: Anyone
 *      (the shared secret is the access control). Copy the /exec URL into the renderer.
 *
 * POST (Content-Type: application/json), body:
 *   { "secret": "...", "action": "attempt_start" | "attempt_end" | "reset",
 *     "asset_id": "key_art_temple", "kind": "image",
 *     "outcome": "done|failed|quota|refused|timeout|selector|skipped|blocked",   // attempt_end
 *     "error": "...", "file": "path/of/rendered/file", "debug_dir": "...",
 *     "run_id": "...", "surface": "gemini web / model name",
 *     "started": "2026-10-23T10:00:00Z",  // optional; default = Last Attempt set by attempt_start
 *     "note": "..."                        // optional; appended to the row's Notes cell (once)
 *   }
 *   -> { ok: true, asset_id, kind, status, attempts, next_eligible }
 *   outcome "blocked" = Google's "unusual traffic" check page stopped the renderer before it could
 *   render: the attempt is logged, the row goes back to Pending with no Next Eligible, and it
 *   neither counts against the Daily Cap nor starts a cooldown or a retry backoff.
 *
 *   action "reset": { asset_id, kind (optional), run_id, from_outcome, to_outcome (all three
 *   optional) } -> the row is set to Pending with Next Eligible cleared; with run_id, that run's
 *   Attempts entries of the asset whose Outcome is from_outcome get to_outcome instead (e.g. a
 *   check page logged as 'quota' becomes 'blocked', which lifts the kind's quota cooldown).
 *   -> { ok: true, asset_id, kind, status: 'Pending', relabeled: N }
 *
 * GET  ?secret=...&kind=image|video|music (optional)&all=1 (optional)&limit=N (optional)
 *   -> { ok: true, now, kinds: { image: {daily_cap, used_today, remaining_today, min_gap_s,
 *        cooldown_min, max_retries, retry_backoff_s, last_quota_hit, last_attempt_end,
 *        kind_next_eligible, next_row_eligible, ready}, ... },
 *        rows: [ {asset_id, kind, step, status, attempts, failures, spec, drop, game, prompt,
 *                 next_eligible}, ... ] }
 *   rows = Pending rows, plus Failed/Quota rows whose Next Eligible has passed, plus
 *   Rendering rows whose Last Attempt is older than STALE_RENDERING_MIN (a renderer that died
 *   between attempt_start and attempt_end). next_row_eligible = the earliest future Next
 *   Eligible of a Failed/Quota row of that kind (the next retry), or null.
 *   Unless all=1, rows of a kind that is not ready (cap used up, quota cooldown,
 *   or min gap not yet elapsed) are left out.
 *
 * Timestamps are written as Date objects (shown as yyyy-mm-ddThh:mm:ss in the
 * spreadsheet time zone). The Quotas formulas depend on that; do not write ISO strings.
 * All writes take a script lock so concurrent renderers cannot interleave.
 */

var CONFIG = {
  // kind -> tab name. Kind strings must match the Attempts "Kind" column and the Quotas "Kind" column.
  KIND_TABS: {
    image: 'Images (Gemini Image)',
    video: 'Video (Gemini Veo)',
    music: 'Audio (Gemini Lyria)'
  },
  ATTEMPTS_TAB: 'Attempts',
  QUOTAS_TAB: 'Quotas',

  // Header names on the kind tabs (columns are found by header, so order can change).
  KIND_COLS: {
    step: 'Step',
    status: 'Status',
    id: 'Asset ID',
    spec: 'Spec / Format',
    drop: 'Drop Path (Save Rendered File To)',
    game: 'Engine Target (game:)',
    prompt: 'Self-Contained Copy-Paste Prompt',
    attempts: 'Attempts',
    lastAttempt: 'Last Attempt',
    lastOutcome: 'Last Outcome',
    lastError: 'Last Error',
    nextEligible: 'Next Eligible',
    renderedFile: 'Rendered File',
    notes: 'Notes'
  },

  // Attempts tab column order (append-only log). Must match the header row.
  ATTEMPTS_HEADERS: ['Timestamp', 'Asset ID', 'Kind', 'Attempt #', 'Started', 'Ended',
                     'Duration s', 'Outcome', 'Error', 'Surface/Model', 'Debug Dir', 'Run ID'],

  // Quotas tab header names.
  QUOTA_COLS: {
    kind: 'Kind',
    dailyCap: 'Daily Cap',
    minGap: 'Min Gap (s)',
    cooldown: 'Cooldown After Quota (min)',
    maxRetries: 'Max Retries',
    backoff: 'Retry Backoff (s)'
  },
  // Used when a Quotas cell is blank.
  QUOTA_DEFAULTS: { dailyCap: 20, minGap: 60, cooldown: 240, maxRetries: 3, backoff: 120 },

  // Status values (must match the Status dropdown).
  STATUS: {
    pending: 'Pending', rendering: 'Rendering', done: 'Done', failed: 'Failed',
    quota: 'Quota', refused: 'Refused', needsEdit: 'Needs prompt edit', skipped: 'Skipped'
  },
  OUTCOMES: ['done', 'failed', 'quota', 'refused', 'timeout', 'selector', 'skipped', 'blocked'],
  // Outcomes that use up the daily cap (quota/skipped/blocked do not).
  COUNTED_OUTCOMES: ['done', 'failed', 'refused', 'timeout', 'selector'],
  // Outcomes that are retried with backoff, up to Max Retries.
  RETRY_OUTCOMES: ['failed', 'timeout', 'selector'],
  // Backoff = Retry Backoff (s) * BACKOFF_FACTOR^(failures - 1).
  BACKOFF_FACTOR: 2,
  // A row left in Rendering longer than this (renderer killed mid-asset) is offered again.
  STALE_RENDERING_MIN: 120,
  // Used when the script is neither bound to the spreadsheet nor given SPREADSHEET_ID.
  DEFAULT_SPREADSHEET_ID: '1WNbk19jM4_gVMklRA4rdA8Im9K_v8rb7VdvDFVc8geA',
  LOCK_WAIT_MS: 30000
};

// ---------------------------------------------------------------- entry points

function doPost(e) {
  var body;
  try {
    body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return json_({ ok: false, error: 'invalid JSON body' });
  }
  if (!checkSecret_(body.secret)) return json_({ ok: false, error: 'unauthorized' });

  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(CONFIG.LOCK_WAIT_MS);
  } catch (err) {
    return json_({ ok: false, error: 'busy: could not get lock' });
  }
  try {
    if (body.action === 'attempt_start') return json_(attemptStart_(body));
    if (body.action === 'attempt_end') return json_(attemptEnd_(body));
    if (body.action === 'reset') return json_(reset_(body));
    return json_({ ok: false, error: 'unknown action: ' + body.action });
  } catch (err) {
    return json_({ ok: false, error: String(err && err.message || err) });
  } finally {
    SpreadsheetApp.flush();
    lock.releaseLock();
  }
}

function doGet(e) {
  var p = (e && e.parameter) || {};
  if (!checkSecret_(p.secret)) return json_({ ok: false, error: 'unauthorized' });
  try {
    return json_(queue_(p.kind || null, p.all === '1' || p.all === 'true', p.limit ? Number(p.limit) : 0));
  } catch (err) {
    return json_({ ok: false, error: String(err && err.message || err) });
  }
}

// ---------------------------------------------------------------- actions

function attemptStart_(b) {
  var ctx = findAsset_(b.kind, b.asset_id);
  var now = new Date();
  var n = toNum_(ctx.get('attempts')) + 1;
  ctx.set('status', CONFIG.STATUS.rendering);
  ctx.set('attempts', n);
  ctx.set('lastAttempt', now);
  ctx.save();
  return { ok: true, asset_id: b.asset_id, kind: ctx.kind, status: CONFIG.STATUS.rendering, attempts: n };
}

function attemptEnd_(b) {
  var outcome = String(b.outcome || '').toLowerCase();
  if (CONFIG.OUTCOMES.indexOf(outcome) < 0) throw new Error('unknown outcome: ' + b.outcome);
  var ctx = findAsset_(b.kind, b.asset_id);
  var now = new Date();
  var q = quotaFor_(ctx.kind);

  // If attempt_start was never called for this attempt, count it now.
  var attempts = toNum_(ctx.get('attempts'));
  var started;
  if (ctx.get('status') !== CONFIG.STATUS.rendering) {
    attempts += 1;
    started = b.started ? new Date(b.started) : now;
  } else {
    started = b.started ? new Date(b.started) : (asDate_(ctx.get('lastAttempt')) || now);
  }

  // Append-only log row.
  var sh = sheet_(CONFIG.ATTEMPTS_TAB);
  sh.appendRow([now, b.asset_id, ctx.kind, attempts, started, now,
                Math.round((now - started) / 1000), outcome, b.error || '',
                b.surface || '', b.debug_dir || '', b.run_id || '']);

  var status, next = '';
  var failures = countFailures_(ctx.kind, b.asset_id);   // includes the row just appended
  if (outcome === 'done') {
    status = CONFIG.STATUS.done;
  } else if (outcome === 'quota') {
    status = CONFIG.STATUS.quota;
    next = new Date(now.getTime() + q.cooldown * 60 * 1000);
  } else if (outcome === 'refused') {
    status = CONFIG.STATUS.needsEdit;          // no auto-retry; a human edits the prompt in the repo
  } else if (outcome === 'skipped') {
    status = CONFIG.STATUS.skipped;
  } else if (outcome === 'blocked') {
    status = CONFIG.STATUS.pending;            // the asset is fine; the renderer's session needs a human
  } else {                                     // failed / timeout / selector
    status = CONFIG.STATUS.failed;
    if (failures < q.maxRetries) {
      var waitS = q.backoff * Math.pow(CONFIG.BACKOFF_FACTOR, Math.max(0, failures - 1));
      next = new Date(now.getTime() + waitS * 1000);
    }                                          // else retries exhausted: Next Eligible stays blank
  }

  ctx.set('status', status);
  ctx.set('attempts', attempts);
  ctx.set('lastAttempt', started);
  ctx.set('lastOutcome', outcome);
  ctx.set('lastError', outcome === 'done' ? '' : (b.error || ''));
  ctx.set('nextEligible', next);
  if (outcome === 'done' && b.file) ctx.set('renderedFile', b.file);
  if (b.note) {
    var notes = String(ctx.get('notes') || '');
    var note = String(b.note).slice(0, 500);
    if (notes.indexOf(note) < 0) ctx.set('notes', notes ? notes + '\n' + note : note);
  }
  ctx.save();

  return { ok: true, asset_id: b.asset_id, kind: ctx.kind, status: status, attempts: attempts,
           failures: failures, next_eligible: next ? iso_(next) : null };
}

function reset_(b) {
  var ctx = findAsset_(b.kind, b.asset_id);
  var relabeled = 0;
  if (b.run_id && b.from_outcome && b.to_outcome) {
    var to = String(b.to_outcome).toLowerCase();
    if (CONFIG.OUTCOMES.indexOf(to) < 0) throw new Error('unknown outcome: ' + b.to_outcome);
    var from = String(b.from_outcome).toLowerCase();
    var sh = sheet_(CONFIG.ATTEMPTS_TAB);
    var last = sh.getLastRow();
    if (last >= 2) {
      var h = CONFIG.ATTEMPTS_HEADERS;
      var iId = h.indexOf('Asset ID'), iKind = h.indexOf('Kind'), iOut = h.indexOf('Outcome'), iRun = h.indexOf('Run ID');
      var data = sh.getRange(2, 1, last - 1, h.length).getValues();
      for (var r = 0; r < data.length; r++) {
        if (String(data[r][iId]).trim() === b.asset_id && data[r][iKind] === ctx.kind &&
            String(data[r][iRun]) === String(b.run_id) && String(data[r][iOut]).toLowerCase() === from) {
          sh.getRange(r + 2, iOut + 1).setValue(to);
          relabeled++;
        }
      }
    }
  }
  ctx.set('status', CONFIG.STATUS.pending);
  ctx.set('nextEligible', '');
  ctx.save();
  return { ok: true, asset_id: b.asset_id, kind: ctx.kind, status: CONFIG.STATUS.pending, relabeled: relabeled };
}

function queue_(onlyKind, all, limit) {
  var now = new Date();
  var log = readAttempts_();
  var kinds = {};
  var rows = [];
  Object.keys(CONFIG.KIND_TABS).forEach(function (kind) {
    if (onlyKind && kind !== onlyKind) return;
    var q = quotaFor_(kind);
    var k = kindState_(kind, q, log, now);
    kinds[kind] = k;
    k.next_row_eligible = null;

    var sh = sheet_(CONFIG.KIND_TABS[kind]);
    var data = sh.getDataRange().getValues();
    var col = headerIndex_(data[0], CONFIG.KIND_COLS, CONFIG.KIND_TABS[kind]);
    var picked = 0;
    var staleBefore = now.getTime() - CONFIG.STALE_RENDERING_MIN * 60 * 1000;
    for (var r = 1; r < data.length; r++) {
      var row = data[r];
      var id = row[col.id];
      if (!id) continue;
      var st = row[col.status];
      var ne = asDate_(row[col.nextEligible]);
      var la = asDate_(row[col.lastAttempt]);
      var retryable = st === CONFIG.STATUS.failed || st === CONFIG.STATUS.quota;
      if (retryable && ne && ne > now &&
          (!k.next_row_eligible || ne.getTime() < new Date(k.next_row_eligible).getTime())) {
        k.next_row_eligible = iso_(ne);
      }
      var eligible = st === CONFIG.STATUS.pending ||
        (retryable && ne && ne <= now) ||
        (st === CONFIG.STATUS.rendering && (!la || la.getTime() < staleBefore));
      if (!eligible) continue;
      if (!all && (!k.ready || picked >= k.remaining_today)) continue;
      rows.push({
        asset_id: id, kind: kind, step: row[col.step], status: st,
        attempts: toNum_(row[col.attempts]), failures: countFailuresIn_(log, kind, id),
        spec: row[col.spec], drop: row[col.drop], game: row[col.game], prompt: row[col.prompt],
        next_eligible: ne ? iso_(ne) : null
      });
      picked++;
    }
  });
  if (limit > 0) rows = rows.slice(0, limit);
  return { ok: true, now: iso_(now), kinds: kinds, rows: rows };
}

// ---------------------------------------------------------------- helpers

function kindState_(kind, q, log, now) {
  var tz = ss_().getSpreadsheetTimeZone();
  var today = Utilities.formatDate(now, tz, 'yyyy-MM-dd');
  var used = 0, lastQuota = null, lastEnd = null;
  log.forEach(function (a) {
    if (a.kind !== kind || !a.ts) return;
    if (CONFIG.COUNTED_OUTCOMES.indexOf(a.outcome) >= 0 &&
        Utilities.formatDate(a.ts, tz, 'yyyy-MM-dd') === today) used++;
    if (a.outcome === 'quota' && (!lastQuota || a.ts > lastQuota)) lastQuota = a.ts;
    if (a.outcome !== 'blocked' && a.ended && (!lastEnd || a.ended > lastEnd)) lastEnd = a.ended;
  });
  var nextT = 0;
  if (lastQuota) nextT = Math.max(nextT, lastQuota.getTime() + q.cooldown * 60 * 1000);
  if (lastEnd) nextT = Math.max(nextT, lastEnd.getTime() + q.minGap * 1000);
  var remaining = Math.max(0, q.dailyCap - used);
  return {
    daily_cap: q.dailyCap, used_today: used, remaining_today: remaining,
    min_gap_s: q.minGap, cooldown_min: q.cooldown, max_retries: q.maxRetries,
    retry_backoff_s: q.backoff,
    last_quota_hit: lastQuota ? iso_(lastQuota) : null,
    last_attempt_end: lastEnd ? iso_(lastEnd) : null,
    kind_next_eligible: nextT ? iso_(new Date(nextT)) : null,
    ready: remaining > 0 && nextT <= now.getTime()
  };
}

function readAttempts_() {
  var sh = sheet_(CONFIG.ATTEMPTS_TAB);
  var last = sh.getLastRow();
  if (last < 2) return [];
  var h = CONFIG.ATTEMPTS_HEADERS;
  var iTs = h.indexOf('Timestamp'), iId = h.indexOf('Asset ID'), iKind = h.indexOf('Kind'),
      iEnd = h.indexOf('Ended'), iOut = h.indexOf('Outcome');
  return sh.getRange(2, 1, last - 1, h.length).getValues().map(function (r) {
    return { ts: asDate_(r[iTs]), id: r[iId], kind: r[iKind], ended: asDate_(r[iEnd]),
             outcome: String(r[iOut] || '').toLowerCase() };
  });
}

function countFailures_(kind, id) {
  return countFailuresIn_(readAttempts_(), kind, id);
}

function countFailuresIn_(log, kind, id) {
  return log.filter(function (a) {
    return a.kind === kind && a.id === id && CONFIG.RETRY_OUTCOMES.indexOf(a.outcome) >= 0;
  }).length;
}

function quotaFor_(kind) {
  var sh = sheet_(CONFIG.QUOTAS_TAB);
  var data = sh.getDataRange().getValues();
  var col = headerIndex_(data[0], CONFIG.QUOTA_COLS, CONFIG.QUOTAS_TAB);
  var d = CONFIG.QUOTA_DEFAULTS;
  for (var r = 1; r < data.length; r++) {
    if (String(data[r][col.kind]).trim() === kind) {
      var v = function (k) { var x = data[r][col[k]]; return (x === '' || x === null || isNaN(Number(x))) ? d[k] : Number(x); };
      return { dailyCap: v('dailyCap'), minGap: v('minGap'), cooldown: v('cooldown'),
               maxRetries: v('maxRetries'), backoff: v('backoff') };
    }
  }
  return { dailyCap: d.dailyCap, minGap: d.minGap, cooldown: d.cooldown,
           maxRetries: d.maxRetries, backoff: d.backoff };
}

/** Finds the asset row on its kind tab; if kind is missing, searches every kind tab. */
function findAsset_(kind, id) {
  if (!id) throw new Error('asset_id is required');
  var kinds = kind ? [kind] : Object.keys(CONFIG.KIND_TABS);
  for (var i = 0; i < kinds.length; i++) {
    var tab = CONFIG.KIND_TABS[kinds[i]];
    if (!tab) throw new Error('unknown kind: ' + kinds[i]);
    var sh = sheet_(tab);
    var data = sh.getDataRange().getValues();
    var col = headerIndex_(data[0], CONFIG.KIND_COLS, tab);
    for (var r = 1; r < data.length; r++) {
      if (String(data[r][col.id]).trim() === id) return rowCtx_(sh, r + 1, data[r], col, kinds[i]);
    }
  }
  throw new Error('asset not found: ' + id + (kind ? ' (kind ' + kind + ')' : ''));
}

function rowCtx_(sh, rowNum, values, col, kind) {
  var row = values.slice();
  return {
    kind: kind,
    get: function (k) { return row[col[k]]; },
    set: function (k, v) { row[col[k]] = v; },
    save: function () { sh.getRange(rowNum, 1, 1, row.length).setValues([row]); }
  };
}

function headerIndex_(headerRow, names, tab) {
  var idx = {};
  Object.keys(names).forEach(function (k) {
    var i = headerRow.indexOf(names[k]);
    if (i < 0) throw new Error('header "' + names[k] + '" not found on tab ' + tab);
    idx[k] = i;
  });
  return idx;
}

function ss_() {
  var id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (id) return SpreadsheetApp.openById(id);
  var active = SpreadsheetApp.getActiveSpreadsheet();   // bound script
  return active || SpreadsheetApp.openById(CONFIG.DEFAULT_SPREADSHEET_ID);
}

function sheet_(name) {
  var sh = ss_().getSheetByName(name);
  if (!sh) throw new Error('missing tab: ' + name);
  return sh;
}

function checkSecret_(given) {
  var props = PropertiesService.getScriptProperties();
  var want = props.getProperty('TRACKER_SECRET');
  // Keyboard-only setup: deploy.mjs writes tracker_secret.local.gs (gitignored) and clasp pushes
  // it. When present it is the secret, and it is stored as the TRACKER_SECRET Script Property
  // (so a new secret pushed later replaces the old one).
  if (typeof TRACKER_SECRET_LOCAL !== 'undefined' && String(TRACKER_SECRET_LOCAL).length >= 32) {
    if (want !== String(TRACKER_SECRET_LOCAL)) {
      want = String(TRACKER_SECRET_LOCAL);
      props.setProperty('TRACKER_SECRET', want);
    }
  }
  // Otherwise the first call after deployment adopts the caller's secret (at least 32 chars) so
  // no secret is ever written into the script source. Later calls must match it.
  if (!want && typeof given === 'string' && given.length >= 32) {
    var lock = LockService.getScriptLock();
    lock.waitLock(10000);
    try {
      want = props.getProperty('TRACKER_SECRET');
      if (!want) { props.setProperty('TRACKER_SECRET', given); want = given; }
    } finally { lock.releaseLock(); }
  }
  return !!want && typeof given === 'string' && given === want;
}

function asDate_(v) {
  if (v instanceof Date) return v;
  if (v === '' || v === null || v === undefined) return null;
  var d = new Date(v);
  return isNaN(d.getTime()) ? null : d;
}

function toNum_(v) { var n = Number(v); return isNaN(n) ? 0 : n; }

function iso_(d) { return d.toISOString(); }

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
