"""Put Pip, Morrow and Zip in a BAND room: their warnings, tips, lessons and votes, live.

    python3 telemetry/band.py configure    once: each robot's BAND agent id and API key (hidden)
    python3 telemetry/band.py room         find the room again (after creating it or adding a robot)
    python3 telemetry/band.py run          bridge the live match into the room (dashboard.py starts it)

The game never talks to BAND. This bridge reads the match log the game is writing, and posts what a
robot says to its crewmates into the room as that robot, mentioning the robots it was said to.

While this bridge runs, the robots' warnings and tips really travel through the room. A robot says
something in the game; the bridge posts it to BAND as that robot; then it reads the room as each
robot the message was for, and when BAND shows that robot the message, it tells the game, and only
then does that robot act on it. If BAND takes more than five seconds, the robot takes the message
off the game's own harbor radio instead, so a slow network never breaks a match. The game knows the
bridge is running from band-bridge.alive in its data folder, which the bridge rewrites every two
seconds; without it, robots hear each other inside the game as before.

People in the room can also reach the robots by @mentioning one (nobody has to):
  - "watch Rafi" or "careful of Nell's dash": the robot gives that player more room in the game.
  - a move, such as "pass early", "go wide", "press", "guard the ring", "get ahead": the robot leans
    towards that move. It says so in the game and answers in the room, and tells you when it does it.
  - anything else is a question: the robot answers from the live match, with what it is doing and
    why, who has robbed it, what it has learned and what Coach Bruin told it.
What goes back to the game is appended to band-inbox.jsonl in the game's data folder; the game
picks it up within half a second and the court records it, so the match still replays exactly. Only
a message number, a warning or a move reaches the game, never anyone's own words.

What goes to BAND: those robot messages and answers. Keys stay in telemetry/local/band.json
(gitignored, readable by you only).
"""

import argparse
import getpass
import json
import os
import re
import signal
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


def save(config):
    descriptor = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as out:
        json.dump(config, out)


def configure(_args):
    LOCAL.mkdir(exist_ok=True)
    agents = {}
    for robot in ROBOTS:
        agent_id = input(f"{robot}'s BAND agent ID: ").strip()
        key = getpass.getpass(f"{robot}'s BAND API key (hidden): ").strip()
        if not agent_id or not key:
            sys.exit("Both the agent ID and the key are needed.")
        agents[robot] = {"id": agent_id, "key": key}
    base = None
    for candidate in BASES:
        try:
            call(candidate, agents["Pip"]["key"], "GET", "/chats")
            base = candidate
            break
        except (urllib.error.URLError, ValueError) as error:
            print(f"{candidate}: {error}")
    if base is None:
        sys.exit("BAND did not accept Pip's key.")
    # Keys are saved now, so finding the room can be tried again without typing them.
    save({"base": base, "chat_id": None, "room": None, "agents": agents})
    print("Keys saved.")
    find_room(None)


def find_room(_args):
    """Find the room Pip, Morrow and Zip share, learn their handles, and say hello there."""
    config = json.loads(CONFIG.read_text())
    agents = config["agents"]
    pip = agents["Pip"]["key"]
    rooms = call(config["base"], pip, "GET", "/chats?include=participants&page_size=50").get("data", [])
    print(f"Pip is in {len(rooms)} room(s): " + ", ".join(repr(r.get("title")) for r in rooms))
    ids = {a["id"] for a in agents.values()}
    shared = [r for r in rooms if ids <= {p.get("id") for p in r.get("participants", [])}]
    named = [r for r in shared or rooms if "last light" in (r.get("title") or "").lower()]
    room = (named or shared or rooms or [None])[0]
    if room is None:
        sys.exit(
            "Pip is in no room yet. In BAND: Rooms, then +, select Pip, Morrow and Zip, create the room, "
            "then run: python3 telemetry/band.py room"
        )
    people = call(config["base"], pip, "GET", f"/chats/{room['id']}/participants").get("data", [])
    handles = {p["id"]: p.get("handle") for p in people}
    missing = [robot for robot, agent in agents.items() if agent["id"] not in handles]
    if missing:
        sys.exit(
            f"Add {', '.join(missing)} to the room '{room.get('title')}' (Participants, then Add "
            "participants), then run: python3 telemetry/band.py room"
        )
    for agent in agents.values():
        agent["handle"] = handles.get(agent["id"])
    config.update({"chat_id": room["id"], "room": room.get("title")})
    save(config)
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
        return None
    content = (" ".join(tags) + " " + line).strip()
    body = {"message": {"content": content, "mentions": mentions}}
    try:
        reply = call(config["base"], agents[speaker]["key"], "POST", f"/chats/{config['chat_id']}/messages", body)
    except (urllib.error.URLError, ValueError) as error:
        print(f"BAND post from {speaker} failed: {error}", file=sys.stderr, flush=True)
        return None
    # The posted message, as BAND describes it (its id is used to recognise it when a listener sees it).
    sent = reply.get("data", reply) if isinstance(reply, dict) else {}
    return sent if isinstance(sent, dict) else {}


