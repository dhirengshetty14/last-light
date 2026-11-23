"""Put Pip, Morrow and Zip in a BAND room: their warnings, tips, lessons and votes, live.

    python3 telemetry/band.py configure    once: each robot's BAND agent id and API key (hidden)
    python3 telemetry/band.py run          bridge the live match into the room (dashboard.py starts it)

The game never talks to BAND. This bridge reads the match log the game is writing, and posts what a
robot says to its crewmates into the room as that robot, mentioning the robots it was said to. People
in the room can ask a robot something by @mentioning it; the robot answers from the live match: what
it is doing and why, who has robbed it, what it has learned and what Coach Bruin told it.

What goes to BAND: those robot messages and answers. Keys stay in telemetry/local/band.json
(gitignored, readable by you only).
"""

import argparse
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "telemetry" / "local"
CONFIG = LOCAL / "band.json"
ANSWERED = LOCAL / "band-answered.json"
ROBOTS = ["Pip", "Morrow", "Zip"]
NAMES = ["Nell", "Rafi", "Pip", "Morrow", "Zip"]
BASES = ["https://app.band.ai/api/v1/agent", "https://api.band.ai/api/v1/agent"]

sys.path.insert(0, str(ROOT / "telemetry"))
import watch  # noqa: E402


def call(base, key, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        base + path,
        data=data,
        method=method,
        headers={"X-API-Key": key, "Content-Type": "application/json", "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


def configure(_args):
    LOCAL.mkdir(exist_ok=True)
    agents = {}
    for robot in ROBOTS:
        agent_id = input(f"{robot}'s BAND agent ID: ").strip()
        key = getpass.getpass(f"{robot}'s BAND API key (hidden): ").strip()
        if not agent_id or not key:
            sys.exit("Both the agent ID and the key are needed.")
        agents[robot] = {"id": agent_id, "key": key}
    pip = agents["Pip"]["key"]
    base, rooms = None, []
    for candidate in BASES:
        try:
            rooms = call(candidate, pip, "GET", "/chats?include=participants").get("data", [])
            base = candidate
            break
        except (urllib.error.URLError, ValueError) as error:
            print(f"{candidate}: {error}")
    if base is None:
        sys.exit("BAND did not accept Pip's key.")
    ids = {a["id"] for a in agents.values()}
    rooms = [r for r in rooms if ids <= {p.get("id") for p in r.get("participants", [])}] or rooms
    named = [r for r in rooms if "last light" in (r.get("title") or "").lower()]
    room = (named or rooms or [None])[0]
    if room is None:
        sys.exit("Pip is in no room yet. Create a room with Pip, Morrow and Zip, then run this again.")
    people = call(base, pip, "GET", f"/chats/{room['id']}/participants").get("data", [])
    handles = {p["id"]: p.get("handle") for p in people}
    for robot, agent in agents.items():
        agent["handle"] = handles.get(agent["id"])
    missing = [robot for robot, agent in agents.items() if agent["id"] not in handles]
    if missing:
        sys.exit(f"Add {', '.join(missing)} to the room '{room.get('title')}', then run this again.")
    descriptor = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as out:
        json.dump({"base": base, "chat_id": room["id"], "room": room.get("title"), "agents": agents}, out)
    config = json.loads(CONFIG.read_text())
    post(config, "Pip", ["Morrow", "Zip"], "Harbor radio is on. I'll call out who robs us.")
    print(f"BAND is set up: room '{room.get('title')}'. Pip just said hello there.")


def post(config, speaker, listeners, line, people=()):
    """Post a line as one robot, mentioning the robots (and people) it is for."""
    agents = config["agents"]
    mentions, tags = [], []
    for robot in listeners:
        if robot in agents and robot != speaker:
            agent = agents[robot]
            mention = {"id": agent["id"]}
            if agent.get("handle"):
                mention["handle"] = agent["handle"]
                tags.append("@" + agent["handle"])
            mentions.append(mention)
    for person in people:
        mentions.append({"id": person})
    if not mentions:
        return
    content = (" ".join(tags) + " " + line).strip()
    body = {"message": {"content": content, "mentions": mentions}}
    try:
        call(config["base"], agents[speaker]["key"], "POST", f"/chats/{config['chat_id']}/messages", body)
    except (urllib.error.URLError, ValueError) as error:
        print(f"BAND post from {speaker} failed: {error}", file=sys.stderr, flush=True)


class Match:
    """What each robot has done and said in the live match, for answering questions."""

    def __init__(self):
        self.reason = {r: "Watching the opening play." for r in ROBOTS}
        self.robbed = {r: [0, 0] for r in ROBOTS}
        self.lessons = {r: [] for r in ROBOTS}
        self.coach = {r: "" for r in ROBOTS}
        self.score = [0, 0]
        self.mode = ""

    def read(self, event):
        seat = event.get("seat", -1)
        robot = NAMES[seat] if 2 <= seat <= 4 else None
        kind = event.get("kind")
        if kind == "response_intent" and robot:
            self.reason[robot] = event.get("reason", self.reason[robot])
        elif kind == "robbed" and robot and int(event.get("by", -1)) in (0, 1):
            self.robbed[robot][int(event["by"])] += 1
        elif kind == "lesson" and robot:
            self.lessons[robot].append(event.get("line", ""))
        elif kind == "coach_note" and robot:
            self.coach[robot] = event.get("advice", "")
        elif kind == "goal":
            self.score = [int(event.get("gold", 0)), int(event.get("blue", 0))]

    def answer(self, robot):
        nell, rafi = self.robbed[robot]
        parts = [f"Right now: {self.reason[robot]}"]
        parts.append(f"Score {self.score[0]}-{self.score[1]}. Nell has robbed me {nell} times, Rafi {rafi}.")
        if self.lessons[robot]:
            parts.append("What I learned: " + self.lessons[robot][-1])
        if self.coach[robot]:
            parts.append("Coach Bruin told me: " + self.coach[robot])
        return " ".join(parts)


def said(config, match, event):
    """Post an event to the room if it is something a robot says to other robots."""
    seat = event.get("seat", -1)
    if not 2 <= seat <= 4:
        return
    robot = NAMES[seat]
    crew = [r for r in ROBOTS if r != robot]
    kind = event.get("kind")
    if kind == "talk":
        listeners = [NAMES[int(k)] for k in event.get("to", []) if 2 <= int(k) <= 4]
        post(config, robot, listeners, event.get("line", ""))
    elif kind == "lesson":
        post(config, robot, crew, "Lesson: " + event.get("line", ""))
    elif kind == "coach_note":
        post(config, robot, crew, "Coach Bruin's note for me: " + event.get("advice", ""))
    elif kind in ("union_call", "union", "protest") and event.get("reason"):
        post(config, robot, crew, event["reason"])


def answer_people(config, match, answered):
    """Reply to people who @mention a robot in the room, from what the robot is doing now."""
    for robot in ROBOTS:
        agent = config["agents"][robot]
        try:
            waiting = call(
                config["base"], agent["key"], "GET",
                f"/chats/{config['chat_id']}/messages?status=all&sort_order=desc&limit=20",
            ).get("data", [])
        except (urllib.error.URLError, ValueError):
            continue
        for message in waiting:
            if message.get("sender_type") != "User" or message["id"] in answered:
                continue
            answered.add(message["id"])
            post(config, robot, [], match.answer(robot), people=[message["sender_id"]])
    ANSWERED.write_text(json.dumps(sorted(answered)))


def run(args):
    if not CONFIG.exists():
        sys.exit("Run `python3 telemetry/band.py configure` first.")
    config = json.loads(CONFIG.read_text())
    answered = set(json.loads(ANSWERED.read_text())) if ANSWERED.exists() else set()
    folder = args.flights or watch.default_flights()
    # Questions asked before the bridge started are not answered again.
    if not ANSWERED.exists():
        match = Match()
        answer_people(config, match, answered)
    current, offset, match = None, 0, Match()
    newest = max(folder.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, default=None)
    if newest is not None:
        # Join a match already being played without replaying what was said before.
        current, offset = newest, newest.stat().st_size
        with newest.open() as f:
            for line in f:
                if line.endswith("\n") and '"seq"' in line:
                    match.read(json.loads(line))
    print(f"BAND bridge on: room '{config.get('room')}'", flush=True)
    last_poll = 0.
    while True:
        newest = max(folder.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, default=None)
        if newest is not None and newest != current:
            current, offset, match = newest, 0, Match()
        if current is not None and current.stat().st_size > offset:
            with current.open() as f:
                f.seek(offset)
                for line in f:
                    if not line.endswith("\n"):
                        break
                    offset += len(line.encode())
                    if '"seq"' not in line:
                        continue
                    event = json.loads(line)
                    match.read(event)
                    said(config, match, event)
        if time.monotonic() - last_poll > 4:
            last_poll = time.monotonic()
            answer_people(config, match, answered)
        time.sleep(1)


def main():
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    steps = cli.add_subparsers(dest="step", required=True)
    steps.add_parser("configure").set_defaults(go=configure)
    bridge = steps.add_parser("run")
    bridge.add_argument("--flights", type=Path, help="Watch this folder of match logs instead.")
    bridge.set_defaults(go=run)
    args = cli.parse_args()
    args.go(args)


if __name__ == "__main__":
    main()
