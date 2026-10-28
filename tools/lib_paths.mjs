// Shared helpers for the Node ports of the asset tools (gen_sources, check_assets,
// set_texture_imports): walk folders in the order Python's sorted(Path.rglob("*")) gives, read
// text the way Path.read_text does (universal newlines), and escape regexes like re.escape; and
// for tools/land_wardrobe.mjs, find the art tools' Python and tell a Git LFS pointer from a file.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const PROJECT = path.join(ROOT, "project");

/** Path relative to `base`, with forward slashes (str(PurePosixPath)). */
export const rel = (p, base = ROOT) => path.relative(base, p).split(path.sep).join("/");

/** Python Path ordering: compare the lists of parts. */
export function cmpParts(a, b) {
  const pa = a.split("/"), pb = b.split("/");
  for (let i = 0; i < Math.min(pa.length, pb.length); i++) {
    if (pa[i] !== pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return pa.length - pb.length;
}

/** sorted(dir.rglob("*")): every file and folder under dir (absolute paths), Python's order. */
export function rglob(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      out.push(p);
      if (e.isDirectory()) walk(p);
    }
  };
  walk(dir);
  return out.sort((a, b) => cmpParts(rel(a, dir), rel(b, dir)));
}

export const isFile = (p) => { try { return fs.statSync(p).isFile(); } catch { return false; } };

/** Path.read_text(): UTF-8 (invalid bytes replaced), \r\n and \r read as \n. */
export const readText = (p) => fs.readFileSync(p).toString("utf8").replace(/\r\n?/g, "\n");

/** Write text, keeping the line ends the file already has (\r\n on a CRLF checkout). */
export function writeText(p, text) {
  const crlf = fs.existsSync(p) && fs.readFileSync(p).includes("\r\n");
  fs.writeFileSync(p, crlf ? text.replace(/\n/g, "\r\n") : text);
}

export const reEscape = (s) => s.replace(/[.*+?^${}()|[\]\\\-\/#&~ ]/g, "\\$&");

/** The art tools' Python, one with numpy, scipy and Pillow (tools/requirements-art.txt), looked for
 *  as project/tests/test_paperdoll_tools.gd looks (bd gd37): ART_PYTHON when it is set (only that
 *  one), else the art venv ~/.local/share/persistint/art-venv, else the repo's .venv, else python3
 *  on PATH; the first that imports them. Returns {python, tried}: python is null when none has
 *  them; tried names each one tried and why it would not do. */
export function artPython() {
  const art = process.env.ART_PYTHON;
  const home = process.env.HOME || process.env.USERPROFILE || "";
  const venvs = [...(home ? [path.join(home, ".local/share/persistint/art-venv")] : []), path.join(ROOT, ".venv")];
  const found = venvs.map((v) => ["bin/python3", "bin/python", "Scripts/python.exe"].map((r) => path.join(v, r)).find(isFile)).filter(Boolean);
  const tried = [];
  for (const py of art ? [art] : [...found, "python3"]) {
    const r = spawnSync(py, ["-I", "-c", "import numpy, scipy, PIL"], { stdio: "ignore" });
    if (r.status === 0) return { python: py, tried };
    tried.push(`${py} (${r.error ? "not found" : "no numpy, scipy or Pillow"})`);
  }
  return { python: null, tried };
}

/** A Git LFS pointer in place of the file (the PNGs are in LFS: `git lfs pull` fetches them). */
export function isLfsPointer(p) {
  try {
    const fd = fs.openSync(p, "r"), head = Buffer.alloc(40);
    const n = fs.readSync(fd, head, 0, 40, 0);
    fs.closeSync(fd);
    return head.subarray(0, n).toString("latin1").startsWith("version https://git-lfs");
  } catch { return false; }
}
