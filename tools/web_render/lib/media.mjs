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

/** Pixel size of a PNG, JPEG, WebP or GIF from its header, or null. */
export function imageSize(buf) {
  const ext = sniffExt(buf);
  if (ext === '.png' && buf.length >= 24) return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20), ext };
  if (ext === '.gif' && buf.length >= 10) return { w: buf.readUInt16LE(6), h: buf.readUInt16LE(8), ext };
  if (ext === '.jpg') {
    let i = 2;
    while (i + 9 < buf.length) {
      if (buf[i] !== 0xff) { i++; continue; }
      const m = buf[i + 1];
      if (m === 0xd8 || m === 0x01 || (m >= 0xd0 && m <= 0xd7) || m === 0xff) { i += m === 0xff ? 1 : 2; continue; }
      if (m >= 0xc0 && m <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(m)) return { w: buf.readUInt16BE(i + 7), h: buf.readUInt16BE(i + 5), ext };
      i += 2 + buf.readUInt16BE(i + 2);
    }
    return null;
  }
  if (ext === '.webp' && buf.length >= 30) {
    const chunk = buf.toString('latin1', 12, 16);
    if (chunk === 'VP8X') return { w: 1 + buf.readUIntLE(24, 3), h: 1 + buf.readUIntLE(27, 3), ext };
    if (chunk === 'VP8L') { const b = buf.readUInt32LE(21); return { w: (b & 0x3fff) + 1, h: ((b >> 14) & 0x3fff) + 1, ext }; }
    if (chunk === 'VP8 ') return { w: buf.readUInt16LE(26) & 0x3fff, h: buf.readUInt16LE(28) & 0x3fff, ext };
  }
  return null;
}

/**
 * Check that captured bytes are a real, full-size image for an asset of ratio `aspect` ("16:9").
 * Returns a list of problems (empty = fine). The on-page preview or an icon fails minSide.
 */
export function checkImage(buf, aspect, { minBytes = 20_000, minSide = 512, tolerance = 0.12 } = {}) {
  const size = imageSize(buf);
  if (!size) return [`not a PNG/JPEG/WebP/GIF image (${buf.length} bytes)`];
  const errs = [];
  if (buf.length < minBytes) errs.push(`only ${buf.length} bytes`);
  if (Math.min(size.w, size.h) < minSide) errs.push(`${size.w}x${size.h} is smaller than ${minSide} px on its short side (a preview?)`);
  const m = /^(\d+(?:\.\d+)?)\s*[:x]\s*(\d+(?:\.\d+)?)$/.exec(String(aspect || ''));
  if (m) {
    const want = Number(m[1]) / Number(m[2]);
    const got = size.w / size.h;
    if (Math.abs(got - want) / want > tolerance) errs.push(`${size.w}x${size.h} is not ${aspect}`);
  }
  return errs;
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
