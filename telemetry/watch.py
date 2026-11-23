"""Stage each sealed local log prefix and run one Bruin writer. Use --watch for live flights."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "telemetry" / "local"


def default_flights():
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    elif os.name == "nt":
        base = Path(os.environ["APPDATA"])
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return base / "Godot" / "app_userdata" / "This Side Up" / "flights"


# Staged rows of each log, by path and size. A finished match never changes, so during play only
# the live match is parsed again.
STAGED = {}


def stage_one(path):
    size = path.stat().st_size
    kept = STAGED.get(path)
    if kept and kept[0] == size:
        return kept[1], kept[2]
    rows = 0
    parts = []
    with path.open() as f:
        line = f.readline()
        if line.endswith("\n"):
            header = json.loads(line)
            if header.get("kind") == "header":
                for line in f:
                    if not line.endswith("\n"):
                        break
                    e = json.loads(line)
                    if "seq" not in e:
                        continue
                    row = {
                        "run": header["run"],
                        "mode": (
                            "Free Agents"
                            if header.get("free_agents")
                            else ("Open Crews" if header["open_crews"] else "Rivals")
                        )
                        if "open_crews" in header
                        else None,
                        "origin": header.get("origin", "fixture"),
                        "court": header.get("court_version"),
                        "seq": e["seq"],
                        "kind": e["kind"],
                        "tick": e["tick"],
                        "seat": e["seat"],
                        "points": e.get("points"),
                        "full_pass": e.get("pass"),
                        "category": e.get("type"),
                        "choice": e.get("action", e.get("choice")),
                        "cause": e.get("source", e.get("id")),
                        "flags": e.get("flags"),
                        "payload": json.dumps(e, separators=(",", ":")),
                    }
                    parts.append(json.dumps(row, separators=(",", ":")) + "\n")
                    rows += 1
    text = "".join(parts)
    STAGED[path] = (size, text, rows)
    return text, rows


def stage(paths):
    rows = 0
    temp = LOCAL / "events.ndjson.next"
    with temp.open("w") as out:
        for path in paths:
            text, count = stage_one(path)
            out.write(text)
            rows += count
    if rows:
        temp.replace(LOCAL / "events.ndjson")
    return rows


@contextmanager
def single_writer(lock_file, skip_if_busy):
    if os.name == "posix":
        import fcntl

        try:
            fcntl.flock(
                lock_file, fcntl.LOCK_EX | (fcntl.LOCK_NB if skip_if_busy else 0)
            )
        except BlockingIOError:
            yield False
            return
    yield True


def export_memory(bruin, config, output):
    sql = """SELECT context || '/' || choice, count(*), count(*) FILTER (WHERE full_pass), sum(points)
             FROM flight.learning_examples WHERE origin='local_play' GROUP BY context,choice ORDER BY 1"""
    query = subprocess.run(
        [
            bruin,
            "query",
            "--config-file",
            str(config),
            "-c",
            "nursery",
            "-o",
            "json",
            "-q",
            sql,
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    estimates = {
        row[0]: [int(v) for v in row[1:]] for row in json.loads(query.stdout)["rows"]
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_suffix(".next")
    tmp.write_text(
        json.dumps(
            {
                "schema": "verified-local-responses-v1",
                "estimates": estimates,
                "history": {
                    "resolved": sum(row[0] for row in estimates.values()),
                    "full": sum(row[1] for row in estimates.values()),
                },
            }
        )
    )
    tmp.replace(output)


def main():
    os.environ.setdefault("TELEMETRY_OPTOUT", "true")
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("inputs", nargs="*", type=Path)
    cli.add_argument("--watch", action="store_true")
    cli.add_argument(
        "--if-idle",
        action="store_true",
        help="Leave a running watcher in charge of the final refresh.",
    )
    cli.add_argument(
        "--flights",
        type=Path,
        help="Watch this folder of match logs instead of the game's own. Robot memory is not exported.",
    )
    args = cli.parse_args()
    LOCAL.mkdir(exist_ok=True)
    config = LOCAL / "bruin.yml"
    bruin = shutil.which("bruin") or str(Path.home() / ".local/bin/bruin")
    with (
        (LOCAL / "writer.lock").open("a") as lock,
        single_writer(lock, args.watch or args.if_idle) as acquired,
    ):
        if not acquired:
            return
        config.write_text(
            "default_environment: default\nenvironments:\n  default:\n    connections:\n      duckdb:\n        - name: nursery\n          path: "
            + json.dumps(str(LOCAL / "nursery.duckdb"))
            + "\n"
        )
        previous = None
        while True:
            folder = args.flights or default_flights()
            paths = sorted(args.inputs or folder.glob("*.jsonl"))
            try:
                stamp = tuple((str(p), p.stat().st_size) for p in paths)
                if stamp != previous and paths and stage(paths):
                    subprocess.run(
                        [
                            bruin,
                            "run",
                            "--workers",
                            "1",
                            "--config-file",
                            str(config),
                            "telemetry",
                        ],
                        cwd=ROOT,
                        check=True,
                    )
                    if not args.inputs and not args.flights:
                        export_memory(
                            bruin,
                            config,
                            default_flights().parent / "verified-responses.json",
                        )
                    previous = stamp
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                if not args.watch:
                    raise
                print(error, file=sys.stderr, flush=True)
            if not args.watch:
                break
            time.sleep(2)


if __name__ == "__main__":
    main()
