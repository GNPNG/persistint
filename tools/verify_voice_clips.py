"""Check generated voice clips: does each clip say its line, in its speaker's voice?

Usage:
  python3 -I tools/verify_voice_clips.py [--speaker NAME] [--key KEY] [--json OUT]

For every line in project/audio/voice/manifest.json whose clip exists:
  - text: the clip is transcribed on CPU (faster-whisper, small.en) and compared word by word
    with the intended text (difflib ratio over normalized words); below 0.8 is flagged.
  - voice: for speakers with a reference recording in project/data/voices.json, the cosine
    similarity of the clip's and the reference's speaker embeddings (Resemblyzer) is reported;
    below 0.75 is flagged. Speakers with a built-in studio voice have no reference ("-").
Flagged clips can be regenerated with tools/generate_voice_clips.py --key KEY --force.
Requires: pip install faster-whisper resemblyzer librosa
"""
import argparse
import difflib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "project/audio/voice/manifest.json"
CAST = ROOT / "project/data/cast.json"
VOICES = ROOT / "project/data/voices.json"
OUT = ROOT / "project/audio/voice"
TEXT_MIN = 0.8
VOICE_MIN = 0.75

NUMBERS = {"10": "ten", "2": "two", "4": "four", "16th": "sixteenth"}


def words(s):
    s = s.lower().replace("’", "'").replace("-", " ").replace("—", " ")
    return [NUMBERS.get(w, w) for w in re.findall(r"[a-z0-9']+", s)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", action="append", help="only this speaker (repeatable)")
    ap.add_argument("--key", action="append", help="only this clip key (repeatable)")
    ap.add_argument("--json", help="also write the results here")
    args = ap.parse_args()

    lines = json.loads(MANIFEST.read_text())
    cast = json.loads(CAST.read_text())
    voices = json.loads(VOICES.read_text())
    by_name = {v["name"]: voices.get(cid) for cid, v in cast.items() if isinstance(v, dict) and "name" in v}

    def ref_for(speaker):
        v = by_name.get(speaker) or voices.get(speaker) or {}
        ref = ROOT / v["ref"] if "ref" in v else None
        return ref if ref and ref.exists() else None

    todo = [l for l in lines if (OUT / f"{l['key']}.wav").exists()
            and (not args.speaker or l["speaker"] in args.speaker)
            and (not args.key or l["key"] in args.key)]
    if not todo:
        print("no clips to check")
        return

    import librosa
    import numpy as np
    from faster_whisper import WhisperModel
    from resemblyzer import VoiceEncoder, preprocess_wav

    asr = WhisperModel("small.en", device="cpu", compute_type="int8")
    enc = VoiceEncoder("cpu", verbose=False)
    ref_emb = {}
    results = []
    for l in todo:
        clip = OUT / f"{l['key']}.wav"
        audio = librosa.load(clip, sr=16000)[0]
        heard = " ".join(s.text for s in asr.transcribe(audio, language="en")[0]).strip()
        text_sim = difflib.SequenceMatcher(None, words(l["text"]), words(heard)).ratio()
        voice_sim = None
        ref = ref_for(l["speaker"])
        if ref:
            if ref not in ref_emb:
                ref_emb[ref] = enc.embed_utterance(preprocess_wav(ref))
            e = enc.embed_utterance(preprocess_wav(audio, source_sr=16000))
            voice_sim = float(np.dot(e, ref_emb[ref]) / (np.linalg.norm(e) * np.linalg.norm(ref_emb[ref])))
        flag = text_sim < TEXT_MIN or (voice_sim is not None and voice_sim < VOICE_MIN)
        results.append({"key": l["key"], "speaker": l["speaker"], "text": l["text"], "heard": heard,
                        "text_sim": round(text_sim, 3), "voice_sim": None if voice_sim is None else round(voice_sim, 3),
                        "flagged": flag})
        vs = "-" if voice_sim is None else f"{voice_sim:.2f}"
        print(f"{'FLAG' if flag else 'ok  '} {text_sim:.2f} {vs:>5} {l['speaker'][:16]:16} {l['key'][:8]} {l['text'][:50]!r} heard {heard[:50]!r}", flush=True)

    print("\nspeaker            clips  flagged  min_text  mean_text  min_voice  mean_voice")
    for sp in sorted({r["speaker"] for r in results}):
        rs = [r for r in results if r["speaker"] == sp]
        ts = [r["text_sim"] for r in rs]
        vs = [r["voice_sim"] for r in rs if r["voice_sim"] is not None]
        fv = lambda f: f"{f(vs):.2f}" if vs else "-"
        print(f"{sp[:18]:18} {len(rs):5}  {sum(r['flagged'] for r in rs):7}  {min(ts):8.2f}  {sum(ts)/len(ts):9.2f}  "
              f"{fv(min):>9}  {fv(lambda v: sum(v)/len(v)):>10}")
    print(f"total {len(results)} clips, {sum(r['flagged'] for r in results)} flagged")
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
