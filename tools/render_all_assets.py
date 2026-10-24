#!/usr/bin/env python3
"""
Batch asset renderer and task queue for PERSISTINT prompts/.

Each prompt file (prompts/**/<id>.md) has front matter (id, tool, drop, game) and a
`## Prompt` section that is already self-contained (preamble + world line + subject +
negatives; see dev/STYLE.md). Rendered files go to the `drop:` path; then
tools/sync_rendered_assets.py copies them into project/.

Usage (from anywhere; paths resolve against the repo root):
  python3 tools/render_all_assets.py --status            # rendered vs missing, per asset
  python3 tools/render_all_assets.py --export-queue      # one copy-paste file of missing prompts
  python3 tools/render_all_assets.py --type image        # render missing images via the Gemini API
  python3 tools/render_all_assets.py --type video        # render missing videos
  python3 tools/render_all_assets.py --type music        # render missing music and stingers
  python3 tools/render_all_assets.py --type all --sync   # everything, then sync into project/
  ... --only key_art_bunker,title_screen                 # limit to some ids
  ... --force                                            # re-render even if the drop file exists

Needs GEMINI_API_KEY and `pip install google-genai` for rendering (not for --status / --export-queue).

Models (Gemini API, checked against ai.google.dev 2026-10-23): images `gemini-nano-banana-2.1`
(Imagen 4 is shut down), video `gemini-omni-1.1-flash` (Veo 3.1 Preview ids shut down
2026-10-22), music `lyria-3.5` (MP3 by default; length is steered in the prompt).
All three are called through client.interactions.create and return base64 inline data.
"""
import argparse
import base64
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.DOTALL)
PROMPT_RE = re.compile(r"^##\s+Prompt\s*\n+(.+?)(?=\n+##\s+|\Z)", re.DOTALL | re.MULTILINE)
NOTES_RE = re.compile(r"^##\s+Notes\s*\n+(.+?)(?=\n+##\s+|\Z)", re.DOTALL | re.MULTILINE)
RATIO_RE = re.compile(r"\b(1:1|16:9|9:16|4:3|3:4|3:2|2:3|5:4|4:5|21:9)\b")

KIND = {"Gemini image": "image", "Gemini Veo": "video", "Gemini Omni": "video", "Gemini Lyria": "music"}


def parse_prompt_file(md_path: Path) -> dict | None:
    text = md_path.read_text(encoding="utf-8").replace("\r\n", "\n")
    fm = FRONTMATTER_RE.search(text)
    pr = PROMPT_RE.search(text)
    if not fm or not pr:
        return None
    meta = {}
    for line in fm.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    if "drop" not in meta or "tool" not in meta:
        return None
    meta["prompt"] = " ".join(pr.group(1).strip().splitlines())
    notes = NOTES_RE.search(text)
    ratio = meta.get("aspect") or (RATIO_RE.search(notes.group(1)).group(1)
                                    if notes and RATIO_RE.search(notes.group(1)) else None)
    meta["aspect"] = ratio or "16:9"
    meta["kind"] = KIND.get(meta["tool"], "other")
    meta["md_path"] = str(md_path.relative_to(ROOT))
    drop = ROOT / meta["drop"]
    meta["drop_abs"] = drop
    meta["exists"] = drop.exists() and drop.stat().st_size > 0
    return meta


def discover_tasks(prompts_root: Path) -> list[dict]:
    tasks = []
    for md_path in sorted(prompts_root.rglob("*.md")):
        if md_path.name in ("STYLE.md", "README.md"):
            continue
        parsed = parse_prompt_file(md_path)
        if parsed:
            tasks.append(parsed)
        else:
            print(f"[skip] {md_path.relative_to(ROOT)}: no front matter drop/tool or no ## Prompt", file=sys.stderr)
    return tasks


def _save(task: dict, b64: str) -> None:
    out = task["drop_abs"]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(b64))
    print(f"  -> {task['drop']} ({out.stat().st_size} bytes)")


def render_image(client, task: dict, model: str) -> None:
    print(f"[image] {task['id']} ({task['aspect']}) ...")
    it = client.interactions.create(
        model=model,
        input=task["prompt"],
        response_format={"type": "image", "mime_type": "image/png",
                         "aspect_ratio": task["aspect"], "image_size": "2K"},
    )
    _save(task, it.output_image.data)


