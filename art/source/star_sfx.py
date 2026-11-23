"""Render Last Light's match sound effects. Requires numpy. Run: python3 art/source/star_sfx.py"""

import wave
from pathlib import Path

import numpy as np

DEST = Path(__file__).resolve().parents[2] / "assets/last_light"
SR = 32000
rng = np.random.default_rng(7)


def clock(seconds):
    return np.arange(round(seconds * SR)) / SR


def fade(y, attack=0.004, release=0.03):
    t = clock(len(y) / SR)
    return y * np.minimum(1, t / attack) * np.minimum(1, (t[-1] - t) / release)


def noise(seconds, low, high):
    """Band-limited noise from a filtered spectrum, so each effect has its own colour."""
    n = round(seconds * SR)
    spectrum = np.fft.rfft(rng.normal(0, 1, n))
    freq = np.fft.rfftfreq(n, 1 / SR)
    spectrum *= np.exp(-0.5 * ((np.log(np.maximum(freq, 1)) - np.log(np.sqrt(low * high))) / (np.log(high / low) / 2.4)) ** 2)
    y = np.fft.irfft(spectrum, n)
    return y / np.max(np.abs(y))


def bell(freq, seconds, bright=1.0):
    """Struck metal: inharmonic partials that die at different rates."""
    t = clock(seconds)
    y = np.zeros(len(t))
    for ratio, gain, decay in [(1, 1, 3.2), (2.76, 0.55, 5.5), (5.4, 0.3 * bright, 9), (8.93, 0.16 * bright, 14)]:
        y += gain * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * t)
    return y


def sweep(f0, f1, seconds, curve=1.0):
    t = clock(seconds)
    f = f0 + (f1 - f0) * (t / t[-1]) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def mix(seconds, *layers):
    y = np.zeros(round(seconds * SR))
    for start, gain, part in layers:
        a = round(start * SR)
        part = part[: len(y) - a]
        y[a : a + len(part)] += gain * part
    return y


def store(name, y, peak=0.82):
    y = fade(y) * (peak / max(1e-6, np.max(np.abs(y))))
    with wave.open(str(DEST / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, SR, 0, "NONE", ""))
        f.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())
    print(name, f"{len(y) / SR:.2f}s")


