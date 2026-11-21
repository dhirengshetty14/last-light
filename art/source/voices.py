"""Bake short, local intent lines. Arguments are kokoro.onnx and voices.bin."""

import sys
import wave
from pathlib import Path
import numpy as np
import onnxruntime as ort
from kokoro_onnx import Kokoro

root = Path(__file__).resolve().parents[2]
opt = ort.SessionOptions()
opt.intra_op_num_threads = 3
opt.inter_op_num_threads = 1
k = Kokoro.from_session(
    ort.InferenceSession(sys.argv[1], opt, providers=["CPUExecutionProvider"]),
    sys.argv[2],
)
cast = {
    "pip": (
        "af_heart",
        "en-us",
        0.98,
        {
            "cover": "I've got her. Give me a little slack.",
            "deal": "I'll remember who held the line.",
            "reel": "Recording's secure.",
            "story": "That's a calf in there, Nell. Hold the line. I'll take the catch.",
        },
    ),
    "morrow": (
        "bm_george",
        "en-gb",
        0.95,
        {
            "echo": "Listen. She's waiting for an answer.",
            "deal": "We can still save both.",
            "reel": "Their voices are all here.",
            "cover": "I'll hold this landing.",
            "story": "There are three voices on this reel. Hers is the only one still singing.",
        },
    ),
    "zip": (
        "am_puck",
        "en-us",
        1.05,
        {
            "rush": "Blue rail's mine. Take your time.",
            "deal": "Give me the rail and you've got a deal.",
            "reel": "Special delivery.",
            "cover": "Brakes on. Send her through.",
            "story": "One pass, Rafi. When that hatch lines up, I'll be on the rail.",
        },
    ),
}
for actor, (voice, lang, speed, lines) in cast.items():
    for cue, words in lines.items():
        data, sr = k.create(words, voice=voice, lang=lang, speed=speed)
        active = np.flatnonzero(np.abs(data) > 0.003)
        data = data[max(0, active[0] - 280) : active[-1] + 350]
        data = data * (0.82 / max(0.2, np.max(np.abs(data))))
        path = root / "assets" / "audio" / f"{actor}_{cue}.wav"
        with wave.open(str(path), "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(sr)
            f.writeframes((np.clip(data, -1, 1) * 32767).astype("<i2").tobytes())
