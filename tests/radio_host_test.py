import io
import json
import sys
import unittest
from pathlib import Path
from threading import Thread
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
import radio


def observation(name):
    return {
        "name": name,
        "team": 1,
        "position": [1, 0.2],
        "nearby": [],
        "blue_goals": 0,
        "gold_goals": 1,
        "star_holder": "Nell",
        "scouting_shots_passes_lane": [[2, 1, -0.2], [1, 3, 0.5]],
        "relationships": {"reputation": [1, 0]},
        "learned_tactic": "press",
        "last_four_plays": [],
        "last_public_reason": "unknown client text",
    }


class RadioTest(unittest.TestCase):
    def test_google_protocol_and_public_fields(self):
        for name in radio.ROBOTS:
            seen = radio.scout(observation(name))
            plan = {
                phase: {"move": moves[0], "reason": "Guard this lane."}
                for phase, moves in radio.MOVES.items()
            }
            body = {
                "modelVersion": radio.MODEL,
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {
                            "parts": [
                                {"thought": True, "text": "private fixture"},
                                {"text": json.dumps(plan)},
                            ]
                        },
                    }
                ],
            }
            with patch.object(
                radio, "urlopen", return_value=io.BytesIO(json.dumps(body).encode())
            ) as upstream:
                reply = radio.google_plan("fixture-only", seen)
            request = upstream.call_args.args[0]
            self.assertEqual(request.full_url, radio.GOOGLE)
            self.assertIn(
                name, json.loads(request.data)["systemInstruction"]["parts"][0]["text"]
            )
            self.assertNotIn("unknown client text", request.data.decode())
            self.assertEqual(reply["plan"], plan)
            self.assertNotIn("private fixture", json.dumps(reply))

    def test_service_routes_and_budget(self):
        receipts = []

        def generate(seen):
            receipts.append(seen)
            return {"model_version": radio.MODEL}

        with radio.Radio(("127.0.0.1", 0), generate) as service:
            thread = Thread(target=service.serve_forever, daemon=True)
            thread.start()
            try:

                def post(data):
                    return urlopen(
                        Request(
                            f"http://127.0.0.1:{service.server_port}/v1/playbook",
                            data=json.dumps(data).encode(),
                            headers={"Content-Type": "application/json"},
                        ),
                        timeout=2,
                    )

                for name in radio.ROBOTS:
                    with post(observation(name)) as response:
                        self.assertEqual(response.status, 200)
                self.assertEqual([x["name"] for x in receipts], list(radio.ROBOTS))
                for bad in [
                    {},
                    {**observation("Pip"), "nearby": [{}]},
                    observation("Unknown"),
                ]:
                    with self.assertRaises(HTTPError) as err:
                        post(bad)
                    self.assertEqual(err.exception.code, 400)
                for _ in range(69):
                    self.assertTrue(service.admit())
                with self.assertRaises(HTTPError) as err:
                    post(observation("Zip"))
                self.assertEqual(err.exception.code, 429)
                self.assertEqual(len(receipts), 3)
            finally:
                service.shutdown()
                thread.join()


if __name__ == "__main__":
    unittest.main()
