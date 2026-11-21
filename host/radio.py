"""Last Light's fixed-purpose Gemini service. Only the host holds the provider credential."""

import argparse
import getpass
import json
import math
import os
import re
import tempfile
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

MODEL = "gemini-3.1-flash-lite"
GOOGLE = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
)
ROBOTS = ("Pip", "Morrow", "Zip")
NAMES = ("Nell", "Rafi") + ROBOTS
PERSONAS = (
    "Pip is an opportunistic ball thief and values teammates who pass back.",
    "Morrow is a patient keeper who studies shooting lanes and helps underdogs.",
    "Zip is a fast courier who wants open space and reliable passing partners.",
)
MOVES = {
    "defend": ["press", "screen", "cut"],
    "support": ["advance", "outlet"],
    "carry": ["drive", "flank", "pass", "finish"],
    "loose": ["lead", "recover"],
}
TACTICS = {move for options in MOVES.values() for move in options}
KEY_PATH = Path.home() / "Library/Application Support/Last Light Host/gemini.key"
PATH = "/v1/playbook"


def position(value):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError("invalid position")
    return [number(v, -20, 20) for v in value]


def number(value, minimum, maximum):
    if (
        type(value) not in (int, float)
        or not math.isfinite(value)
        or not minimum <= value <= maximum
    ):
        raise ValueError("invalid number")
    return round(value, 2)


def member(value, options):
    if value not in options:
        raise ValueError("unknown game value")
    return value


def rows(value, length, exact=False):
    if (
        not isinstance(value, list)
        or len(value) > length
        or (exact and len(value) != length)
    ):
        raise ValueError("invalid row count")
    return value


def scout(raw):
    """Only game facts, numbers and known action names can reach the publisher's prompt."""
    name = member(raw["name"], ROBOTS)
    neighbors = [
        {
            "name": member(row["name"], NAMES),
            "team": number(row["team"], 0, 1),
            "position": position(row["position"]),
        }
        for row in rows(raw["nearby"], 4)
    ]
    tendencies = []
    for row in rows(raw["scouting_shots_passes_lane"], 2, exact=True):
        shots, passes, lane = rows(row, 3, exact=True)
        tendencies.append(
            [number(shots, 0, 6000), number(passes, 0, 6000), number(lane, -10, 10)]
        )
    memory = []
    for row in rows(raw["last_four_plays"], 4):
        memory.append(
            {
                "move": member(row["move"], TACTICS),
                "phase": member(row["phase"], MOVES),
                "holder_after": member(row["holder_after"], (*NAMES, "loose")),
                **{
                    key: row[key] is True
                    for key in (
                        "scored",
                        "won_possession",
                        "lost_possession",
                        "completed_pass",
                    )
                },
            }
        )
    return {
        "name": name,
        "team": number(raw["team"], 0, 1),
        "position": position(raw["position"]),
        "blue_goals": number(raw["blue_goals"], 0, 3),
        "gold_goals": number(raw["gold_goals"], 0, 3),
        "star_holder": member(raw["star_holder"], (*NAMES, "loose")),
        "nearby": neighbors,
        "nell_rafi_shots_passes_lane": tendencies,
        "nell_rafi_trust": [
            number(x, -2, 3)
            for x in rows(raw["relationships"]["reputation"], 2, exact=True)
        ],
        "learned_tactic": member(raw["learned_tactic"], TACTICS | {""}),
        "recent": memory,
    }