ASKED = {
    "press": "press the carrier", "screen": "guard the ring", "cut": "cut the passing lane",
    "recover": "chase the star", "lead": "read where the star lands",
    "outlet": "stay close for a pass", "advance": "get ahead",
    "drive": "go straight at the ring", "flank": "take the wide lane", "pass": "pass early",
    "finish": "shoot", "evade": "keep my distance",
}
WARNING = re.compile(r"\b(watch|careful|beware|mind|avoid|look out|away from|dash|rob|robs|steal|steals)\b")
NOT = re.compile(r"\b(don'?t|do not|stop|never|not|no more)\b")
# Checked in order: the first that matches wins.
MOVES = [
    (r"\b(cut|lane|intercept)", "defend", "cut"),
    (r"\b(press|pressure|close (him|her|them) down)", "defend", "press"),
    (r"\b(screen|guard|protect|hold the ring|stay back)", "defend", "screen"),
    (r"\bpass", "carry", "pass"),
    (r"\b(wide|flank|outside)", "carry", "flank"),
    (r"\b(straight|drive|charge|go for the ring)", "carry", "drive"),
    (r"\b(dodge|evade|keep your distance|run away)", "carry", "evade"),
    (r"\b(shoot|finish|score)", "carry", "finish"),
    (r"\b(lead|where it lands|read the star)", "loose", "lead"),
    (r"\b(chase|recover|get the star|loose)", "loose", "recover"),
    (r"\b(advance|get ahead|go forward|up the court)", "support", "advance"),
    (r"\b(outlet|stay close|support|come back)", "support", "outlet"),
]


def understand(text):
    """Turn a person's message into a note for the game, or None when it is just a question."""
    words = re.sub(r"@\[\[[^\]]*\]\]|@[\w./-]+", " ", text.lower())
    for about, name in enumerate(("nell", "rafi")):
        if re.search(rf"\b{name}\b", words) and WARNING.search(words):
            return {"topic": "warn", "about": about}
    if words.rstrip().endswith("?") or NOT.search(words):
        # A question, or "don't pass": not something to hand the game as a move to favour.
        return None
    for pattern, phase, move in MOVES:
        if re.search(pattern, words):
            return {"topic": "tip", "phase": phase, "try": move}
    return None


def first_name(name):
    letters = re.sub(r"[^A-Za-z]", "", (name or "").split(" ")[0])
    return letters[:12] or "Someone"


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


def said(config, match, event, state=None):
    """Post an event to the room if it is something a robot says to other robots."""
    seat = event.get("seat", -1)
    if not 2 <= seat <= 4:
        return
    robot = NAMES[seat]
    crew = [r for r in ROBOTS if r != robot]
    kind = event.get("kind")
    if kind == "talk":
        listeners = [NAMES[int(k)] for k in event.get("to", []) if 2 <= int(k) <= 4]
        sent = post(config, robot, listeners, event.get("line", ""))
        if state is not None and sent is not None and event.get("via") == "band":
            # The listeners act on this in the game only once BAND shows it to them.
            state["relay"].append({
                "msg": int(event["msg"]), "speaker": config["agents"][robot]["id"],
                "line": event.get("line", ""), "band_id": sent.get("id"),
                "waiting": set(listeners), "since": time.monotonic(),
            })
    elif kind == "lesson":
        post(config, robot, crew, "Lesson: " + event.get("line", ""))
    elif kind == "coach_note":
        post(config, robot, crew, "Coach Bruin's note for me: " + event.get("advice", ""))
    elif kind in ("union_call", "union", "protest") and event.get("reason"):
        post(config, robot, crew, event["reason"])


def answer_people(config, match, answered, state, reply=True):
    """Handle people who @mention a robot in the room. A warning or a move goes to the game's inbox;
    anything else is answered from what the robot is doing now. With reply=False the messages
    already there are only marked as seen."""
    for robot in ROBOTS:
        agent = config["agents"][robot]
        try:
            waiting = call(
                config["base"], agent["key"], "GET",
                f"/chats/{config['chat_id']}/messages?status=all&sort_order=desc&limit=20",
            ).get("data", [])
        except (urllib.error.URLError, ValueError):
            continue
        for message in reversed(waiting):
            # One message can mention two robots; each takes it once.
            mine = f"{robot}:{message['id']}"
            if message.get("sender_type") != "User" or mine in answered or message["id"] in answered:
                continue
            answered.add(mine)
            if not reply:
                continue
            note = understand(message.get("content") or "")
            if note is None:
                post(config, robot, [], match.answer(robot), people=[message["sender_id"]])
                continue
            note.update({
                "seat": NAMES.index(robot), "who": first_name(message.get("sender_name")),
                "ref": str(message["id"]),
            })
            with state["inbox"].open("a") as inbox:
                inbox.write(json.dumps(note) + "\n")
            state["waiting"][mine] = (message["sender_id"], time.monotonic())
            state["senders"][mine] = message["sender_id"]
    ANSWERED.write_text(json.dumps(sorted(answered)))


