"""Render the Last Light original eight-bar score and game sounds. Requires numpy and soundfile."""

import soundfile as sf
import wave
from pathlib import Path
import numpy as np

DEST = Path(__file__).resolve().parents[2] / "assets/last_light"
SR = 32000
BEAT = 60 / 110
TOTAL = round(32 * BEAT * SR)
song = np.zeros((TOTAL, 2))
rng = np.random.default_rng(24)


def note(midi, beats, kind):
    t = np.arange(round(beats * BEAT * SR)) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    phase = 2 * np.pi * f * t
    if kind == "keys":
        y = np.sin(phase + 1.25 * np.exp(-9 * t) * np.sin(phase * 2)) + 0.28 * np.sin(
            phase * 2.006
        )
        env = np.exp(-3.5 * t)
    elif kind == "bow":
        y = (
            0.75 * np.sin(phase + 0.08 * np.sin(27 * t))
            + 0.21 * np.sin(2 * phase)
            + 0.17 * np.sin(phase * 1.003)
        )
        env = (1 - np.exp(-4 * t)) * np.exp(-0.5 * t)
    else:
        y = np.sin(phase) + 0.21 * np.sin(phase * 2) + 0.10 * np.sin(phase * 3)
        env = np.exp(-2.4 * t)
    return y * env * np.minimum(1, t / 0.012) * np.minimum(1, (t[-1] - t) / 0.085)


def place(beat, y, gain, pan=0):
    idx = (round(beat * BEAT * SR) + np.arange(len(y))) % TOTAL
    song[idx] += gain * y[:, None] * np.sqrt(np.array([1 - pan, 1 + pan]) * 0.5)


def store(path, y):
    with wave.open(str(path), "wb") as f:
        f.setparams((1 if y.ndim == 1 else y.shape[1], 2, SR, 0, "NONE", ""))
        f.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())


chords = [(50, 53, 57, 64), (46, 53, 57, 62), (48, 53, 57, 60), (48, 52, 55, 62)]
hook = [
    [(0, 69), (0.75, 72), (1.5, 74), (2.75, 69)],
    [(0.5, 65), (1.5, 67), (2, 69)],
    [(0, 72), (1, 69), (1.75, 65), (3, 67)],
    [(0.5, 64), (1.5, 67), (2.75, 62)],
]
for bar in range(8):
    chord = chords[bar % 4]
    for j, pitch in enumerate(chord):
        place(4 * bar, note(pitch, 4.2, "bow"), 0.12, (j - 1.5) / 2)
    for j in range(8):
        place(
            4 * bar + j / 2,
            note(chord[[0, 2, 1, 3, 2, 0, 3, 1][j]] + 12, 0.91, "keys"),
            0.08,
            0.36 * (-1) ** j,
        )
        t = np.arange(round(0.11 * SR)) / SR
        noise = np.diff(rng.normal(0, 0.45, len(t) + 1))
        place(
            4 * bar + j / 2,
            noise * np.exp(-55 * t),
            0.027 if j % 2 == 0 else 0.042,
            -0.28,
        )
    for b in [0, 2, 3.5]:
        place(4 * bar + b, note(chord[0] - 12, 1.15, "bass"), 0.30)
        t = np.arange(round(0.24 * SR)) / SR
        place(
            4 * bar + b,
            np.sin(2 * np.pi * (47 * t + 0.95 * (1 - np.exp(-28 * t))))
            * np.exp(-18 * t),
            0.24,
        )
    for b, pitch in hook[bar % 4]:
        y = note(pitch + (12 if bar == 7 and b == 2.75 else 0), 1.40, "keys")
        place(4 * bar + b, y, 0.35, 0.05)
        place(4 * bar + b + 0.75, y, 0.075, -0.55)
sf.write(DEST / "last_light.ogg", np.tanh(song * 1.13) * 0.89, SR, subtype="VORBIS")
for name, pitches in {
    "goal": [69, 72, 76, 81],
    "turnover": [69, 62],
    "toss": [76, 81],
    "accord": [62, 69, 74],
}.items():
    y = np.zeros(SR)
    for i, pitch in enumerate(pitches):
        n = note(pitch, 0.85, "keys")
        start = round(i * 0.096 * SR)
        y[start : start + len(n)] += 0.32 * n
    store(DEST / (name + ".wav"), y)
