"""Fetch the two pinned, MIT-licensed source avatars into a disposable directory."""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
from urllib.request import urlopen

REVISION = "0943055db6ec570bcef9f2c8b41c9e5467c808f9"
BASE = f"https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/{REVISION}/"
PEOPLE = {
    "Nell": (
        "Medical_Female_03",
        "f154",
        [
            "body_color_blue",
            "body_normal",
            "head_color",
            "head_normal",
            "opacity_color",
        ],
    ),
    "Rafi": (
        "Male_Adult_04",
        "m006",
        ["body_color", "body_normal", "head_color", "head_normal", "opacity_color"],
    ),
}


def fetch(pair):
    url, dest = pair
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        with urlopen(BASE + url, timeout=90) as response:
            payload = response.read()
        staging = dest.with_suffix(dest.suffix + ".part")
        staging.write_bytes(payload)
        staging.replace(dest)
    return dest.name


if __name__ == "__main__":
    cache = Path(sys.argv[1])
    jobs = [
        (
            "LICENSE.md",
            Path(__file__).resolve().parents[2] / "licenses" / "Rocketbox-LICENSE.txt",
        )
    ]
    for name, (model, prefix, maps) in PEOPLE.items():
        group = "Adults" if model == "Male_Adult_04" else "Professions"
        base = f"Assets/Avatars/{group}/{model}/"
        jobs.append((base + f"Export/{model}_facial.fbx", cache / name / "figure.fbx"))
        for key in maps:
            file = f"{prefix}_{key}.tga"
            jobs.append((base + "Textures/" + file, cache / name / file))
    with ThreadPoolExecutor(max_workers=5) as pool:
        for file in pool.map(fetch, jobs):
            print(file, flush=True)
