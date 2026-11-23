"""Optional, off-line visual review of one explicitly selected image. No game state is changed."""

import argparse
import base64
import json
import mimetypes
import os
from pathlib import Path
import urllib.error
import urllib.request

MODEL = "gemini-3.5-flash-lite"


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("frame", type=Path)
    args = cli.parse_args()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        cli.error("Set GEMINI_API_KEY in your local environment.")
    mime = mimetypes.guess_type(args.frame.name)[0]
    if (
        mime not in ("image/png", "image/jpeg", "image/webp")
        or args.frame.stat().st_size > 10_000_000
    ):
        cli.error("Select one PNG, JPEG, or WebP under 10 MB.")
    prompt = (
        "Review this Godot screenshot for visible clipping, facial distortion, target legibility and "
        "text overlap. Return a compact JSON object with visible_issues and evidence in screen coordinates. "
        "Describe observed pixels only. Gameplay correctness is verified by the simulator."
    )
    body = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {
                        "inline_data": {
                            "mime_type": mime,
                            "data": base64.b64encode(args.frame.read_bytes()).decode(),
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.1,
        },
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as reply:
            res = json.load(reply)
    except urllib.error.HTTPError as e:
        raise SystemExit(f"Visual review failed with HTTP {e.code}.") from None
    print(res["candidates"][0]["content"]["parts"][-1]["text"])


if __name__ == "__main__":
    main()
