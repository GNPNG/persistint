// Media bytes: format sniffing, saving to a drop path, optional ffmpeg conversion, and
// WSL <-> Windows path mapping for downloads written by a Windows-side Chrome.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

/** Guess a file extension from magic bytes. Returns e.g. '.png', '.mp4', '.mp3', or null. */
export function sniffExt(buf) {
  if (!buf || buf.length < 4) return null;
  const b = (i) => buf[i];
  const ascii = (s, e) => Buffer.from(buf.subarray(s, e)).toString('latin1');
  if (b(0) === 0x89 && ascii(1, 4) === 'PNG') return '.png';
  if (b(0) === 0xff && b(1) === 0xd8 && b(2) === 0xff) return '.jpg';
  if (ascii(0, 4) === 'RIFF' && buf.length >= 12) {
    const t = ascii(8, 12);
    if (t === 'WEBP') return '.webp';
    if (t === 'WAVE') return '.wav';
  }
  if (ascii(0, 4) === 'GIF8') return '.gif';
  if (buf.length >= 12 && ascii(4, 8) === 'ftyp') {
    const brand = ascii(8, 12);
    if (/^(avif|avis)/.test(brand)) return '.avif';
    if (/^(heic|heix|heim|heis|hevc|hevx|mif1|msf1)/.test(brand)) return '.heic';
    return /^M4A|^M4B/.test(brand) ? '.m4a' : '.mp4';
  }
  if (b(0) === 0x1a && b(1) === 0x45 && b(2) === 0xdf && b(3) === 0xa3) return '.webm';
  if (ascii(0, 4) === 'OggS') return '.ogg';
  if (ascii(0, 4) === 'fLaC') return '.flac';
  if (ascii(0, 3) === 'ID3') return '.mp3';
  if (b(0) === 0xff && (b(1) & 0xe0) === 0xe0 && (b(1) & 0x06) !== 0) return '.mp3'; // MPEG audio frame sync, layer bits set
  return null;
}

/** Map an extension or MIME type to a canonical extension. */
export function extFromMime(mime) {
  const m = (mime || '').split(';')[0].trim().toLowerCase();
  return ({ 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp', 'video/mp4': '.mp4',
    'audio/mpeg': '.mp3', 'audio/mp3': '.mp3', 'audio/mp4': '.m4a', 'audio/wav': '.wav',
    'video/webm': '.webm', 'audio/ogg': '.ogg', 'image/avif': '.avif', 'image/heic': '.heic' })[m] ?? null;
}

/** True for a MIME type that can never be a rendered asset (an HTML sign-in/error page, JSON, text). */
export function isNonMediaMime(mime) {
  const m = (mime || '').split(';')[0].trim().toLowerCase();
  return /^text\//.test(m) || /(^|[/+])(json|xml|html|javascript)$/.test(m);
}

export function hasFfmpeg() {
  const r = spawnSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  return r.status === 0;
}

/**
 * Write `buf` to `dropAbs`. If its real format differs from the drop extension, convert with
 * ffmpeg when available; otherwise save it beside the drop with its real extension and report
 * that, so a wrong-format file never sits at the drop path. Bytes whose format cannot be
 * identified (an HTML sign-in or error page, JSON, text) are saved as <drop>.unknown for
 * inspection and the call throws, so the asset stays MISSING.
 */
export function saveToDrop(buf, dropAbs, { log = console.log, mime = null } = {}) {
  const want = path.extname(dropAbs).toLowerCase();
  const got = sniffExt(buf);
  fs.mkdirSync(path.dirname(dropAbs), { recursive: true });
  if (!got || isNonMediaMime(mime)) {
    const unknown = `${dropAbs}.unknown`;
    fs.writeFileSync(unknown, buf);
    const head = Buffer.from(buf.subarray(0, 80)).toString('latin1').replace(/[^\x20-\x7e]+/g, ' ').trim();
    throw new Error(`captured bytes are not a recognised media file (${buf.length} bytes${mime ? `, ${mime}` : ''}, starts "${head}"); saved as ${unknown}, the asset stays missing`);
  }
  if (got === want || (got === '.jpg' && want === '.jpeg')) {
    fs.writeFileSync(dropAbs, buf);
    return { path: dropAbs, format: got, converted: false };
  }
  const tmp = `${dropAbs}.src${got}`;
  fs.writeFileSync(tmp, buf);
  return convertFile(tmp, dropAbs, got, { log, keepAs: dropAbs.slice(0, -want.length || undefined) + got });
}

/**
 * Convert `src` (format `got`) to `dropAbs` with ffmpeg. On success `src` is removed. Without
 * ffmpeg, or if it fails, `src` is moved to `keepAs` (default: left where it is) and this throws.
 */
export function convertFile(src, dropAbs, got, { log = console.log, keepAs = src } = {}) {
  const want = path.extname(dropAbs).toLowerCase();
  if (hasFfmpeg()) {
    const args = ['-y', '-loglevel', 'error', '-i', src];
    if (want === '.mp3') args.push('-vn', '-c:a', 'libmp3lame', '-q:a', '2');
    args.push(dropAbs);
    const r = spawnSync('ffmpeg', args, { encoding: 'utf8' });
    if (r.status === 0) {
      fs.unlinkSync(src);
      log(`  converted ${got} -> ${want} with ffmpeg`);
      return { path: dropAbs, format: want, converted: true };
    }
    fs.rmSync(dropAbs, { force: true });
    log(`  ffmpeg failed: ${(r.stderr || '').trim()}`);
  }
  if (keepAs !== src) fs.renameSync(src, keepAs);
  throw new Error(`got ${got} but the drop wants ${want}; saved as ${keepAs} (install ffmpeg, then run --convert)`);
}

/** Media extensions a captured file may have when it is kept beside its drop for conversion. */
export const BESIDE_EXTS = ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.avif', '.heic', '.mp4', '.m4a',
  '.mp3', '.wav', '.webm', '.ogg', '.flac'];

// ---- WSL <-> Windows paths (for a Chrome running on Windows, attached over CDP) ----

/** /mnt/c/Users/x -> C:\Users\x ; returns null if not under /mnt/<drive>. */
export function wslToWindows(p) {
  const m = /^\/mnt\/([a-z])(\/.*)?$/i.exec(p);
  if (!m) return null;
  return `${m[1].toUpperCase()}:${(m[2] || '/').replace(/\//g, '\\')}`;
}

/** C:\Users\x -> /mnt/c/Users/x ; returns null if not a drive path. */
export function windowsToWsl(p) {
  const m = /^([a-z]):[\\/]?(.*)$/i.exec(p);
  if (!m) return null;
  return `/mnt/${m[1].toLowerCase()}/${m[2].replace(/\\/g, '/')}`.replace(/\/$/, '');
}