def render_video(client, task: dict, model: str) -> None:
    print(f"[video] {task['id']} ({task['aspect']}) ...")
    it = client.interactions.create(
        model=model,
        input=task["prompt"],
        response_format={"type": "video", "aspect_ratio": task["aspect"], "resolution": "720p"},
    )
    _save(task, it.output_video.data)


def render_music(client, task: dict, model: str) -> None:
    print(f"[music] {task['id']} ...")
    it = client.interactions.create(model=model, input=task["prompt"], response_format={"type": "audio"})
    if not it.output_audio:
        raise RuntimeError(f"no audio returned for {task['id']}")
    _save(task, it.output_audio.data)


def print_status(tasks: list[dict]) -> None:
    print(f"{'STATUS':<9} {'KIND':<6} {'ID':<38} DROP")
    print("-" * 110)
    for t in tasks:
        print(f"[{'DONE' if t['exists'] else 'MISSING':<7}] {t['kind']:<6} {t['id']:<38} {t['drop']}")
    done = sum(t["exists"] for t in tasks)
    print(f"\nProgress: {done}/{len(tasks)} assets rendered.")


def export_queue(tasks: list[dict], dest: Path) -> None:
    missing = [t for t in tasks if not t["exists"]]
    lines = ["# PERSISTINT render queue", "",
             f"{len(missing)} assets still to render. Paste each prompt into the named Gemini tool and save",
             "the result to its drop path, then run `python3 tools/sync_rendered_assets.py`.", ""]
    for i, t in enumerate(missing, 1):
        lines += [f"## {i}. {t['id']}  ({t['tool']}, {t['aspect'] if t['kind'] != 'music' else 'audio'})",
                  "", f"Save as: `{t['drop']}`", "", "```text", t["prompt"], "```", ""]
    dest.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {dest} ({len(missing)} prompts)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prompts-dir", default=str(ROOT / "prompts"))
    ap.add_argument("--status", action="store_true", help="show rendered vs missing")
    ap.add_argument("--export-queue", nargs="?", const=str(ROOT / "prompts" / "QUEUE.md"),
                    help="write missing prompts to one file (default prompts/QUEUE.md)")
    ap.add_argument("--type", choices=["image", "video", "music", "all"], help="render missing assets via the API")
    ap.add_argument("--only", help="comma-separated ids to limit to")
    ap.add_argument("--force", action="store_true", help="re-render existing drops")
    ap.add_argument("--image-model", default="gemini-nano-banana-2.1")
    ap.add_argument("--video-model", default="gemini-omni-1.1-flash")
    ap.add_argument("--music-model", default="lyria-3.5")
    ap.add_argument("--sync", action="store_true", help="run tools/sync_rendered_assets.py afterwards")
    args = ap.parse_args()

    tasks = discover_tasks(Path(args.prompts_dir))
    if args.only:
        wanted = {s.strip() for s in args.only.split(",")}
        tasks = [t for t in tasks if t["id"] in wanted]

    if args.export_queue:
        export_queue(tasks, Path(args.export_queue).resolve())
    if args.status or not (args.type or args.export_queue):
        print_status(tasks)
    if not args.type:
        return

    if not os.environ.get("GEMINI_API_KEY"):
        sys.exit("GEMINI_API_KEY is not set")
    try:
        from google import genai
    except ImportError:
        sys.exit("google-genai is not installed: pip install google-genai")
    client = genai.Client()

    renderers = {"image": (render_image, args.image_model), "video": (render_video, args.video_model),
                 "music": (render_music, args.music_model)}
    failed = []
    for t in tasks:
        if (t["exists"] and not args.force) or t["kind"] not in renderers:
            continue
        if args.type != "all" and t["kind"] != args.type:
            continue
        fn, model = renderers[t["kind"]]
        try:
            fn(client, t, model)
        except Exception as e:  # keep going; report at the end
            print(f"  !! {t['id']}: {e}", file=sys.stderr)
            failed.append(t["id"])

    if args.sync:
        subprocess.run([sys.executable, str(ROOT / "tools" / "sync_rendered_assets.py")], check=True)
    if failed:
        sys.exit(f"{len(failed)} failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