def payload(seen):
    prompt = (
        PERSONAS[ROBOTS.index(seen["name"])]
        + " Play orbital courtball. Gold (0) attacks right, Blue (1) left. "
        "Choose one move for each phase based on your scout report. Press challenges the carrier, screen guards "
        "the ring, cut covers a passing lane. Lead predicts a loose ball, recover chases it, outlet offers a pass. "
        "Give one short public tactical reason for each move, at most 100 characters."
    )
    phases = {
        phase: {
            "type": "object",
            "properties": {
                "move": {"type": "string", "enum": moves},
                "reason": {"type": "string"},
            },
            "required": ["move", "reason"],
        }
        for phase, moves in MOVES.items()
    }
    return {
        "systemInstruction": {"parts": [{"text": prompt}]},
        "contents": [
            {
                "role": "user",
                "parts": [{"text": json.dumps(seen, separators=(",", ":"))}],
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "maxOutputTokens": 600,
            "thinkingConfig": {"thinkingLevel": "MINIMAL"},
            "responseJsonSchema": {
                "type": "object",
                "properties": phases,
                "required": list(MOVES),
            },
        },
    }


def google_plan(key, seen):
    data = json.dumps(payload(seen)).encode()
    req = Request(
        GOOGLE,
        data=data,
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    with urlopen(req, timeout=4.5) as response:
        result = json.loads(response.read(65537))
    candidate = result["candidates"][0]
    if candidate.get("finishReason") != "STOP":
        raise ValueError("incomplete playbook")
    value = json.loads(
        "".join(
            p.get("text", "")
            for p in candidate["content"]["parts"]
            if not p.get("thought")
        )
    )
    plan = {}
    for phase, options in MOVES.items():
        entry = value[phase]
        reason = entry["reason"]
        if not isinstance(reason, str) or not 0 < len(reason.strip()) <= 160:
            raise ValueError("invalid public reason")
        plan[phase] = {
            "move": member(entry["move"], options),
            "reason": " ".join(reason.split()),
        }
    usage = result.get("usageMetadata", {})
    return {
        "plan": plan,
        "model_version": str(result.get("modelVersion", MODEL))[:100],
        "input_tokens": int(usage.get("promptTokenCount", 0)),
        "output_tokens": int(usage.get("candidatesTokenCount", 0)),
        "total_tokens": int(usage.get("totalTokenCount", 0)),
    }


class Radio(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, generate):
        super().__init__(address, Handler)
        self.generate = generate
        self.calls = deque()
        self.budget_lock = threading.Lock()
        self.slots = threading.BoundedSemaphore(6)

    def admit(self):
        now = time.monotonic()
        with self.budget_lock:
            while self.calls and self.calls[0] <= now - 3600:
                self.calls.popleft()
            if len(self.calls) >= 900 or (
                len(self.calls) >= 72 and self.calls[-72] > now - 60
            ):
                return False
            self.calls.append(now)
            return True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(6)

    def reply(self, status, result):
        body = json.dumps(result, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_POST(self):
        if self.path != PATH:
            return self.reply(404, {})
        if self.headers.get_content_type() != "application/json":
            return self.reply(415, {})
        try:
            length = int(self.headers.get("Content-Length", 0))
            if not 0 < length <= 8192:
                return self.reply(413, {})
            seen = scout(json.loads(self.rfile.read(length)))
        except (ValueError, KeyError, TypeError, IndexError, RecursionError, OSError):
            return self.reply(400, {})
        if not self.server.slots.acquire(blocking=False):
            return self.reply(429, {})
        try:
            if not self.server.admit():
                return self.reply(429, {})
            result = self.server.generate(seen)
        except HTTPError as error:
            return self.reply(
                error.code if error.code in (401, 403, 404, 429) else 502, {}
            )
        except TimeoutError:
            return self.reply(504, {})
        except (URLError, ValueError, TypeError, KeyError, IndexError, OSError):
            return self.reply(502, {})
        finally:
            self.server.slots.release()
        self.reply(200, result)


def configure():
    key = getpass.getpass("Publisher's Gemini key (hidden): ").strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{16,512}", key):
        raise SystemExit("Enter a valid Gemini key.")
    KEY_PATH.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile("w", dir=KEY_PATH.parent, delete=False) as temp:
        temp.write(key)
    os.replace(temp.name, KEY_PATH)
    print("Host configured. Start Last Light normally.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--configure", action="store_true")
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", "8947")))
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--ready", type=Path)
    parser.add_argument("--parent", type=int)
    args = parser.parse_args()
    if args.configure:
        configure()
        return
    key = (
        os.getenv("GEMINI_API_KEY")
        or os.getenv("GOOGLE_API_KEY")
        or (KEY_PATH.read_text().strip() if KEY_PATH.exists() else "")
    )
    if not key:
        raise SystemExit("Publisher credential is missing.")
    with Radio((args.bind, args.port), lambda seen: google_plan(key, seen)) as radio:
        if args.ready:
            temp = args.ready.with_suffix(".next")
            temp.write_text(str(radio.server_port))
            temp.replace(args.ready)
        if args.parent:
            radio.timeout = 0.5
            while os.getppid() == args.parent:
                radio.handle_request()
        else:
            radio.serve_forever()


if __name__ == "__main__":
    main()
