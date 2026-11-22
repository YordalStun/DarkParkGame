#!/usr/bin/env python3
"""
Synthesises the story sounds into assets/audio/ (all generated here, so they are ours outright):
  phone_ring.ogg    UK double ring from an electronic desk phone (loop: ring-ring, pause)
  engine_idle.ogg   petrol 4-cylinder idle (seamless loop; pitch it up for driving)
  window_slide.ogg  aluminium sliding window on a gritty runner
  handset.ogg       handset lifted / put down on the cradle
  barrier_button.ogg chunky push button + relay click
  car_door.ogg      car door shutting outside
  knock.ogg         knuckles on the glass

Usage: python3 tools/build_story_audio.py      (needs numpy and ffmpeg)
"""
import os
import subprocess

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def save(name, x, peak_db=-3.0):
    x = x / (np.max(np.abs(x)) + 1e-9) * (10 ** (peak_db / 20))
    pcm = np.clip(x, -1, 1).astype(np.float32)
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", path], input=pcm.tobytes(), check=True)
    print("wrote", path)


def phone_ring():
    # 400 + 450 Hz, 0.4 on / 0.2 off / 0.4 on / 2.0 off, through a tiny tinny speaker.
    total = 3.0
    x = np.zeros(int(total * SR))
    for start in (0.0, 0.6):
        tt = t(0.4)
        tone = np.sin(2 * np.pi * 400 * tt) + np.sin(2 * np.pi * 450 * tt)
        tone += 0.5 * np.sign(np.sin(2 * np.pi * 1200 * tt)) * 0.3   # buzzy piezo edge
        tone *= env(len(tt), 0.01, 0.02)
        i = int(start * SR)
        x[i:i + len(tt)] += tone
    x = highpass(lowpass(x, 3500), 300)
    save("phone_ring", x, -4.0)


def engine_idle():
    # 4-cyl idle ~ 800 rpm -> firing 26.7 Hz. Exactly 40 cycles so it loops seamlessly.
    f = 800 / 60 * 2
    dur = 40 / f
    tt = t(dur)
    x = np.zeros_like(tt)
    for h, a in [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.25), (6, 0.12), (8, 0.06)]:
        x += a * np.sin(2 * np.pi * f * h * tt + h)
    # Combustion roughness: noise bursts on each firing, cyclic so the loop holds.
    pulse = (np.sin(2 * np.pi * f * tt) > 0.6).astype(float)
    noise = rng.standard_normal(len(tt))
    x += 0.5 * lowpass(noise, 900) * pulse
    x += 0.15 * lowpass(noise, 300)
    x = lowpass(x, 1200)
    # cross-fade the ends to hide the noise seam
    n = int(0.03 * SR)
    x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    x = x[:-n]
    save("engine_idle", x, -4.0)


def window_slide():
    dur = 0.9
    tt = t(dur)
    noise = rng.standard_normal(len(tt))
    grit = lowpass(noise, 2500) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 17 * tt)))
    rumble = lowpass(noise, 180) * 2.0
    clunk = np.zeros_like(tt)
    k = t(0.08)
    hit = np.sin(2 * np.pi * 140 * k) * np.exp(-k * 50)
    clunk[-len(k):] += hit * 1.5
    x = (grit + rumble) * env(len(tt), 0.05, 0.12) + clunk
    save("window_slide", x, -5.0)


def handset():
    k = t(0.25)
    x = np.sin(2 * np.pi * 210 * k) * np.exp(-k * 35) + 0.5 * lowpass(rng.standard_normal(len(k)), 3000) * np.exp(-k * 60)
    save("handset", x, -6.0)


def barrier_button():
    k = t(0.35)
    x = lowpass(rng.standard_normal(len(k)), 4000) * np.exp(-k * 120)
    relay = np.zeros_like(k)
    j = t(0.05)
    i = int(0.12 * SR)
    relay[i:i + len(j)] = np.sin(2 * np.pi * 1800 * j) * np.exp(-j * 150)
    x += relay * 0.6
    save("barrier_button", x, -6.0)


def car_door():
    k = t(0.6)
    x = np.sin(2 * np.pi * 70 * k) * np.exp(-k * 18) + 0.6 * lowpass(rng.standard_normal(len(k)), 1200) * np.exp(-k * 25)
    x += 0.2 * np.sin(2 * np.pi * 420 * k) * np.exp(-k * 30)
    save("car_door", x, -4.0)


def knock():
    x = np.zeros(int(0.8 * SR))
    for s in (0.0, 0.22, 0.4):
        k = t(0.12)
        hit = np.sin(2 * np.pi * 900 * k) * np.exp(-k * 80) + lowpass(rng.standard_normal(len(k)), 3000) * np.exp(-k * 120)
        i = int(s * SR)
        x[i:i + len(k)] += hit
    save("knock", x, -6.0)


if __name__ == "__main__":
    phone_ring()
    engine_idle()
    window_slide()
    handset()
    barrier_button()
    car_door()
    knock()
