#!/usr/bin/env python3
"""
Builds the game's ambience sound set into assets/audio/.

Two kinds of sounds:
  * Recorded CC0 sounds from OpenGameArt.org (see assets/audio/CREDITS.md).
    Download them with tools/fetch_audio.sh, then this script trims them,
    normalises loudness and turns ambience beds into seamless loops.
  * Synthesised sounds (fluorescent hum, CRT whine, clock tick, light zap).
    These are generated here from scratch, so they are ours outright.

Usage:
    python3 tools/build_audio.py <folder with the downloaded raw sounds> [<music folder>]

Requires: ffmpeg on PATH, numpy.
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


# ---------------------------------------------------------------- helpers
def decode(path, start=None, dur=None, channels=2, filters=None):
    cmd = ["ffmpeg", "-v", "error"]
    if start is not None:
        cmd += ["-ss", str(start)]
    if dur is not None:
        cmd += ["-t", str(dur)]
    cmd += ["-i", path, "-ac", str(channels), "-ar", str(SR)]
    if filters:
        cmd += ["-af", filters]
    cmd += ["-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, channels).copy()


def loudness_lufs(x):
    """Rough integrated loudness (K-weighting skipped; good enough to level beds)."""
    rms = np.sqrt(np.mean(x.astype(np.float64) ** 2) + 1e-12)
    return 20 * np.log10(rms) - 0.691 + 3.0


def normalise(x, target_lufs, peak=0.89):
    g = 10 ** ((target_lufs - loudness_lufs(x)) / 20)
    y = x * g
    p = np.max(np.abs(y))
    if p > peak:
        y *= peak / p
    return y


def make_loop(x, fade_s=2.0):
    """Equal-power crossfade of the tail into the head -> seamless loop."""
    n = len(x)
    f = int(fade_s * SR)
    t = np.linspace(0, 1, f, dtype=np.float32)[:, None]
    fin, fout = np.sin(t * np.pi / 2), np.cos(t * np.pi / 2)
    out = x[: n - f].copy()
    out[:f] = x[:f] * fin + x[n - f:] * fout
    return out


def fade(x, fin=0.01, fout=0.05):
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)[:, None]
    if b:
        x[-b:] *= np.linspace(1, 0, b)[:, None]
    return x


def encode(x, name, quality=5):
    path = os.path.join(OUT, name)
    ch = x.shape[1]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(ch),
         "-i", "-", "-c:a", "libvorbis", "-q:a", str(quality), path],
        input=np.clip(x, -1, 1).astype(np.float32).tobytes(), check=True)
    print(f"  {name:24s} {len(x)/SR:6.1f}s  {ch}ch  {loudness_lufs(x):6.1f} LUFS")


def fft_filter(x, lo=None, hi=None):
    """Brick-ish band filter in the frequency domain (fine for noise beds)."""
    X = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo:
        m *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m[:, None], n=len(x), axis=0).astype(np.float32)


# ------------------------------------------------------------ recorded
def build_recorded(src):
    p = lambda *a: os.path.join(src, *a)
    print("Recorded (CC0, OpenGameArt):")

    x = decode(p("Rain OGG", "4.ogg"))
    encode(normalise(make_loop(x, 3.0), -24), "rain_light.ogg")

    x = decode(p("Rain OGG", "2.ogg"))
    encode(normalise(make_loop(x, 3.0), -20), "rain_heavy.ogg")

    # Long indoor-ish rain recording: a 70 s slice as the "rain on the roof" bed.
    x = decode(p("amb_rain2.ogg"), start=120, dur=72, filters="lowpass=2600")
    encode(normalise(make_loop(x, 4.0), -24), "rain_roof.ogg")

    x = decode(p("rain_on_window_loop.wav"), channels=1)
    encode(normalise(make_loop(x, 1.0), -22), "rain_window.ogg")

    x = decode(p("rain-gutter-loop_0.mp3"), channels=1)
    encode(normalise(make_loop(x, 3.0), -24), "rain_gutter.ogg")

    x = decode(p("windy_ambiance.ogg"), start=20, dur=95)
    encode(normalise(make_loop(x, 6.0), -26), "wind.ogg")

    x = decode(p("sfx_100_v2", "sfx100v2_loop_highway.ogg"), filters="lowpass=1400")
    encode(normalise(make_loop(x, 3.0), -30), "traffic_distant.ogg")

    x = decode(p("rain-thunder.ogg"), start=21.0, dur=23.3, filters="highpass=25")
    encode(normalise(fade(x, 0.4, 4.0), -18), "thunder_1.ogg")

    x = decode(p("sfx_100_v2", "sfx100v2_thunder_01.ogg"))
    encode(normalise(fade(x, 0.02, 1.5), -18), "thunder_2.ogg")

    x = decode(p("low-rumbling-176033.mp3"), filters="lowpass=380")
    encode(normalise(fade(x, 1.5, 5.0), -22), "thunder_3.ogg")

    x = decode(p("tree_creak.ogg"), channels=1)
    encode(normalise(fade(x, 0.05, 0.5), -24), "tree_creak.ogg")

    x = decode(p("buzz.ogg"), channels=1)
    encode(normalise(make_loop(x, 0.25), -26), "lamp_buzz.ogg")

    x = decode(p("mouseclick.wav"), channels=1)
    encode(normalise(fade(x, 0.0, 0.01), -20), "mouse_click.ogg")


# --------------------------------------------------------- synthesised
def build_synth():
    rng = np.random.default_rng(1989)
    print("Synthesised:")

    # Fluorescent ballast hum: 120 Hz (60 Hz mains, US) + harmonics + gritty buzz.
    n = SR * 4
    t = np.arange(n) / SR
    x = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.55), (3, 0.30), (4, 0.18), (6, 0.10), (8, 0.05)]:
        x += a * np.sin(2 * np.pi * 120 * h * t + rng.uniform(0, 6.28))
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.06
    noise = fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 2000, 7000)[:, 0] * 0.02
    x = (x + buzz) * (1 + 0.03 * np.sin(2 * np.pi * 0.25 * t)) + noise
    encode(normalise(x[:, None].astype(np.float32), -28), "fluorescent_hum.ogg")

    # CRT: 60 Hz transformer hum, faint flyback whine (15.7 kHz) and static hiss.
    n = SR * 4
    t = np.arange(n) / SR
    hum = 0.5 * np.sin(2 * np.pi * 60 * t) + 0.25 * np.sin(2 * np.pi * 180 * t)
    whine = 0.05 * np.sin(2 * np.pi * 15734 * t)
    hiss = fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 3000, 9000)[:, 0] * 0.03
    x = hum + whine + hiss
    encode(normalise(x[:, None].astype(np.float32), -32), "crt_hum.ogg")

    # Wall clock tick: short filtered click with a woody body.
    n = int(SR * 0.08)
    t = np.arange(n) / SR
    click = rng.normal(0, 1, n) * np.exp(-t * 400)
    body = np.sin(2 * np.pi * 1850 * t) * np.exp(-t * 120) * 0.6
    body += np.sin(2 * np.pi * 3300 * t) * np.exp(-t * 200) * 0.3
    x = (click * 0.4 + body)[:, None].astype(np.float32)
    encode(normalise(fade(x, 0.0, 0.01), -26), "clock_tick.ogg")

    # Fluorescent flicker zap: crackly clicks + buzz burst.
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for c in rng.uniform(0, 0.45, 7):
        i = int(c * SR)
        m = min(n - i, int(0.03 * SR))
        x[i:i + m] += rng.normal(0, 1, m) * np.exp(-np.arange(m) / SR * 160)
    x += np.sign(np.sin(2 * np.pi * 120 * t)) * 0.25 * np.exp(-t * 6)
    encode(normalise(fade(x[:, None].astype(np.float32), 0.0, 0.1), -22), "light_flicker.ogg")


# ---------------------------------------------------------------- radio
# CC0 tracks from OpenGameArt (see CREDITS.md), output name -> source file.
RADIO_TRACKS = [
    ("radio_1.ogg", "bluesy_baritone.mp3"),
    ("radio_2.ogg", "jazz_improv_looped_1.mp3"),
    ("radio_3.ogg", "Jazz Take 2.mp3"),
    ("radio_4.ogg", "blue_intermission.ogg"),
    ("radio_5.ogg", "blues.mp3"),
]


def transistor(x):
    """A small 80s desk radio: narrow band, a little compression and grit, mono."""
    y = fft_filter(x, lo=170, hi=4600)
    y = normalise(y, -18, peak=0.99)
    drive = 1.8
    y = np.tanh(y * drive) / np.tanh(drive)
    return y.astype(np.float32)


def build_radio(src):
    print("Radio (CC0 music, OpenGameArt):")
    for out, name in RADIO_TRACKS:
        x = decode(os.path.join(src, name), channels=1)
        y = transistor(x)
        encode(normalise(fade(y, 0.3, 2.0), -20), out, quality=3)


def build_radio_fx():
    rng = np.random.default_rng(7)
    print("Radio effects (synthesised):")
    # FM hiss loop with the odd crackle.
    n = SR * 4
    hiss = fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 300, 5000)[:, 0] * 0.3
    for c in rng.uniform(0, 4, 14):
        i = int(c * SR)
        m = min(n - i, int(0.004 * SR))
        hiss[i:i + m] += rng.normal(0, 1, m) * 0.6
    encode(normalise(make_loop(hiss[:, None].astype(np.float32), 0.3), -30), "radio_hiss.ogg")
    # Knob switch click.
    n = int(SR * 0.09)
    t = np.arange(n) / SR
    x = rng.normal(0, 1, n) * np.exp(-t * 300) * 0.5 + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 90) * 0.5
    encode(normalise(fade(x[:, None].astype(np.float32), 0.0, 0.01), -24), "radio_click.ogg")
    # Static burst while the set warms up, with a tuning whistle sliding down.
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    noise = fft_filter(rng.normal(0, 1, (n, 1)).astype(np.float32), 300, 5000)[:, 0]
    whistle = np.sin(2 * np.pi * np.cumsum(np.linspace(2400, 600, n)) / SR) * 0.15
    env = np.minimum(1, t / 0.03) * np.exp(-t * 3.5)
    x = (noise * 0.5 + whistle) * env
    encode(normalise(fade(x[:, None].astype(np.float32), 0.0, 0.15), -26), "radio_static.ogg")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1:
        build_recorded(sys.argv[1])
    else:
        print("No source folder given: skipping recorded sounds.")
    if len(sys.argv) > 2:
        build_radio(sys.argv[2])
    build_synth()
    build_radio_fx()
