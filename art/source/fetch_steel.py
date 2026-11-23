"""Fetch Rob Tuytel's CC0 scan of a worn steel plate. Keep the files small enough for mobile GPUs."""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import json

base = Path(__file__).resolve().parents[2] / "assets" / "room"
headers = {"User-Agent": "ThisSideUp-Game/1.0 (local Godot art build)"}


def read(url):
    with urlopen(Request(url, headers=headers), timeout=40) as response:
        return response.read()


def fetch(entry):
    name, meta = entry
    path = base / ("steel_" + name + ".jpg")
    if path.exists() and hashlib.md5(path.read_bytes()).hexdigest() == meta["md5"]:
        return
    data = read(meta["url"])
    if hashlib.md5(data).hexdigest() != meta["md5"]:
        raise ValueError("Checksum mismatch in " + name)
    path.write_bytes(data)


if __name__ == "__main__":
    meta = json.loads(read("https://api.polyhaven.com/files/metal_plate_02"))
    with ThreadPoolExecutor(max_workers=3) as workers:
        list(
            workers.map(
                fetch,
                [(key, meta[key]["1k"]["jpg"]) for key in ("Diffuse", "nor_gl", "arm")],
            )
        )
