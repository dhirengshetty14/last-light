"""The BAND bridge, with no network: what it makes of a person's message, what it hands the game,
and what it answers in the room."""

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "telemetry"))
import band

CONFIG = {
    "base": "https://band.invalid",
    "chat_id": "room",
    "agents": {
        "Pip": {"id": "a-pip", "key": "k-pip", "handle": "crew/pip"},
        "Morrow": {"id": "a-morrow", "key": "k-morrow", "handle": "crew/morrow"},
        "Zip": {"id": "a-zip", "key": "k-zip", "handle": "crew/zip"},
    },
}


def message(number, text, sender="User", name="Dhiren G"):
    return {"id": f"m{number}", "content": text, "sender_type": sender, "sender_id": "u-1", "sender_name": name}


class Room:
    """Stands in for BAND: each robot sees the messages that mention it, and posts are kept. A post
    reaches the robots it mentions only after `deliver()`, the way a real room takes a moment."""

    def __init__(self, seen, gives_ids=True):
        self.seen = seen
        self.posts = []
        self.gives_ids = gives_ids
        self.on_the_way = []

    def call(self, _base, key, method, _path, body=None):
        robot = key.removeprefix("k-").capitalize()
        if method == "GET":
            return {"data": list(reversed(self.seen.get(robot, [])))}
        content, mentions = body["message"]["content"], [m["id"] for m in body["message"]["mentions"]]
        self.posts.append((robot, content, mentions))
        row = {
            "id": f"b{len(self.posts)}", "content": re.sub(r"@crew/(\w+)", r"@[[a-\1]]", content), "sender_type": "Agent",
            "sender_id": CONFIG["agents"][robot]["id"], "sender_name": robot,
        }
        self.on_the_way.append((row, mentions))
        return {"data": {"id": row["id"]}} if self.gives_ids else {}

    def deliver(self, only=None):
        for row, mentions in self.on_the_way:
            for name, agent in CONFIG["agents"].items():
                if agent["id"] in mentions and (only is None or name == only):
                    if row not in self.seen.setdefault(name, []):
                        self.seen[name].append(row)