def confirm(config, state, event):
    """Tell the person in the room what the game did with their message."""
    seat = event.get("seat", -1)
    if not 2 <= seat <= 4:
        return
    robot = NAMES[seat]
    mine = f"{robot}:{event.get('ref', '')}"
    sender = state["senders"].get(mine)
    if not sender:
        return
    if event.get("kind") == "band_note":
        state["waiting"].pop(mine, None)
        if event.get("topic") == "warn":
            line = f"Got it. Giving {NAMES[int(event['about'])]} more room."
        else:
            line = f"Got it. I'll {ASKED[event['try']]} when I can."
    else:
        line = f"Doing what you asked now: {ASKED[event['try']]}."
    post(config, robot, [], line, people=[sender])


def read_room(config, robot, limit=20):
    """The newest messages BAND shows this robot, oldest first."""
    agent = config["agents"][robot]
    rows = call(
        config["base"], agent["key"], "GET",
        f"/chats/{config['chat_id']}/messages?status=all&sort_order=desc&limit={limit}",
    ).get("data", [])
    return list(reversed(rows))


def carry_back(config, state):
    """For each robot still waiting on a crewmate's message, read the room as that robot. When BAND
    shows it the message, tell the game, which lets that robot act on it."""
    state["relay"] = [m for m in state["relay"] if m["waiting"] and time.monotonic() - m["since"] < 10]
    for robot in ROBOTS:
        if not any(robot in m["waiting"] for m in state["relay"]):
            continue
        try:
            rows = read_room(config, robot)
        except (urllib.error.URLError, ValueError):
            continue
        for row in rows:
            seen = (robot, row.get("id"))
            if row.get("sender_type") != "Agent" or seen in state["heard"]:
                continue
            state["heard"].add(seen)
            for sent in state["relay"]:
                if robot not in sent["waiting"]:
                    continue
                if sent["band_id"]:
                    match = row.get("id") == sent["band_id"]
                else:
                    match = row.get("sender_id") == sent["speaker"] and (row.get("content") or "").endswith(sent["line"])
                if match:
                    sent["waiting"].discard(robot)
                    note = {"topic": "relay", "seat": NAMES.index(robot), "msg": sent["msg"], "ref": str(row.get("id"))}
                    with state["inbox"].open("a") as inbox:
                        inbox.write(json.dumps(note) + "\n")
                    break


def give_up(config, state):
    """A message the game has not taken within six seconds was sent outside a match."""
    for mine, (sender, since) in list(state["waiting"].items()):
        if time.monotonic() - since > 6:
            del state["waiting"][mine]
            robot = mine.split(":")[0]
            post(config, robot, [], "I'm not in a match right now. Tell me again after kickoff.", people=[sender])


def run(args):
    if not CONFIG.exists():
        sys.exit("Run `python3 telemetry/band.py configure` first.")
    config = json.loads(CONFIG.read_text())
    if not config.get("chat_id"):
        sys.exit("No BAND room yet: run `python3 telemetry/band.py room`.")
    answered = set(json.loads(ANSWERED.read_text())) if ANSWERED.exists() else set()
    # Questions asked before the bridge started are not answered again.
    state = {
        "inbox": args.inbox or watch.default_flights().parent / "band-inbox.jsonl",
        "waiting": {},
        "senders": {},
        "relay": [],
        "heard": set(),
    }
    state["inbox"].parent.mkdir(parents=True, exist_ok=True)
    if not ANSWERED.exists():
        answer_people(config, Match(), answered, state, reply=False)
    for robot in ROBOTS:
        # What is in the room already is not a delivery of anything said from now on.
        try:
            state["heard"] |= {(robot, row.get("id")) for row in read_room(config, robot)}
        except (urllib.error.URLError, ValueError):
            pass
    # The game looks at this file to know the bridge is running, and then sends robot talk through BAND.
    alive = state["inbox"].parent / "band-bridge.alive"
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        follow(config, args, state, answered, alive)
    finally:
        alive.unlink(missing_ok=True)


def follow(config, args, state, answered, alive):
    """Follow the newest match log for as long as the bridge runs."""
    folder = args.flights or watch.default_flights()
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
    last_poll, last_beat = 0., 0.
    while True:
        if time.monotonic() - last_beat > 2:
            last_beat = time.monotonic()
            alive.write_text(str(time.time()))
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
                    said(config, match, event, state)
                    if event.get("kind") in ("band_note", "band_heed"):
                        confirm(config, state, event)
        if state["relay"]:
            carry_back(config, state)
        if time.monotonic() - last_poll > 3:
            last_poll = time.monotonic()
            answer_people(config, match, answered, state)
            give_up(config, state)
        time.sleep(.25)


def main():
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    steps = cli.add_subparsers(dest="step", required=True)
    steps.add_parser("configure").set_defaults(go=configure)
    steps.add_parser("room").set_defaults(go=find_room)
    bridge = steps.add_parser("run")
    bridge.add_argument("--flights", type=Path, help="Watch this folder of match logs instead.")
    bridge.add_argument("--inbox", type=Path, help="Write messages for the game to this file instead.")
    bridge.set_defaults(go=run)
    args = cli.parse_args()
    args.go(args)


if __name__ == "__main__":
    main()
