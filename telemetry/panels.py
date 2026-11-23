"""Draw each finished match as one comic panel with Runware, for the game's final screen.

    python3 telemetry/panels.py configure    once: your Runware API key, asked for privately
    python3 telemetry/panels.py run          watch for finished matches (dashboard.py starts it)
    python3 telemetry/panels.py draw <log>   draw one match now

The game never calls Runware. When a match log ends, this script picks the match's big moment (a
robot walkout, a lesson a robot learned, a robot-lit beacon, or just the result), asks Runware's
FLUX.1 [schnell] model for a comic panel of it, and saves the picture where the game's final screen
and the live report look for it. If it takes too long or fails, the final screen simply shows no panel.

What goes to Runware: a text description of the moment (names, the score and what happened). The key
stays in telemetry/local/runware.key (gitignored, readable by you only).
"""

import argparse
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "telemetry" / "local"
KEY = LOCAL / "runware.key"
SHOWN = LOCAL / "panels"
API = "https://api.runware.ai/v1"
MODEL = "runware:100@1"
NAMES = ["Nell", "Rafi", "Pip", "Morrow", "Zip"]

sys.path.insert(0, str(ROOT / "telemetry"))
import watch  # noqa: E402

STYLE = (
    "Single comic book panel, bold black ink outlines, halftone dots, bright sunset colors. "
    "A wooden dock court floating in a harbor on Saturn at dusk, the ringed planet huge in the sky, "
    "a carnival of floating islands, waterfalls and glowing jellyfish behind. Characters: three small "
    "cartoon dock robots, Pip (round, orange), Morrow (tall, sturdy, bronze) and Zip (slim, mint green), "
    "and two human dockhands, Nell (green work jacket) and Rafi (dark coat). A glowing star is the ball. "
)
NO_TEXT = "No text, no letters, no speech bubbles."