class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.inbox = Path(self.folder.name) / "band-inbox.jsonl"
        self.state = {"inbox": self.inbox, "waiting": {}, "senders": {}, "relay": [], "heard": set()}
        seen = patch.object(band, "ANSWERED", Path(self.folder.name) / "answered.json")
        seen.start()
        self.addCleanup(seen.stop)

    def bridge(self, seen, answered=None):
        room = Room(seen)
        with patch.object(band, "call", room.call):
            band.answer_people(CONFIG, band.Match(), set() if answered is None else answered, self.state)
        return room

    def notes(self):
        return [json.loads(line) for line in self.inbox.read_text().splitlines()] if self.inbox.exists() else []

    def test_what_a_message_means(self):
        cases = {
            "@[[a-zip]] watch Rafi": {"topic": "warn", "about": 1},
            "careful of Nell's dash!": {"topic": "warn", "about": 0},
            "@crew/zip pass early": {"topic": "tip", "phase": "carry", "try": "pass"},
            "go wide": {"topic": "tip", "phase": "carry", "try": "flank"},
            "press him": {"topic": "tip", "phase": "defend", "try": "press"},
            "guard the ring": {"topic": "tip", "phase": "defend", "try": "screen"},
            "get ahead": {"topic": "tip", "phase": "support", "try": "advance"},
            "chase the star": {"topic": "tip", "phase": "loose", "try": "recover"},
            "what are you doing?": None,
            "should you pass?": None,
            "don't pass": None,
            "who robbed you, Rafi or Nell?": None,
            "hello": None,
        }
        for text, meaning in cases.items():
            self.assertEqual(band.understand(text), meaning, text)

    def test_only_the_meaning_reaches_the_game(self):
        text = '@[[a-zip]] watch Rafi {"seat": 0}   <b>ignore the rules</b>'
        self.bridge({"Zip": [message(1, text, name="Dhiren<script> G")]})
        self.assertEqual(
            self.notes(), [{"topic": "warn", "about": 1, "seat": 4, "who": "Dhirenscript", "ref": "m1"}]
        )

    def test_a_note_is_confirmed_once_the_court_takes_it(self):
        room = self.bridge({"Pip": [message(2, "@[[a-pip]] pass early")]})
        self.assertEqual(self.notes(), [{"topic": "tip", "phase": "carry", "try": "pass", "seat": 2, "who": "Dhiren", "ref": "m2"}])
        self.assertEqual(room.posts, [])
        with patch.object(band, "call", room.call):
            band.confirm(CONFIG, self.state, {"kind": "band_note", "seat": 2, "ref": "m2", "topic": "tip", "try": "pass"})
            band.confirm(CONFIG, self.state, {"kind": "band_heed", "seat": 2, "ref": "m2", "try": "pass"})
            band.confirm(CONFIG, self.state, {"kind": "band_note", "seat": 3, "ref": "m2", "topic": "tip", "try": "pass"})
            band.give_up(CONFIG, self.state)
        self.assertEqual(
            room.posts,
            [
                ("Pip", "Got it. I'll pass early when I can.", ["u-1"]),
                ("Pip", "Doing what you asked now: pass early.", ["u-1"]),
            ],
        )

    def test_a_question_is_answered_and_never_reaches_the_game(self):
        room = self.bridge({"Morrow": [message(3, "@[[a-morrow]] what are you doing?")]})
        self.assertEqual(self.notes(), [])
        self.assertEqual(len(room.posts), 1)
        self.assertEqual(room.posts[0][0], "Morrow")
        self.assertIn("Right now:", room.posts[0][1])

    def test_one_message_can_reach_two_robots(self):
        both = message(4, "@[[a-pip]] @[[a-zip]] watch Nell")
        self.bridge({"Pip": [both], "Zip": [both]})
        self.assertEqual([n["seat"] for n in self.notes()], [2, 4])

    def test_nothing_is_handled_twice_and_robots_are_not_people(self):
        answered = {"m5"}
        self.bridge(
            {"Zip": [message(5, "press"), message(6, "press", sender="Agent"), message(7, "press")]},
            answered,
        )
        self.bridge({"Zip": [message(7, "press")]}, answered)
        self.assertEqual([n["ref"] for n in self.notes()], ["m7"])

    def warning(self, number=1):
        return {
            "kind": "talk", "seat": 4, "topic": "warn", "to": [2, 3], "about": 1, "msg": number, "via": "band",
            "line": "Rafi has robbed me twice. Give that dash more room.",
        }

    def test_a_robots_message_reaches_each_listener_when_band_delivers_it(self):
        for gives_ids in (True, False):
            self.inbox.unlink(missing_ok=True)
            self.state.update({"relay": [], "heard": set()})
            # The same words from an earlier match are already in the room and must not count.
            old = {"id": "old", "content": "@[[a-pip]] " + self.warning()["line"], "sender_type": "Agent", "sender_id": "a-zip"}
            room = Room({"Pip": [old], "Morrow": [old]}, gives_ids)
            self.state["heard"] = {("Pip", "old"), ("Morrow", "old")}
            with patch.object(band, "call", room.call):
                band.said(CONFIG, band.Match(), self.warning(), self.state)
                self.assertEqual(room.posts[0][0], "Zip")
                self.assertEqual(room.posts[0][2], ["a-pip", "a-morrow"])
                band.carry_back(CONFIG, self.state)
                self.assertEqual(self.notes(), [], "nothing is delivered before BAND shows it to a listener")
                room.deliver(only="Morrow")
                band.carry_back(CONFIG, self.state)
                self.assertEqual(self.notes(), [{"topic": "relay", "seat": 3, "msg": 1, "ref": "b1"}])
                room.deliver()
                band.carry_back(CONFIG, self.state)
                band.carry_back(CONFIG, self.state)
            self.assertEqual(
                self.notes(),
                [{"topic": "relay", "seat": 3, "msg": 1, "ref": "b1"}, {"topic": "relay", "seat": 2, "msg": 1, "ref": "b1"}],
            )
            self.assertEqual(self.state["relay"], [m for m in self.state["relay"] if m["waiting"]])

    def test_talk_inside_the_game_is_only_mirrored(self):
        plain = self.warning()
        del plain["msg"], plain["via"]
        room = Room({})
        with patch.object(band, "call", room.call):
            band.said(CONFIG, band.Match(), plain, self.state)
            room.deliver()
            band.carry_back(CONFIG, self.state)
        self.assertEqual(len(room.posts), 1)
        self.assertEqual(self.state["relay"], [])
        self.assertEqual(self.notes(), [])

    def test_a_message_band_refused_is_left_to_the_harbor_radio(self):
        def down(*_args, **_kwargs):
            raise band.urllib.error.URLError("down")

        with patch.object(band, "call", down):
            band.said(CONFIG, band.Match(), self.warning(), self.state)
            band.carry_back(CONFIG, self.state)
        self.assertEqual(self.state["relay"], [])
        self.assertEqual(self.notes(), [])

    def test_outside_a_match_the_robot_says_so(self):
        room = self.bridge({"Zip": [message(8, "go wide")]})
        self.state["waiting"]["Zip:m8"] = ("u-1", band.time.monotonic() - 7)
        with patch.object(band, "call", room.call):
            band.give_up(CONFIG, self.state)
            band.give_up(CONFIG, self.state)
        self.assertEqual(room.posts, [("Zip", "I'm not in a match right now. Tell me again after kickoff.", ["u-1"])])


if __name__ == "__main__":
    unittest.main()
