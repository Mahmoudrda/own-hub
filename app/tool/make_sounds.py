#!/usr/bin/env python3
"""Synthesises Own Hub's sound cues from nothing.

Every file is built from sine waves and seeded noise, written with the
standard library only, so the output is the same on every run and nobody else
holds a right in it. No sample, library, recording or generator service is
involved. Run from the app folder:

    python3 tool/make_sounds.py            # writes assets/sounds/*.wav
    python3 tool/make_sounds.py --preview /path/to/own_hub_sounds.wav

One pentatonic family in C major (C D E G A), so any two cues layered together
agree. Warm mallet tones (a sine with a quiet second and fourth harmonic, a
5 ms attack and an exponential decay), a muted wooden tap (a short filtered
noise burst) and a slow air shimmer for the finish. Mono, 16-bit, 22.05 kHz.
"""

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050

NOTE = {
    "A3": 220.00,
    "C4": 261.63,
    "E4": 329.63,
    "G4": 392.00,
    "A4": 440.00,
    "C5": 523.25,
    "D5": 587.33,
    "E5": 659.25,
    "G5": 783.99,
    "C6": 1046.50,
    "E6": 1318.51,
}

# Peak level of each file, in dBFS. The ceiling stays well under -3 dBTP.
PEAK_DB = -12.0
TICK_PEAK_DB = -18.0


def _blank(seconds):
    return [0.0] * int(round(seconds * RATE))


def _mix(into, part, at):
    start = int(round(at * RATE))
    for i, v in enumerate(part):
        if start + i < len(into):
            into[start + i] += v


def mallet(freq, seconds, tau, gain=1.0):
    """A soft marimba or kalimba note: fundamental plus quiet 2nd and 4th."""
    n = int(round(seconds * RATE))
    attack = int(0.005 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / tau)
        if i < attack:
            env *= i / attack
        w = 2 * math.pi * freq * t
        out.append(
            gain
            * env
            * (math.sin(w) + 0.28 * math.sin(2 * w) + 0.08 * math.sin(4 * w))
        )
    return out


def wood(freq, seconds, seed, gain=1.0):
    """A muted wooden tap: a very short low-passed noise burst and a soft body."""
    rng = random.Random(seed)
    n = int(round(seconds * RATE))
    out = []
    low = 0.0
    for i in range(n):
        t = i / RATE
        low += 0.18 * ((rng.random() * 2 - 1) - low)
        env = math.exp(-t / (seconds / 5))
        if i < int(0.003 * RATE):
            env *= i / (0.003 * RATE)
        body = math.sin(2 * math.pi * freq * t) * math.exp(-t / (seconds / 3))
        out.append(gain * env * (0.9 * low + 0.5 * body))
    return out


def shimmer(seconds, seed, gain=1.0):
    """Air: noise high-passed and low-passed, swelling in and fading out."""
    rng = random.Random(seed)
    n = int(round(seconds * RATE))
    out = []
    lp = 0.0
    prev_lp = 0.0
    hp = 0.0
    for i in range(n):
        x = rng.random() * 2 - 1
        lp += 0.35 * (x - lp)
        hp = 0.92 * (hp + lp - prev_lp)
        prev_lp = lp
        swell = math.sin(math.pi * i / n) ** 2
        out.append(gain * swell * hp)
    return out


def finish(samples, peak_db):
    """Fades the last 20 ms, removes any offset and sets the peak level."""
    mean = sum(samples) / len(samples)
    samples = [s - mean for s in samples]
    fade = min(int(0.02 * RATE), len(samples))
    for i in range(fade):
        samples[len(samples) - 1 - i] *= i / fade
    peak = max(abs(s) for s in samples) or 1.0
    scale = (10 ** (peak_db / 20)) / peak
    return [s * scale for s in samples]


def write(path, samples):
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b"".join(
                struct.pack("<h", max(-32767, min(32767, int(round(s * 32767)))))
                for s in samples
            )
        )


def set_done(note):
    return finish(mallet(NOTE[note], 0.25, 0.07), PEAK_DB)


def rest_tick():
    return finish(wood(NOTE["G5"], 0.09, seed=11), TICK_PEAK_DB)


def rest_end():
    out = _blank(0.5)
    _mix(out, mallet(NOTE["E5"], 0.3, 0.09), 0.0)
    _mix(out, mallet(NOTE["G5"], 0.32, 0.1), 0.18)
    return finish(out, PEAK_DB)


def session_phrase(seconds):
    out = _blank(seconds)
    for i, note in enumerate(("C5", "E5", "G5")):
        _mix(out, mallet(NOTE[note], 0.7, 0.16, 0.9), 0.22 * i)
    _mix(out, mallet(NOTE["C6"], 1.1, 0.34), 0.66)
    _mix(out, shimmer(1.1, seed=23, gain=0.12), 0.6)
    return out


def session_done():
    return finish(session_phrase(1.7), PEAK_DB)


def personal_best():
    out = session_phrase(1.95)
    _mix(out, mallet(NOTE["E6"], 0.9, 0.22, 0.55), 1.0)
    return finish(out, PEAK_DB)


def week_closed():
    out = _blank(1.4)
    for note in ("C4", "E4", "G4"):
        part = mallet(NOTE[note], 1.4, 0.45)
        swell = int(0.18 * RATE)
        for i in range(min(swell, len(part))):
            part[i] *= (i / swell) ** 2
        _mix(out, part, 0.0)
    return finish(out, PEAK_DB)


def food_logged():
    out = _blank(0.36)
    _mix(out, wood(NOTE["A3"], 0.1, seed=31), 0.0)
    _mix(out, mallet(NOTE["D5"], 0.28, 0.07, 0.55), 0.07)
    return finish(out, PEAK_DB)


def undo():
    out = _blank(0.36)
    _mix(out, mallet(NOTE["D5"], 0.28, 0.07, 0.55), 0.0)
    _mix(out, wood(NOTE["A3"], 0.1, seed=31), 0.07)
    return finish(out, PEAK_DB)


def milestone():
    out = mallet(NOTE["E6"], 0.7, 0.18)
    return finish(out, PEAK_DB)


def verified():
    out = _blank(0.6)
    _mix(out, mallet(NOTE["G5"], 0.4, 0.1), 0.0)
    _mix(out, mallet(NOTE["C6"], 0.4, 0.11), 0.2)
    return finish(out, PEAK_DB)


def saved():
    return finish(mallet(NOTE["C6"], 0.15, 0.04), PEAK_DB)


CUES = {
    "set_done_1": lambda: set_done("G4"),
    "set_done_2": lambda: set_done("A4"),
    "set_done_3": lambda: set_done("C5"),
    "set_done_4": lambda: set_done("D5"),
    "set_done_5": lambda: set_done("E5"),
    "rest_tick": rest_tick,
    "rest_end": rest_end,
    "session_done": session_done,
    "personal_best": personal_best,
    "week_closed": week_closed,
    "food_logged": food_logged,
    "undo": undo,
    "milestone": milestone,
    "verified": verified,
    "saved": saved,
}


def main():
    here = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(here / "assets" / "sounds"))
    parser.add_argument("--preview", help="also write every cue, one after the other")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    total = 0
    preview = []
    for name, build in CUES.items():
        samples = build()
        write(out / f"{name}.wav", samples)
        total += 44 + 2 * len(samples)
        preview += samples + _blank(0.7)
    print(f"{len(CUES)} cues, {total / 1024:.0f} KB, written to {out}")
    if args.preview:
        write(Path(args.preview), preview)
        print(f"preview written to {args.preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
