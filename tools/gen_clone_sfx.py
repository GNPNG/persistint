"""Synthesize the clone hall's cartoon sound effects: the polar bear cub's soft pounce
"boing", a squishy chomp/crunch, a wet splat, a cute burp and a little cub snore, and the
zombie clones' vocalizations: three groans ("Uuunnngh"), a closed-mouth moan ("Mmmrrrh") and
a small growl ("Grrrr").

The vocalizations stand in for the sounds written in square brackets in a clone's bark
("[Uuunnngh.] Shamble.", data/ruins.json): Voice never reads a bracketed sound aloud, it plays
one of these instead (author 2026-10-24: text-to-speech "doesn't do a good job of the groaning
effects"). They are a cartoon voice built from scratch (a glottal pulse train with vibrato
through two vowel formants, breath noise, a trill for the r's), not a recording of anyone; the
Clones audio bus pitches them up like the clips so they come out as kid zombies.

Usage: python3 -I tools/gen_clone_sfx.py
Writes project/audio/sfx/<name>.wav (22.05 kHz, 16-bit mono); data/ruins.json
("clone_children" -> "pounce" -> "sfx") picks which pounce sounds play, Voice.sfx_for picks a
vocalization by its spelling (g... growl, m... moan, anything else a groan).
"""
import wave
from pathlib import Path

import numpy as np
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_levels  # noqa: E402

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
    """Writes the sound, then sets its level to the target for its kind (tools/audio_levels.py:
    vocalizations -16 LUFS like the voice clips, short effects -12 LUFS momentary) with ffmpeg."""
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.wav"
    _write(path, x)
    if audio_levels.have_ffmpeg():
        audio_levels.normalize(path, path, audio_levels.target_for(path), ("-codec:a", "pcm_s16le"))


def _write(path, x):
    with wave.open(str(path), "wb") as w:
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


def biquad_bandpass(x, f0, q):
    """x through a resonant band-pass (RBJ biquad) at f0 Hz with quality q."""
    w0 = 2 * np.pi * f0 / RATE
    alpha = np.sin(w0) / (2 * q)
    b = np.array([alpha, 0.0, -alpha])
    a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
    b, a = b / a[0], a / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        out = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, v, y1, out
        y[i] = out
    return y


def voice(seconds, f_start, f_end, formants, vibrato=5.5, depth=0.04, breath=0.12, trill=0.0, trill_from=1.0):
    """A cartoon throat: a glottal pulse train gliding from f_start to f_end Hz with vibrato,
    through the given (frequency, quality, gain) formants, plus breath noise; `trill` > 0 chops
    the tail (from `trill_from` of the way through) at that rate for a rolled r."""
    s = t(seconds)
    k = s / seconds
    f = f_start + (f_end - f_start) * k ** 0.8
    f = f * (1 + depth * np.sin(2 * np.pi * vibrato * s + 0.7 * np.sin(2 * np.pi * 0.9 * s)))
    ph = np.cumsum(f) / RATE
    frac = ph % 1.0
    pulse = np.exp(-frac * 9.0) * (1 - frac)          # one soft glottal pulse per period
    pulse -= pulse.mean()
    source = pulse + breath * lowpass(rng.standard_normal(len(s)), 4) * (0.6 + 0.4 * np.sin(2 * np.pi * f * s))
    out = np.zeros_like(s)
    for f0, q, g in formants:
        out += g * biquad_bandpass(source, f0, q)
    out += 0.25 * pulse
    if trill > 0:
        gate = np.where(k >= trill_from, 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * trill * s)), 1.0)
        out *= gate
    return out


def groan(kind):
    """Uuunnngh: a long "uh" sliding down into "n" and a closed "gh" at the end."""
    seconds, f0, f1, vib = {0: (1.05, 128, 92, 5.0), 1: (0.85, 142, 104, 6.0), 2: (1.25, 118, 84, 4.4)}[kind]
    s = t(seconds)
    k = s / seconds
    x = voice(seconds, f0, f1, ((520 - 200 * k.mean(), 6, 1.0), (1040, 8, 0.45), (2500, 10, 0.12)), vibrato=vib, depth=0.05, breath=0.14)
    # the mouth closes: the vowel dims into a nasal "nn" over the last third
    nasal = voice(seconds, f0, f1, ((280, 5, 1.0), (900, 9, 0.2)), vibrato=vib, depth=0.05, breath=0.05)
    mix = np.clip((k - 0.55) / 0.3, 0, 1)
    x = x * (1 - mix) + nasal * mix
    e = env(len(s), 0.14, 0.3) * (1 - 0.25 * np.sin(2 * np.pi * 1.3 * s))
    tail = int(RATE * 0.08)  # "gh": a short breathy stop
    gh = lowpass(rng.standard_normal(tail), 6) * np.linspace(1, 0, tail) ** 2 * 0.5
    return np.concatenate([x * e, gh])


def moan():
    """Mmmrrrh: a hum with the mouth shut, rolling into an r and a sigh."""
    seconds = 1.0
    s = t(seconds)
    x = voice(seconds, 150, 168, ((260, 4, 1.0), (750, 10, 0.12)), vibrato=4.6, depth=0.03, breath=0.05, trill=24.0, trill_from=0.55)
    x = lowpass(x, 3)
    sigh = lowpass(rng.standard_normal(int(RATE * 0.22)), 8) * np.linspace(1, 0, int(RATE * 0.22)) ** 1.5 * 0.35
    return np.concatenate([x * env(len(s), 0.12, 0.25), sigh])


def growl():
    """Grrrr: a small chest growl, fry and trill, more breath than voice."""
    seconds = 0.75
    s = t(seconds)
    x = voice(seconds, 96, 78, ((400, 4, 0.9), (1300, 6, 0.5), (3000, 8, 0.25)), vibrato=7.0, depth=0.03, breath=0.4, trill=27.0, trill_from=0.15)
    fry = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 31 * s + np.cumsum(rng.standard_normal(len(s))) * 0.002))
    x = x * fry * env(len(s), 0.04, 0.2)
    # a chest growl is dense, not spiky: a soft clip rounds the fry's peaks so the sound can sit
    # at the vocalization level without a limiter squashing it
    x = x / (np.max(np.abs(x)) + 1e-9)
    return np.tanh(x * 2.2) / np.tanh(2.2)


if __name__ == "__main__":
    for name, fn in (("boing", boing), ("chomp", chomp), ("splat", splat), ("burp", burp), ("snore", snore),
                     ("groan_1", lambda: groan(0)), ("groan_2", lambda: groan(1)), ("groan_3", lambda: groan(2)),
                     ("moan", moan), ("growl", growl)):
        save(name, fn())
