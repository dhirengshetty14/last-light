"""Mix the captured Godot sequence from the original radio clips and the photographed flight's JSONL."""

from pathlib import Path
import json
import sys
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
log, destination = map(Path, sys.argv[1:3])
sr = 24000
seconds = 1361 / 24
mix = np.zeros(round(seconds * sr), dtype=float)


def tone(notes, duration, kind, gain):
    t = np.arange(round(sr * duration)) / sr
    phase = t / duration
    env = np.minimum(t * 20, 1) * np.minimum((duration - t) * 10, 1)
    voice = np.zeros(len(t))
    for i, hz in enumerate(notes):
        if kind == "whale":
            hz = hz * (1 + 0.04 * np.sin(t * 1.7 + i * 0.5))
        voice += np.sin(2 * np.pi * hz * t + 0.23 * np.sin(t * 2 + i))
    if kind == "latch":
        env *= np.exp(-phase * 7)
    if kind == "score":
        env *= 0.65 + 0.2 * np.sin(2 * np.pi * phase)
    return voice * gain * env / len(notes)


def lay(t, data):
    n = round(t * sr)
    end = min(len(mix), n + len(data))
    if n < len(mix):
        mix[n:end] += data[: end - n]


def voice(name):
    with wave.open(str(root / "assets/audio" / (name + ".wav"))) as wav:
        assert wav.getframerate() == sr and wav.getnchannels() == 1
        return np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2") / 32768


score = tone([55, 82.5, 110], 3.4, "score", 0.065)
for t in np.arange(0, seconds, 3.4):
    lay(t, score)
lay(40 / 24, tone([196, 246.94], 1.37, "whale", 0.17))
for name, frame in [("pip_story", 93), ("morrow_story", 183), ("zip_story", 303)]:
    lay(frame / 24, voice(name) * 0.82)
effects = {
    "latch": tone([660, 990], 0.15, "latch", 0.18),
    "gravity": tone([196, 246.94, 293.66], 0.8, "whale", 0.22),
    "contact": tone([420, 710], 0.22, "latch", 0.21),
    "end": tone([146.83, 196, 246.94, 329.63, 392], 2.4, "whale", 0.24),
}
next_speech = 486 / 24
for event in (json.loads(row) for row in log.read_text().splitlines()):
    tick = event.get("tick", 0)
    t = 486 / 24 + min(600, tick) / 60 + max(0, tick - 600) / 216
    if event["kind"] in effects:
        lay(t, effects[event["kind"]])
    if (
        event["kind"] != "ledger"
        or event.get("seat", -1) < 2
        or not event.get("cue")
        or t < next_speech
    ):
        continue
    name = ["nell", "rafi", "pip", "morrow", "zip"][event["seat"]] + "_" + event["cue"]
    if (root / "assets/audio" / (name + ".wav")).is_file():
        utterance = voice(name)
        lay(t, utterance * 0.76)
        next_speech = t + len(utterance) / sr + 0.34
mix[-sr:] *= np.linspace(1, 0, sr)
with wave.open(str(destination), "wb") as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(sr)
    out.writeframes((np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
