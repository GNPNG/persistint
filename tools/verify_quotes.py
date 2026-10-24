"""Report the verification state of the celebrity quote databases (project/data/quotes/*.json).

Usage: python3 -I tools/verify_quotes.py [--list-unverified]
Reads only the json fields written by the verbatim V&V pass (verified, checked_url, primary_source,
was, note, excluded_from_game); no network. "usable" = verified and not excluded_from_game (only
those may be used in game). A file's optional "speech_habits" list (verbatim utterances transcribed from
recordings) is checked the same way, as its own row, and each entry also needs a "timestamp". Prints a per-file table and exits 1 if any quote lacks a verified flag or a
checked_url, or if a url is not https.
"""
import json
import sys
from pathlib import Path

QUOTES = Path(__file__).resolve().parent.parent / "project/data/quotes"


def main() -> int:
    list_unverified = "--list-unverified" in sys.argv[1:]
    rows, problems, unverified = [], [], []
    lists = []
    for path in sorted(QUOTES.glob("*.json")):
        data = json.loads(path.read_text())
        lists.append((path.name, data["quotes"]))
        if "speech_habits" in data:  # verbatim from recordings: each also needs a timestamp
            lists.append((f"{path.name}:speech_habits", data["speech_habits"]))
    for name, quotes in lists:
        path = Path(name)
        n = len(quotes)
        ok = sum(1 for q in quotes if q.get("verified") is True)
        corrected = sum(1 for q in quotes if "was" in q)
        primary = sum(1 for q in quotes if q.get("primary_source"))
        excluded = sum(1 for q in quotes if q.get("excluded_from_game") is True)
        usable = sum(1 for q in quotes if q.get("verified") is True and q.get("excluded_from_game") is not True)
        for i, q in enumerate(quotes):
            if not isinstance(q.get("verified"), bool):
                problems.append(f"{path.name}[{i}]: no verified flag")
            if not q.get("checked_url"):
                problems.append(f"{path.name}[{i}]: no checked_url")
            if name.endswith(":speech_habits") and not q.get("timestamp"):
                problems.append(f"{path.name}[{i}]: no timestamp")
            for key in ("url", "checked_url", "primary_source"):
                if q.get(key) and not str(q[key]).startswith("https://"):
                    problems.append(f"{path.name}[{i}]: {key} is not https")
            if q.get("verified") is not True:
                unverified.append(f"{path.name}[{i}]: {q['text']}")
        rows.append((path.name, n, ok, n - ok, corrected, primary, excluded, usable))

    head = ("file", "total", "verified", "unverified", "corrected", "other primary", "excluded", "usable")
    widths = [max(len(str(r[c])) for r in rows + [head]) for c in range(len(head))]
    line = lambda r: "  ".join(str(v).ljust(w) if c == 0 else str(v).rjust(w) for c, (v, w) in enumerate(zip(r, widths)))
    print(line(head))
    print("  ".join("-" * w for w in widths))
    for r in rows:
        print(line(r))
    totals = ("TOTAL",) + tuple(sum(r[c] for r in rows) for c in range(1, len(head)))
    print("  ".join("-" * w for w in widths))
    print(line(totals))
    if list_unverified:
        print("\nunverified:")
        for u in unverified:
            print("  " + u)
    for p in problems:
        print("PROBLEM " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
