#!/usr/bin/env python3
"""Loudness measurement and normalization shared by the audio tools (ffmpeg's ebur128).

Targets (sops/10-audio-levels.md): music game copies -18 LUFS integrated, true peak -1.5 dBTP;
voice clips and spoken vocalizations -16 LUFS, -1 dBTP; short cartoon effects by momentary
loudness (-12 LUFS momentary max), -1.5 dBTP. Buses sit at 0 dB; the settings screen scales them.
"""
import math
import re
import shutil
import subprocess
from pathlib import Path

MUSIC = {"I": -18.0, "TP": -1.5, "tol": 1.0}
VOICE = {"I": -16.0, "TP": -1.0, "tol": 1.0}
VOCALIZATION = {"I": -16.0, "TP": -1.5, "tol": 1.0}
EFFECT = {"mean": -14.0, "TP": -1.5, "tol": 1.5}  # too short for a loudness reading: mean level (dB)
VOCALIZATIONS = {"groan_1", "groan_2", "groan_3", "moan", "growl", "snore"}


def have_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def measure(path) -> dict:
    """Integrated (I), momentary max (M), loudness range (LRA) in LU and true peak (TP) in dBTP."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true",
                        "-f", "null", "-"], capture_output=True, text=True)
    text = r.stderr
    vals = re.findall(r"\bI:\s+(-?[\d.]+) LUFS", text)
    i = float(vals[-1]) if vals else None
    if i is not None and i <= -69.0:
        i = None  # gated out: the file is too short or too quiet for an integrated reading
    moments = [float(m) for m in re.findall(r"\bM:\s*(-?[\d.]+)", text)]
    moments = [m for m in moments if m > -100.0]
    lra = re.findall(r"LRA:\s+([\d.]+) LU", text)
    tp = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", text)
    v = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "volumedetect",
                        "-f", "null", "-"], capture_output=True, text=True).stderr
    mean = re.findall(r"mean_volume:\s+(-?[\d.]+) dB", v)
    return {"I": i, "M": max(moments) if moments else None, "LRA": float(lra[-1]) if lra else None,
            "TP": float(tp[-1]) if tp else None, "mean": float(mean[-1]) if mean else None}


def target_for(path) -> dict:
    p = str(path).replace("\\", "/")
    if "/audio/music/" in p:
        return MUSIC
    if "/audio/voice/" in p:
        return VOICE
    if "/audio/sfx/" in p:
        return VOCALIZATION if Path(p).stem in VOCALIZATIONS else EFFECT
    return VOICE


def level_of(m: dict, target: dict):
    """The reading the target is about: integrated loudness, or the mean level for short effects."""
    if "mean" in target:
        return m.get("mean")
    return m.get("M") if "M" in target else m.get("I")


def wanted(target: dict) -> float:
    return target.get("mean", target.get("M", target.get("I")))


def gain_db(m: dict, target: dict) -> float:
    lvl = level_of(m, target)
    if lvl is None:
        return 0.0
    return wanted(target) - lvl


def in_range(m: dict, target: dict) -> bool:
    lvl = level_of(m, target)
    want = wanted(target)
    if lvl is None:
        return False
    if abs(lvl - want) > target["tol"]:
        return False
    return m["TP"] is None or m["TP"] <= target["TP"] + 0.2


def normalize(src, dst, target: dict, out_args=()) -> dict:
    """Writes `dst` from `src` at the target: a static gain (the dynamics are kept) and a true-peak
    limiter at the ceiling as a safety, repeated up to three times when the limiter's work moves
    the level off target. Returns the measurement of the source."""
    first = measure(src)
    m = first
    cur = src
    limit = 10 ** ((target["TP"] - 0.4) / 20.0)
    for _ in range(3):
        g = gain_db(m, target)
        af = f"volume={g:.3f}dB,alimiter=limit={limit:.4f}:attack=2:release=60:level=false"
        tmp = Path(str(dst) + ".tmp" + Path(dst).suffix)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(cur), "-af", af, *out_args, str(tmp)],
                       check=True)
        Path(tmp).replace(dst)
        m = measure(dst)
        cur = dst
        if in_range(m, target):
            break
    return first


def db(x: float) -> float:
    return 20 * math.log10(max(x, 1e-9))
