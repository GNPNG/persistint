// Shared helpers for the Node ports of the asset tools (gen_sources, check_assets,
// set_texture_imports): walk folders in the order Python's sorted(Path.rglob("*")) gives, read
// text the way Path.read_text does (universal newlines), and escape regexes like re.escape.
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