t = clock(0.30)
store("dash", noise(0.30, 500, 5200) * np.exp(-((t - 0.09) / 0.075) ** 2) + 0.25 * sweep(240, 90, 0.30) * np.exp(-9 * t), 0.62)
t = clock(0.16)
store("catch", mix(0.16, (0, 1.0, sweep(210, 95, 0.16) * np.exp(-26 * t)), (0, 0.35, noise(0.05, 1800, 7000) * np.exp(-90 * clock(0.05)))), 0.55)
t = clock(0.20)
store("throw", noise(0.20, 900, 6500) * np.exp(-((t - 0.05) / 0.05) ** 2) + 0.2 * sweep(520, 900, 0.20) * np.exp(-16 * t), 0.5)
t = clock(0.26)
store("steal", mix(0.26, (0, 0.9, noise(0.07, 1500, 8000) * np.exp(-60 * clock(0.07))), (0.01, 0.8, sweep(880, 300, 0.25, 0.6) * np.exp(-13 * clock(0.25)))), 0.7)
store(
    "goal_big",
    mix(
        1.9,
        (0, 0.9, sweep(70, 38, 0.5) * np.exp(-7 * clock(0.5))),
        (0, 0.75, bell(523.25, 1.9)),
        (0.09, 0.6, bell(659.25, 1.8)),
        (0.18, 0.6, bell(783.99, 1.7)),
        (0.30, 0.7, bell(1046.5, 1.6, 1.4)),
        (0.05, 0.22, noise(1.2, 3000, 9000) * np.exp(-3.2 * clock(1.2))),
    ),
    0.86,
)
store("deal", mix(0.75, (0, 0.8, bell(587.33, 0.7, 0.6)), (0.11, 0.8, bell(880, 0.6, 0.6)), (0, 0.25, noise(0.03, 2500, 9000))), 0.55)
store("paid", mix(0.8, (0, 0.7, bell(1318.5, 0.5)), (0.07, 0.7, bell(1568, 0.5)), (0.14, 0.8, bell(2093, 0.6, 1.3)), (0.14, 0.15, noise(0.35, 5000, 11000) * np.exp(-9 * clock(0.35)))), 0.6)
store(
    "broken",
    mix(
        0.9,
        (0, 1.0, noise(0.06, 900, 9000) * np.exp(-45 * clock(0.06))),
        (0.02, 0.7, bell(311.13, 0.85, 0.5)),
        (0.02, 0.6, bell(329.63, 0.85, 0.5)),
        (0.05, 0.9, sweep(140, 48, 0.5, 0.7) * np.exp(-6 * clock(0.5))),
    ),
    0.78,
)
clank = bell(410, 0.22, 1.8) + 0.5 * noise(0.22, 1200, 6000) * np.exp(-40 * clock(0.22))
store("strike", mix(0.62, (0, 1.0, clank), (0.27, 0.8, bell(350, 0.32, 1.8) + 0.4 * noise(0.32, 1000, 5000) * np.exp(-40 * clock(0.32)))), 0.7)
t = clock(0.34)
store("radio", mix(0.34, (0, 0.6, noise(0.30, 1200, 3600) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * clock(0.30))))), (0.05, 0.5, np.sin(2 * np.pi * 1320 * clock(0.09))), (0.20, 0.5, np.sin(2 * np.pi * 990 * clock(0.09)))), 0.42)
t = clock(1.1)
store("vote", mix(1.1, *[(k * 0.36, 0.9, sweep(196, 185, 0.30) * np.exp(-7 * clock(0.30)) + 0.5 * bell(392, 0.30, 0.4)) for k in range(3)]), 0.6)
t = clock(2.4)
store(
    "powerdown",
    mix(
        2.6,
        (0, 0.8, sweep(620, 42, 2.0, 0.55) * (1 - 0.6 * t[: round(2.0 * SR)] / 2.4)),
        (0, 0.35, noise(2.0, 300, 2400) * np.linspace(1, 0, round(2.0 * SR)) ** 2),
        (1.85, 1.0, sweep(58, 30, 0.7) * np.exp(-5 * clock(0.7))),
        (1.85, 0.3, noise(0.12, 80, 500) * np.exp(-25 * clock(0.12))),
    ),
    0.86,
)
t = clock(0.55)
store("whistle", np.sin(2 * np.pi * (2850 * t + 14 * np.sin(2 * np.pi * 31 * t) / (2 * np.pi * 31) * 31)) * (0.75 + 0.25 * noise(0.55, 2000, 6000)) * np.minimum(1, t / 0.02), 0.5)
t = clock(0.07)
store("tick", sweep(1500, 900, 0.07) * np.exp(-55 * t), 0.4)


# ---------------------------------------------------------------- menus, crowd and harbor


def store_loop(name, y, peak=0.7):
    """A loop: no fades, so the end runs straight back into the start."""
    y = y * (peak / max(1e-6, np.max(np.abs(y))))
    with wave.open(str(DEST / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, SR, 0, "NONE", ""))
        f.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())
    print(name, f"{len(y) / SR:.2f}s loop")


def pad(part, seconds):
    out = np.zeros(round(seconds * SR))
    out[: len(part)] = part[: len(out)]
    return out


