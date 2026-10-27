#!/usr/bin/env python3
"""Render site/public/updates.html from CHANGELOG.md (what's new) and docs/ROADMAP.md (what's next).

Both files are plain Markdown with `## ` headings and `- ` bullets; paragraphs between them are
kept. Run after every version bump or roadmap edit, then commit the page:

    python3 tools/gen_updates_page.py
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / "VERSION").read_text().strip()
# The host is a per-game value: it lives only in site/site.config.json (PW-02).
SITE_HOST = json.loads((ROOT / "site" / "site.config.json").read_text(encoding="utf-8"))["site_host"]


def md_to_html(text: str) -> str:
    out, para, items = [], [], []

    def flush():
        nonlocal para, items
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>")
            para = []
        items = [i for i in items if i.strip()]
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items = []

    for line in text.splitlines():
        if line.startswith("# "):
            continue
        if line.startswith("## "):
            flush()
            out.append(f"<h2>{inline(line[3:].strip())}</h2>")
        elif line.startswith("### "):
            flush()
            out.append(f"<h3>{inline(line[4:].strip())}</h3>")
        elif line.startswith("- ") or line.rstrip() == "-":
            if para:
                flush()
            items.append(line[1:].strip())
        elif line.startswith("  ") and items:
            items[-1] += " " + line.strip()
        elif line.strip() == "":
            flush()
        else:
            if items:
                flush()
            para.append(line.strip())
    flush()
    return "\n".join(out)


## The released versions only: CHANGELOG.md from its first "## v" heading on (its preamble and the
## Unreleased section are for the repository, not the players).
def released(text: str) -> str:
    i = text.find("\n## v")
    return text[i + 1:] if i >= 0 else text


def inline(s: str) -> str:
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    return s


def main() -> None:
    changelog = md_to_html(released((ROOT / "CHANGELOG.md").read_text(encoding="utf-8")))
    roadmap = md_to_html((ROOT / "docs" / "ROADMAP.md").read_text(encoding="utf-8"))
    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Updates: PERSISTINT</title>
<meta name="description" content="What's new in the current version of PERSISTINT and what's coming next.">
<meta name="theme-color" content="#fdf6e3">
<meta name="color-scheme" content="light">
<link rel="canonical" href="https://{SITE_HOST}/updates">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/manifest.webmanifest">
<link rel="preload" href="/fonts/fredoka.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/css/site.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="topbar">
  <a class="brand" href="/" aria-label="PERSISTINT home">
    <img src="/icon.svg" alt="" width="28" height="28">
    <span>PERSISTINT</span>
  </a>
  <nav aria-label="Site">
    <ul>
      <li class="nav-sec"><a href="/#trailer">Trailer</a></li>
      <li class="nav-sec"><a href="/#worlds">Worlds</a></li>
      <li class="nav-sec"><a href="/#name-it">Name It</a></li>
      <li class="nav-sec"><a href="/#cruise">Cruise</a></li>
      <li><a href="/updates.html">Updates</a></li>
      <li><a href="/citations.html">Citations</a></li>
      <li><a href="/support.html">Support</a></li>
      <li><a class="nav-play" href="/play/">Play</a></li>
    </ul>
  </nav>
</header>
<main id="main" class="doc-page">
<div class="wrap narrow">
  <h1>Updates</h1>
  <p class="doc-lede">The game you can play right now is <strong>v{VERSION}</strong>. Here is what went into it,
    and what's coming next. Dates are estimates.</p>
  <ul class="toc" aria-label="On this page">
    <li><a href="#next">What's next</a></li>
    <li><a href="#new">What's new</a></li>
  </ul>
  <section id="next" aria-labelledby="next-h">
    <h2 id="next-h" class="doc-h">What's next</h2>
{roadmap}
  </section>
  <section id="new" aria-labelledby="new-h">
    <h2 id="new-h" class="doc-h">What's new</h2>
{changelog}
  </section>
</div>
</main>
<footer class="site-footer">
  <div class="wrap footer-grid">
    <div>
      <p class="footer-logo">PERSISTINT</p>
      <p>Written and designed by Brett Whitty as a companion to his novel <cite>Persistint</cite>, coming soon from
        <a href="https://gnpng.org">GNPNG</a>, an independent Canadian press.</p>
    </div>
    <div class="footer-links">
      <a class="gnpng" href="https://gnpng.org">gnpng.org</a>
      <a href="https://www.youtube.com/watch?v=8GxFjrDAJf4">Book trailer on YouTube</a>
      <a href="/play/">Play <span data-version>v{VERSION}</span></a>
      <a href="/updates.html">Updates &amp; what's next</a>
      <a href="/citations.html" data-modal="cite-modal">Citations &amp; further reading</a>
      <a class="safety-badge" href="/support.html"><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5z" fill="#5ad1d6" stroke="#ffffff" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 16.5s-4-2.4-4-5.1A2.2 2.2 0 0 1 12 10a2.2 2.2 0 0 1 4 1.4c0 2.7-4 5.1-4 5.1z" fill="#ffffff"/></svg>Online safety &amp; support</a>
    </div>
  </div>
  <div class="wrap legal">
    <p>&copy; 2026 Brett Whitty. All rights reserved. Based on characters and themes from the book &lsquo;Persistint&rsquo;. Made with the <a href="https://godotengine.org">Godot Engine</a>.
      Headings set in Fredoka (<a href="/fonts/OFL.txt">SIL Open Font License</a>).</p>
  </div>
</footer>
<script src="/js/ambience.js" defer></script>
</body>
</html>
"""
    (ROOT / "site" / "public" / "updates.html").write_text(page, encoding="utf-8")
    print("wrote site/public/updates.html")


if __name__ == "__main__":
    main()
