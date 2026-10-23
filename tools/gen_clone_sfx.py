"""Synthesize the clone hall's cartoon sound effects: the polar bear cub's soft pounce
"boing", a squishy chomp/crunch, a wet splat, a cute burp and a little cub snore.

Usage: python3 -I tools/gen_clone_sfx.py
Writes project/audio/sfx/<name>.wav (22.05 kHz, 16-bit mono); data/ruins.json
("clone_children" -> "pounce" -> "sfx") picks which ones play.
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "project/audio/sfx"
RATE = 22050
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.01, release=0.2):
    e = np.ones(n)
    a, r = int(RATE * attack), int(RATE * release)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def lowpass(x, k=8):
    return np.convolve(x, np.ones(k) / k, mode="same")


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def boing():
    s = t(0.45)
    f = 180 + 260 * np.exp(-s * 9) * (1 + 0.4 * np.sin(2 * np.pi * 14 * s))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(s), 0.005, 0.3)


def chomp():
    parts = []
    for i in range(3):
        s = t(0.09)
        crunch = lowpass(rng.standard_normal(len(s)), 3 + i) * np.exp(-s * 40)
        squish = np.sin(2 * np.pi * (120 - 300 * s) * s) * np.exp(-s * 25)
        parts += [crunch * 0.7 + squish, np.zeros(int(RATE * 0.04))]
    return np.concatenate(parts)


def splat():
    s = t(0.35)
    noise = lowpass(rng.standard_normal(len(s)), 14) * np.exp(-s * 12)
    blub = np.sin(2 * np.pi * (90 + 200 * np.exp(-s * 20)) * s) * np.exp(-s * 9)
    return noise + 0.8 * blub


def burp():
    s = t(0.4)
    f = 95 + 25 * np.sin(2 * np.pi * 3 * s)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sign(np.sin(ph)) * 0.4 + np.sin(2 * ph) * 0.6
    return lowpass(tone * (1 + 0.3 * rng.standard_normal(len(s))), 10) * env(len(s), 0.03, 0.2)


def snore():
    out = []
    for _ in range(2):
        s = t(0.9)
        breath = lowpass(rng.standard_normal(len(s)), 30) * np.sin(np.pi * s / 0.9) ** 2
        purr = np.sin(2 * np.pi * 70 * s) * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * s)) * np.sin(np.pi * s / 0.9) ** 2
        whistle = np.sin(2 * np.pi * (900 + 300 * s) * s) * np.exp(-((s - 0.75) ** 2) / 0.004) * 0.15
        out += [breath * 0.6 + purr * 0.6 + whistle, np.zeros(int(RATE * 0.25))]
    return np.concatenate(out)


if __name__ == "__main__":
    for name, fn in (("boing", boing), ("chomp", chomp), ("splat", splat), ("burp", burp), ("snore", snore)):
        save(name, fn())