t = clock(0.07)
store("ui_move", sweep(2100, 1650, 0.07) * np.exp(-55 * t) + 0.12 * noise(0.07, 3000, 9000) * np.exp(-90 * t), 0.32)
store("ui_pick", mix(0.6, (0, 0.8, bell(1318.5, 0.55, 0.8)), (0.07, 0.8, bell(1975.5, 0.5, 0.8)), (0, 0.18, noise(0.12, 2000, 8000) * np.exp(-30 * clock(0.12)))), 0.5)
store("ui_back", mix(0.5, (0, 0.8, bell(1174.7, 0.4, 0.6)), (0.07, 0.8, bell(783.99, 0.42, 0.6))), 0.42)
t = clock(0.26)
flip = noise(0.26, 1400, 7500) * np.exp(-(((t - 0.07) / 0.045) ** 2)) * (0.65 + 0.35 * np.sin(2 * np.pi * 70 * t))
store("page", flip + 0.3 * mix(0.26, (0.11, 1.0, sweep(160, 80, 0.15) * np.exp(-22 * clock(0.15)))), 0.5)
t = clock(0.75)
x = t / t[-1]
store("whoosh", np.sin(np.pi * x) ** 2 * (noise(0.75, 200, 1200) * (1 - x) + noise(0.75, 800, 3200) * np.sin(np.pi * x) + noise(0.75, 2500, 9500) * x), 0.5)
store(
    "title_hit",
    mix(
        3.4,
        (0, 1.0, sweep(92, 38, 1.3) * np.exp(-2.4 * clock(1.3))),
        (0, 0.45, noise(0.16, 50, 420) * np.exp(-20 * clock(0.16))),
        (0.02, 0.42, bell(261.63, 3.2, 0.7)),
        (0.08, 0.38, bell(392.0, 3.1, 0.7)),
        (0.14, 0.38, bell(523.25, 3.0, 0.8)),
        (0.20, 0.32, bell(659.25, 2.9, 0.9)),
        (0.26, 0.28, bell(987.77, 2.8, 1.0)),
        (0.1, 0.14, noise(2.6, 4000, 11000) * np.exp(-1.5 * clock(2.6))),
    ),
    0.8,
)
store("lamp", mix(0.45, (0, 0.8, bell(1046.5, 0.42, 1.2)), (0, 0.3, noise(0.02, 2000, 9000) * np.exp(-200 * clock(0.02)))), 0.4)
t = clock(0.18)
store("count", (np.sin(2 * np.pi * 880 * t) + 0.3 * np.sin(2 * np.pi * 1760 * t)) * np.exp(-9 * t) * np.minimum(1, t / 0.004), 0.5)
t = clock(0.5)
store("count_go", (np.sin(2 * np.pi * 1320 * t) + 0.35 * np.sin(2 * np.pi * 2640 * t)) * np.exp(-4 * t) + 0.4 * bell(1760, 0.5, 1.2), 0.55)
# A crowd: many voices swelling at slightly different moments, then claps.
t = clock(3.2)
crowd = np.zeros(len(t))
for k in range(16):
    f = rng.uniform(280, 1300)
    start = rng.uniform(0, 0.3)
    swell = np.clip((t - start) / 0.28, 0, 1) * np.exp(-0.75 * np.maximum(t - start - 0.6, 0))
    crowd += noise(3.2, f * 0.7, f * 1.7) * swell * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(3, 7) * t + rng.uniform(0, 6)))
for k in range(70):
    at = rng.uniform(0.2, 2.8)
    clap = noise(0.03, 1200, 6500) * np.exp(-160 * clock(0.03))
    a = round(at * SR)
    crowd[a : a + len(clap)] += 1.4 * clap[: len(crowd) - a] * np.exp(-0.6 * at)
store("crowd_cheer", crowd, 0.62)
t = clock(1.5)
store(
    "splash",
    noise(1.5, 140, 2600) * np.exp(-3.6 * t)
    + 0.55 * noise(1.5, 1600, 7000) * np.exp(-2.2 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t))
    + 0.7 * pad(sweep(110, 45, 0.45) * np.exp(-7 * clock(0.45)), 1.5),
    0.6,
)
fire = mix(
    2.4,
    (0, 0.18, sweep(700, 2300, 0.55, 0.7) * np.minimum(1, clock(0.55) / 0.2)),
    (0.55, 1.0, noise(0.7, 50, 900) * np.exp(-6 * clock(0.7))),
    (0.55, 0.7, sweep(75, 38, 0.6) * np.exp(-5 * clock(0.6))),
)
for k in range(110):
    at = 0.68 + rng.exponential(0.45)
    if at < 2.35:
        a = round(at * SR)
        snap = noise(0.012, 2500, 10000) * np.exp(-300 * clock(0.012))
        fire[a : a + len(snap)] += 0.5 * snap[: len(fire) - a] * np.exp(-1.2 * (at - 0.68))
store("firework", fire, 0.62)
store(
    "fanfare",
    mix(
        3.0,
        (0, 0.6, bell(523.25, 2.6, 0.9)),
        (0.12, 0.6, bell(659.25, 2.5, 0.9)),
        (0.24, 0.6, bell(783.99, 2.4, 0.9)),
        (0.40, 0.75, bell(1046.5, 2.4, 1.1)),
        (0.40, 0.45, bell(1318.5, 2.3, 1.1)),
        (0.40, 0.5, sweep(65, 40, 1.0) * np.exp(-3 * clock(1.0))),
        (0.42, 0.12, noise(2.0, 4000, 11000) * np.exp(-1.8 * clock(2.0))),
    ),
    0.8,
)
# The sea: a slow swell and the wash of it against the hulls. Built to loop every eight seconds.
t = clock(8.0)
surf = noise(8.0, 70, 700)
hiss = noise(8.0, 1200, 7000)
swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / 4.0)
wash = np.clip(np.sin(2 * np.pi * t / 4.0 - 0.9), 0, 1) ** 2
store_loop("waves", surf * swell * 0.9 + hiss * (0.12 + 0.55 * wash), 0.6)
