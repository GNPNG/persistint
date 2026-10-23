// Prompt discovery and parsing. A line-for-line port of parse_prompt_file / discover_tasks in
// tools/render_all_assets.py, so both tools agree on ids, kinds, aspects and drop paths.
// No third-party imports: --status, --dry-run and the unit tests work before `npm install`.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const WEB_RENDER_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const ROOT = path.resolve(WEB_RENDER_DIR, '..', '..');

const FRONTMATTER_RE = /^---\s*\n([\s\S]*?)\n---\s*\n/; // Python: \A---\s*\n(.*?)\n---\s*\n, DOTALL
const END = '$(?![\\s\\S])'; // Python \Z (end of string even in multiline mode)
const PROMPT_RE = new RegExp(`^##\\s+Prompt\\s*\\n+([\\s\\S]+?)(?=\\n+##\\s+|${END})`, 'm');
const NOTES_RE = new RegExp(`^##\\s+Notes\\s*\\n+([\\s\\S]+?)(?=\\n+##\\s+|${END})`, 'm');
export const RATIO_RE = /\b(1:1|16:9|9:16|4:3|3:4|3:2|2:3|5:4|4:5|21:9)\b/;
// Python str.splitlines() boundaries
const SPLITLINES_RE = /\r\n|[\n\r\v\f\x1c\x1d\x1e\x85\u2028\u2029]/;
// Python str.strip() with no argument strips whitespace; JS trim() covers the same set for our files.

export const KIND = { 'Gemini image': 'image', 'Gemini Veo': 'video', 'Gemini Omni': 'video', 'Gemini Lyria': 'music' };
export const KIND_EXT = { image: '.png', video: '.mp4', music: '.mp3' };

function splitlines(s) {
  const parts = s.split(SPLITLINES_RE);
  if (parts.length && parts[parts.length - 1] === '') parts.pop();
  return parts;
}

export function parsePromptText(text, mdPath, root = ROOT) {
  text = text.replace(/\r\n/g, '\n');
  const fm = FRONTMATTER_RE.exec(text);
  const pr = PROMPT_RE.exec(text);
  if (!fm || !pr) return null;
  const meta = {};
  for (const line of splitlines(fm[1])) {
    const i = line.indexOf(':');
    if (i >= 0) meta[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  if (!('drop' in meta) || !('tool' in meta)) return null;
  meta.prompt = splitlines(pr[1].trim()).join(' ');
  const notes = NOTES_RE.exec(text);
  const nm = notes ? RATIO_RE.exec(notes[1]) : null;
  meta.aspect = meta.aspect || (nm ? nm[1] : null) || '16:9';
  meta.kind = KIND[meta.tool] ?? 'other';
  meta.md_path = path.relative(root, mdPath).split(path.sep).join('/');
  meta.drop_abs = path.resolve(root, meta.drop);
  meta.exists = dropExists(meta.drop_abs);
  return meta;
}

export function dropExists(p) {
  try { return fs.statSync(p).size > 0; } catch { return false; }
}

export function parsePromptFile(mdPath, root = ROOT) {
  return parsePromptText(fs.readFileSync(mdPath, 'utf8'), mdPath, root);
}

function rglobMd(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...rglobMd(p));
    else if (e.isFile() && e.name.endsWith('.md')) out.push(p);
  }
  return out;
}

// Python sorts Path objects by their parts; comparing the '/'-joined strings code point by code
// point gives the same order except where a name sorts before '/', so compare part by part.
function comparePaths(a, b) {
  const pa = a.split(path.sep), pb = b.split(path.sep);
  for (let i = 0; i < Math.min(pa.length, pb.length); i++) {
    if (pa[i] !== pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return pa.length - pb.length;
}

export function discoverTasks(promptsRoot = path.join(ROOT, 'prompts'), { root = ROOT, warn = console.error } = {}) {
  const tasks = [];
  for (const md of rglobMd(promptsRoot).sort(comparePaths)) {
    const name = path.basename(md);
    if (name === 'STYLE.md' || name === 'README.md') continue;
    const t = parsePromptFile(md, root);
    if (t) tasks.push(t);
    else warn(`[skip] ${path.relative(root, md)}: no front matter drop/tool or no ## Prompt`);
  }
  return tasks;
}

/** Extension the drop path asks for, and whether it matches the kind's expected format. */
export function dropFormat(task) {
  const ext = path.extname(task.drop).toLowerCase();
  const expected = KIND_EXT[task.kind];
  return { ext, expected, ok: !!expected && ext === expected };
}

/** Filter tasks the way render.mjs does: kind, --only ids, skip existing unless forced. */
export function selectTasks(tasks, { kind = 'all', only = null, force = false } = {}) {
  const wanted = only ? new Set(only.split(',').map((s) => s.trim()).filter(Boolean)) : null;
  return tasks.filter((t) =>
    (!wanted || wanted.has(t.id)) &&
    (kind === 'all' ? t.kind in KIND_EXT : t.kind === kind) &&
    (force || !t.exists));
}

export function formatStatus(tasks) {
  const lines = [`${'STATUS'.padEnd(9)} ${'KIND'.padEnd(6)} ${'ID'.padEnd(38)} DROP`, '-'.repeat(110)];
  for (const t of tasks) {
    lines.push(`[${(t.exists ? 'DONE' : 'MISSING').padEnd(7)}] ${t.kind.padEnd(6)} ${t.id.padEnd(38)} ${t.drop}`);
  }
  const done = tasks.filter((t) => t.exists).length;
  lines.push('', `Progress: ${done}/${tasks.length} assets rendered.`);
  return lines.join('\n');
}