def generate(key, prompt, width=1024, height=576, timeout=20):
    task = {
        "taskType": "imageInference",
        "taskUUID": str(uuid.uuid4()),
        "model": MODEL,
        "positivePrompt": prompt,
        "width": width,
        "height": height,
        "numberResults": 1,
        "outputType": "URL",
        "outputFormat": "PNG",
    }
    request = urllib.request.Request(
        API,
        data=json.dumps([task]).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        reply = json.loads(response.read())
    rows = reply.get("data", reply) if isinstance(reply, dict) else reply
    found = next((r for r in rows if r.get("imageURL")), None)
    if not found:
        raise ValueError(f"Runware sent no image: {json.dumps(reply)[:300]}")
    with urllib.request.urlopen(found["imageURL"], timeout=timeout) as response:
        return response.read(), found.get("cost")


def configure(_args):
    LOCAL.mkdir(exist_ok=True)
    key = getpass.getpass("Runware API key (hidden): ").strip()
    if not key:
        sys.exit("No key entered.")
    descriptor = os.open(KEY, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as out:
        out.write(key)
    try:
        image, cost = generate(key, STYLE + "The five of them wave at the viewer. " + NO_TEXT, 512, 320)
    except (urllib.error.URLError, ValueError) as error:
        sys.exit(f"Runware did not accept the key: {error}")
    print(f"Runware works: a test panel of {len(image):,} bytes (cost {cost}).")


def moment(path):
    """The match's big moment in words, for the picture and for its caption."""
    goals, lessons, beacons, union, talks, mode = [0, 0], [], 0, False, [], ""
    with path.open() as f:
        head = json.loads(f.readline())
        mode = "Free Agents" if head.get("free_agents") else ("Open Crews" if head.get("open_crews") else "Rivals")
        for line in f:
            if '"seq"' not in line:
                continue
            e = json.loads(line)
            kind = e.get("kind")
            if kind == "goal":
                goals = [int(e.get("gold", 0)), int(e.get("blue", 0))]
            elif kind == "lesson":
                lessons.append((NAMES[e["seat"]], e.get("line", ""), int(e.get("thief", e.get("rival", 0)))))
            elif kind == "aurora":
                beacons += 1
            elif kind == "union":
                union = True
            elif kind == "talk":
                talks.append((NAMES[e["seat"]], e.get("line", "")))
    a, b = goals
    if union:
        scene = "the three robots walk off the court together, arms raised, as the harbor lights go dark behind them"
        caption = "The robots walked out and played the people as their own crew."
    elif lessons:
        robot, line, thief = lessons[-1]
        scene = f"{robot} the robot sidesteps {NAMES[thief]}'s lunging dash and flicks the glowing star to a teammate"
        caption = f"{robot} learned: {line}"
    elif mode == "Rivals" and a > b:
        scene = "Nell and Rafi celebrate a goal through a glowing ring while the three robots look on, stunned"
        caption = f"The people won {a} to {b}."
    elif mode == "Rivals":
        scene = "the three robots celebrate a goal through a glowing ring while Nell and Rafi catch their breath"
        caption = f"The robots won {b} to {a}." if b > a else f"A {a}-{b} draw."
    else:
        scene = "everyone dives for the glowing star in front of a ring as fireworks burst over the harbor"
        caption = f"{mode}: Gold {a}, Blue {b}."
    if beacons and not union:
        # A goal from a robot-only passing chain calls a glowing whale across the sky.
        scene += ", and a huge glowing whale swims across the sky above the court"
    if talks and not union:
        caption += f"  {talks[-1][0]} to the crew: {talks[-1][1]}"
    return STYLE + "Scene: " + scene + ". " + NO_TEXT, caption, mode, goals


def draw(path, key):
    prompt, caption, mode, goals = moment(path)
    started = time.monotonic()
    image, cost = generate(key, prompt)
    seconds = round(time.monotonic() - started, 1)
    run = path.stem
    targets = [watch.default_flights().parent / "panels", SHOWN]
    for folder in targets:
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{run}.png").write_bytes(image)
        (folder / f"{run}.json").write_text(json.dumps({"caption": caption}))
    (SHOWN / "latest.json").write_text(json.dumps({
        "run": run, "file": f"{run}.png", "caption": caption, "mode": mode, "goals": goals,
        "prompt": prompt, "seconds": seconds, "cost": cost, "model": MODEL,
    }))
    print(f"Panel for {run} in {seconds} s: {caption}", flush=True)


def ended(path):
    """Whether a match log has its final whistle."""
    with path.open("rb") as f:
        f.seek(max(0, path.stat().st_size - 4000))
        tail = f.read().decode("utf-8", "replace")
    return '"kind":"final"' in tail or '"kind":"footer"' in tail


def run(args):
    if not KEY.exists():
        sys.exit("Run `python3 telemetry/panels.py configure` first.")
    key = KEY.read_text().strip()
    folder = args.flights or watch.default_flights()
    done = {p.stem for p in (watch.default_flights().parent / "panels").glob("*.png")}
    # Matches that ended before this started are left alone.
    done |= {p.stem for p in folder.glob("*.jsonl") if ended(p)}
    print("Runware panels on.", flush=True)
    while True:
        for path in sorted(folder.glob("*.jsonl"), key=lambda p: p.stat().st_mtime)[-3:]:
            if path.stem in done or not ended(path):
                continue
            done.add(path.stem)
            try:
                draw(path, key)
            except (urllib.error.URLError, ValueError, OSError) as error:
                print(f"No panel for {path.stem}: {error}", file=sys.stderr, flush=True)
        time.sleep(1)


def main():
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    steps = cli.add_subparsers(dest="step", required=True)
    steps.add_parser("configure").set_defaults(go=configure)
    watcher = steps.add_parser("run")
    watcher.add_argument("--flights", type=Path, help="Watch this folder of match logs instead.")
    watcher.set_defaults(go=run)
    one = steps.add_parser("draw")
    one.add_argument("log", type=Path)
    one.set_defaults(go=lambda a: draw(a.log, KEY.read_text().strip()))
    args = cli.parse_args()
    args.go(args)


if __name__ == "__main__":
    main()
