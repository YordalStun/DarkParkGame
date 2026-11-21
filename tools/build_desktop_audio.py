#!/usr/bin/env python3
"""
Synthesises the sound effects for the in-game desktop computer into assets/audio/:
  bios.ogg      POST beep
  hdd.ogg       hard drive seeking
  chime.ogg     start-up chime
  click2.ogg    soft key/button click
  ding.ogg      dialog "ding"
  dialup.ogg    modem dial-up handshake (about 11 s)

All generated from scratch, so they are ours outright. Everything is kept quiet.
Usage: python3 tools/build_desktop_audio.py      (requires ffmpeg and numpy)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_audio as BA  # noqa: E402

SR = BA.SR
rng = np.random.default_rng(95)


def t_of(sec):
    return np.arange(int(SR * sec)) / SR


def tone(freq, sec, amp=1.0):
    t = t_of(sec)
    return amp * np.sin(2 * np.pi * freq * t)


def env_ad(n, a=0.005, d=8.0):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t * d)


def mono(x):
    return x[:, None].astype(np.float32)


def out(x, name, lufs):
    BA.encode(BA.normalise(BA.fade(mono(x), 0.002, 0.03), lufs), name)


def bios():
    t = t_of(0.18)
    x = np.sin(2 * np.pi * 1000 * t) * np.minimum(1, t / 0.004) * np.minimum(1, (0.18 - t) / 0.01)
    out(x, "bios.ogg", -24)


def hdd():
    n = int(SR * 1.8)
    x = np.zeros(n)
    t = 0.05
    while t < 1.7:
        i = int(t * SR)
        m = int(0.012 * SR)
        k = np.arange(m) / SR
        x[i:i + m] += rng.normal(0, 1, m) * np.exp(-k * 350) * rng.uniform(0.3, 1.0)
        x[i:i + m] += np.sin(2 * np.pi * rng.uniform(900, 1500) * k) * np.exp(-k * 250) * 0.5
        t += rng.uniform(0.02, 0.14)
    x += BA.fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 60, 400)[:, 0] * 0.03
    out(x, "hdd.ogg", -26)


def chime():
    # A rising Cmaj9 arpeggio with a soft pad underneath. Original composition.
    n = int(SR * 4.0)
    x = np.zeros(n)
    notes = [(261.6, 0.0), (329.6, 0.22), (392.0, 0.44), (523.3, 0.66), (659.3, 0.9), (783.99, 1.15), (1174.7, 1.45)]
    for f, start in notes:
        i = int(start * SR)
        m = n - i
        t = np.arange(m) / SR
        e = np.minimum(1, t / 0.01) * np.exp(-t * 1.5)
        x[i:] += (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)) * e * 0.4
    t = np.arange(n) / SR
    pad = sum(np.sin(2 * np.pi * f * t) for f in (130.8, 196.0, 261.6, 329.6)) * 0.12
    x += pad * np.minimum(1, t / 0.5) * np.exp(-t * 0.8)
    out(x, "chime.ogg", -22)


def click2():
    n = int(SR * 0.05)
    t = np.arange(n) / SR
    x = rng.normal(0, 1, n) * np.exp(-t * 600) * 0.5 + np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 400) * 0.6
    out(x, "click2.ogg", -24)


def ding():
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 880 * t) + 0.4 * np.sin(2 * np.pi * 1760 * t)) * np.exp(-t * 9)
    x[int(0.12 * SR):] += (np.sin(2 * np.pi * 660 * t[: n - int(0.12 * SR)])) * np.exp(-t[: n - int(0.12 * SR)] * 9) * 0.8
    out(x, "ding.ogg", -24)


def dialup():
    parts = []
    # DTMF for 5-5-5-0-1-4-3
    dt = {"5": (770, 1336), "0": (941, 1336), "1": (697, 1209), "4": (770, 1209), "3": (697, 1477)}
    for d in "5550143":
        f1, f2 = dt[d]
        parts.append((tone(f1, 0.09) + tone(f2, 0.09)) * 0.5)
        parts.append(np.zeros(int(SR * 0.07)))
    parts.append(np.zeros(int(SR * 0.6)))
    # ring-back / answer tone
    parts.append(tone(2100, 0.7, 0.6))
    parts.append(np.zeros(int(SR * 0.25)))
    # handshake: stepped tones with phase-modulated screech and band-limited noise
    n = int(SR * 6.0)
    t = np.arange(n) / SR
    base = np.zeros(n)
    seq = [980, 1180, 1650, 1850, 2225, 2100, 1300, 2400, 1200, 2600, 1750, 2000]
    seg = n // len(seq)
    for i, f in enumerate(seq):
        s, e = i * seg, (i + 1) * seg
        tt = t[s:e]
        base[s:e] = np.sin(2 * np.pi * f * tt + 3.0 * np.sin(2 * np.pi * (f / 40) * tt)) * (0.55 + 0.15 * np.sin(2 * np.pi * 7 * tt))
    noise = BA.fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 400, 3400)[:, 0]
    burst = np.clip(np.sin(2 * np.pi * 1.7 * t) * 3, 0, 1)
    hs = base * 0.7 + noise * 0.5 * burst + noise * 0.15
    hs *= np.minimum(1, t / 0.05) * np.minimum(1, (6.0 - t) / 0.4)
    parts.append(hs)
    # tail: carrier hiss that fades out
    tail = BA.fft_filter(rng.normal(0, 1, (int(SR * 1.2), 1)).astype(np.float32), 800, 3000)[:, 0] * 0.15
    tail *= np.linspace(1, 0, tail.size)
    parts.append(tail)
    x = np.concatenate(parts)
    x = BA.fft_filter(mono(x), 250, 3800)[:, 0]   # telephone band
    out(x, "dialup.ogg", -24)


if __name__ == "__main__":
    for fn in (bios, hdd, chime, click2, ding, dialup):
        fn()
        print("built", fn.__name__)
