#!/usr/bin/env python3
"""Link check for the promo site (PW-13). Run with python3 -I.

Usage: python3 -I tools/check_site_links.py SITE_PUBLIC_DIR --host HOST
           [--allow PATH_GLOB ...] [--check-external]

Checks every href, src, srcset, poster and content="https://HOST/..." in the HTML
files under SITE_PUBLIC_DIR, url(...) in the CSS files, and same-page #fragments.
Internal URLs (relative, root-relative or https://HOST/...) must resolve to a file,
following the static-asset rules of Cloudflare Workers ("auto-trailing-slash":
/a/ -> a/index.html, /a -> a.html or a/index.html) and the sources in _redirects.
--allow globs (fnmatch on the URL path) mark paths served by the worker, such as
/play/*/index.wasm, as present. External http(s) links are listed and only fetched
with --check-external. Exit status 1 on any broken link.
"""
import argparse
import fnmatch
import html.parser
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

URL_ATTRS = {"href", "src", "poster", "data-src"}


class Collector(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.urls = []  # (url, line)
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        line = self.getpos()[0]
        a = dict(attrs)
        for k, v in attrs:
            if v is None:
                continue
            if k in ("id", "name") and (k == "id" or tag == "a"):
                self.ids.add(v)
            if k in URL_ATTRS:
                self.urls.append((v.strip(), line))
            elif k in ("srcset", "imagesrcset"):
                for part in v.split(","):
                    u = part.strip().split()
                    if u:
                        self.urls.append((u[0], line))
        # absolute social-card URLs (og:image, og:url, twitter:image)
        if tag == "meta" and (a.get("content") or "").startswith(("http://", "https://")):
            prop = a.get("property") or a.get("name") or ""
            if prop in ("og:image", "og:url", "twitter:image", "og:video", "og:audio"):
                self.urls.append((a["content"].strip(), line))


def redirect_sources(public):
    pats = []
    path = os.path.join(public, "_redirects")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as f:
            for raw in f:
                raw = raw.split("#", 1)[0].strip()
                if raw:
                    pats.append(raw.split()[0].replace(":splat", "*"))
    return pats


def resolve(public, path):
    """Return True if URL path `path` maps to a static file under `public`."""
    rel = urllib.parse.unquote(path).lstrip("/")
    full = os.path.normpath(os.path.join(public, rel))
    if not (full == public or full.startswith(public + os.sep)):
        return False
    if path.endswith("/"):
        return os.path.isfile(os.path.join(full, "index.html"))
    if os.path.isfile(full):
        return True
    return os.path.isfile(full + ".html") or os.path.isfile(os.path.join(full, "index.html"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("public")
    ap.add_argument("--host", required=True)
    ap.add_argument("--allow", action="append", default=[])
    ap.add_argument("--check-external", action="store_true")
    args = ap.parse_args()
    public = os.path.realpath(args.public)
    allow = args.allow + redirect_sources(public)

    errors, external, checked = [], {}, 0
    for root, _dirs, files in os.walk(public):
        for name in sorted(files):
            fpath = os.path.join(root, name)
            relfile = os.path.relpath(fpath, public)
            page_url = "/" + relfile.replace(os.sep, "/")
            if name.endswith(".html"):
                c = Collector()
                with open(fpath, encoding="utf-8") as f:
                    c.feed(f.read())
                urls, ids = c.urls, c.ids
            elif name.endswith(".css"):
                with open(fpath, encoding="utf-8") as f:
                    text = f.read()
                urls = [(m.group(2), text.count("\n", 0, m.start()) + 1)
                        for m in re.finditer(r"url\(\s*(['\"]?)([^'\")]+)\1\s*\)", text)]
                ids = set()
            else:
                continue
            for url, line in urls:
                where = f"{relfile}:{line}"
                if not url or url.startswith(("data:", "mailto:", "tel:", "javascript:", "blob:")):
                    continue
                parts = urllib.parse.urlsplit(url)
                if parts.scheme in ("http", "https") and parts.netloc != args.host:
                    external.setdefault(url, where)
                    continue
                if parts.scheme and parts.scheme not in ("http", "https"):
                    continue
                checked += 1
                if parts.scheme == "http":
                    errors.append(f"{where}: {url} (use https for the site host)")
                    continue
                if not parts.path and not parts.netloc:
                    # same-page fragment
                    if parts.fragment and parts.fragment not in ids:
                        errors.append(f"{where}: #{parts.fragment} (no element with that id)")
                    continue
                path = parts.path or "/"
                if not path.startswith("/"):
                    path = urllib.parse.urljoin(page_url, path)
                if any(fnmatch.fnmatchcase(path, pat) for pat in allow):
                    continue
                if not resolve(public, path):
                    errors.append(f"{where}: {url} (no file for {path})")

    if args.check_external:
        for url, where in sorted(external.items()):
            req = urllib.request.Request(url, method="GET",
                                         headers={"User-Agent": "Mozilla/5.0 (link check)"})
            try:
                with urllib.request.urlopen(req, timeout=20) as r:
                    code = r.status
            except urllib.error.HTTPError as e:
                code = e.code
            except Exception as e:  # network errors are failures too
                errors.append(f"{where}: {url} ({e.__class__.__name__}: {e})")
                continue
            if code >= 400 and code not in (401, 403, 429):
                errors.append(f"{where}: {url} (HTTP {code})")
            else:
                print(f"  ok {code} {url}")

    print(f"link check: {checked} internal links checked, {len(external)} external "
          f"{'checked' if args.check_external else 'skipped (use --check-external)'}")
    for e in errors:
        print(f"  BROKEN {e}", file=sys.stderr)
    if errors:
        print(f"link check FAILED: {len(errors)} broken", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
