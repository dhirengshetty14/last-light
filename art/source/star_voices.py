"""Bake the five Last Light voices using Kyutai Pocket TTS preset speakers."""

from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from pocket_tts import TTSModel

CAST = {
    "nell": (
        "alba",
        {
            "intro": "When the sun goes down, this little star keeps the harbor lit. Let's get it home."
        },
    ),
    "rafi": (
        "marius",
        {"intro": "Look for my purple jacket. If you get boxed in, pass it here."},
    ),
    "pip": (
        "cosette",
        {
            "intro": "Blue gave me a jersey. Gold could always use a good pair of hands.",
            "join": "Deal. You and me, gold side.",
            "steal": "Ooh, I'll take that!",
        },
    ),
    "morrow": (
        "jean",
        {
            "intro": "Everyone has a favorite route. Give me time. I'll find yours.",
            "steal": "I remember that move.",
            "join": "We have an agreement.",
        },
    ),
    "zip": (
        "javert",
        {
            "intro": "See the blue ring? Bet I can get there before you turn around.",
            "steal": "Coming through!",
            "join": "Gold it is. Try to keep up.",
        },
    ),
}
if __name__ == "__main__":
    torch.set_num_threads(4)
    torch.manual_seed(163)
    model = TTSModel.load_model()
    dest = Path(__file__).resolve().parents[2] / "assets/last_light"
    for actor, (preset, lines) in CAST.items():
        state = model.get_state_for_audio_prompt(preset)
        for cue, line in lines.items():
            audio = model.generate_audio(state, line).numpy().reshape(-1)
            active = np.flatnonzero(np.abs(audio) > 0.007)
            audio = audio[max(0, active[0] - 480) : active[-1] + 960]
            sf.write(
                dest / f"{actor}_{cue}.wav",
                audio * (0.85 / max(0.1, np.abs(audio).max())),
                model.sample_rate,
            )
            print(actor, cue, flush=True)
