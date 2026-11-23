"""Bake the five Last Light voices using Kyutai Pocket TTS preset speakers."""

import argparse
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from pocket_tts import TTSModel

CAST = {
    "nell": (
        "alba",
        {
            "intro": "I used to race the last ferry home. Give me one open lane.",
            "truce": "They've all walked out. Rafi, truce?",
        },
    ),
    "rafi": (
        "marius",
        {
            "intro": "Dad wired that gold ring. Tonight, you and me light it for him.",
            "truce": "Truce. Gold ring, together.",
        },
    ),
    "pip": (
        "cosette",
        {
            "outlet": "I can take the pass.",
            "relay": "That did it! Dash is back.",
            "intro": "See these little hands? Best pickpocket on Saturn. Check your pockets.",
            "join": "Deal. You and me, gold side.",
            "steal": "Ooh, I'll take that!",
            # Free Agents: what each robot says about its own promises.
            "terms": "Next shot's mine. That's the deal.",
            "paid": "Paid in full! Pleasure doing business.",
            "broken": "Hey! That was my shot!",
            "walk": "I'm taking my hands elsewhere.",
            "strike": "Tools down. Make me a better offer.",
            "restless": "Anybody need a thief? I'm open to offers.",
            "no": "Nope. I like it here.",
            "sign": "Deal. I'm with you.",
            "call": "Both captains cheat. Machines, who's walking?",
            "aye": "Walk out!",
            "nay": "I got paid. I stay.",
            "union": "Lights out, captains!",
        },
    ),
    "morrow": (
        "jean",
        {
            "outlet": "I'm open on this side.",
            "relay": "Relay is lit. Make your run.",
            "intro": "Thirty winters guarding this dock. I remember every runner who got past me.",
            "steal": "I remember that move.",
            "join": "We have an agreement.",
            # Morrow tells the story before the cast is introduced.
            "tale1": "When the sun drops behind Saturn, the whales follow one light home.",
            "tale2": "We play for who lights it. Tonight is the last night anyone lights it by hand.",
            "tale3": "They have promised us machines a turn for thirty winters. Tonight, we are counting.",
            "terms": "Score it off a pass. That is my price.",
            "paid": "You kept your word. I will remember that too.",
            "broken": "You gave me your word.",
            "walk": "Then I stand with the other captain.",
            "strike": "I do not move until you make this right.",
            "restless": "Nobody passes to the old keeper.",
            "no": "I keep faith with my captain.",
            "sign": "We have an agreement.",
            "call": "Machines, to the radio. They have both broken their word.",
            "aye": "Enough. Walk out.",
            "nay": "My captain kept faith. I stay.",
            "union": "Then we light it ourselves.",
        },
    ),
    "zip": (
        "javert",
        {
            "outlet": "Hit me on the wing!",
            "relay": "Dash is up. Go, go!",
            "intro": "I delivered your jersey this morning. Want to see how fast?",
            "steal": "Coming through!",
            "join": "Gold it is. Try to keep up.",
            "terms": "Passes to me. I'm counting.",
            "paid": "That's the count. We're square.",
            "broken": "You promised me passes!",
            "walk": "Find yourself another courier.",
            "strike": "I'm not running another step for free.",
            "restless": "I'm open! Somebody make me an offer.",
            "no": "Not interested. Ask me later.",
            "sign": "I'm in. Try to keep up.",
            "call": "They both lied. I'm calling a vote.",
            "aye": "Walk out, now!",
            "nay": "No quarrel here. I stay.",
            "union": "Our harbor now.",
        },
    ),
}
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--missing", action="store_true")
    parser.add_argument("--cue", help="Bake only this cue for every speaker")
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.manual_seed(163)
    model = TTSModel.load_model()
    dest = Path(__file__).resolve().parents[2] / "assets/last_light"
    for actor, (preset, lines) in CAST.items():
        state = model.get_state_for_audio_prompt(preset)
        for cue, line in lines.items():
            if args.cue and args.cue != cue:
                continue
            if args.missing and (dest / f"{actor}_{cue}.wav").exists():
                continue
            audio = model.generate_audio(state, line).numpy().reshape(-1)
            active = np.flatnonzero(np.abs(audio) > 0.007)
            audio = audio[max(0, active[0] - 480) : active[-1] + 960]
            sf.write(
                dest / f"{actor}_{cue}.wav",
                audio * (0.85 / max(0.1, np.abs(audio).max())),
                model.sample_rate,
            )
            print(actor, cue, flush=True)
