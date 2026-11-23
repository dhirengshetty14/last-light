"""Put Last Light's Bruin pipeline in Bruin Cloud, with the match data in MotherDuck.

The live robot report keeps running on the game's Mac (telemetry/dashboard.py). This script adds a
copy in the cloud that the team and the Bruin Cloud dashboards and agents can see:

    python3 telemetry/cloud.py configure   once: your MotherDuck token, asked for privately
    python3 telemetry/cloud.py connect     once: link this GitHub repository as a Bruin Cloud project
    python3 telemetry/cloud.py sync        upload the recorded matches and run the pipeline in the cloud
    python3 telemetry/cloud.py status      the latest cloud runs

Sign in to Bruin Cloud first with `bruin cloud login --global`. The MotherDuck token is kept in
telemetry/local/cloud.bruin.yml (gitignored, readable by you only) and stored in Bruin Cloud as the
`nursery` connection, which the pipeline already uses. It is never printed.

What leaves this Mac: the match event logs (game events, robot decisions and grades, robot talk,
and the observations and replies of Gemini calls). Nothing else.
"""

import argparse
import getpass
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "telemetry" / "local"
CONFIG = LOCAL / "cloud.bruin.yml"
UPLOAD = LOCAL / "cloud-events.ndjson"
REPO = "https://github.com/dhirengshetty14/last-light"
PIPELINE = "nursery-flight-recorder"
COLUMNS = (
    "{run: 'VARCHAR', mode: 'VARCHAR', origin: 'VARCHAR', court: 'INTEGER', seq: 'BIGINT', "
    "tick: 'BIGINT', kind: 'VARCHAR', seat: 'INTEGER', points: 'INTEGER', full_pass: 'BOOLEAN', "
    "category: 'VARCHAR', choice: 'VARCHAR', cause: 'BIGINT', flags: 'BOOLEAN[]', payload: 'VARCHAR'}"
)

sys.path.insert(0, str(ROOT / "telemetry"))
import watch  # noqa: E402  (the same staging the local pipeline uses)


def bruin(*args, capture=True):
    exe = shutil.which("bruin") or str(Path.home() / ".local/bin/bruin")
    env = dict(os.environ, TELEMETRY_OPTOUT="true")
    return subprocess.run(
        [exe, *args], cwd=ROOT, env=env, capture_output=capture, text=True, check=False
    )


def fail(message, result=None):
    print(message, file=sys.stderr)
    if result is not None:
        print((result.stdout or "") + (result.stderr or ""), file=sys.stderr)
    sys.exit(1)


def project_id():
    result = bruin("cloud", "projects", "list", "-o", "json")
    if result.returncode != 0:
        fail("Could not list Bruin Cloud projects. Run: bruin cloud login --global", result)
    for project in json.loads(result.stdout):
        if (project.get("repo") or {}).get("url", "").rstrip("/").removesuffix(".git") == REPO:
            return project["id"]
    return None


def configure(_args):
    LOCAL.mkdir(exist_ok=True)
    token = getpass.getpass("MotherDuck access token (hidden): ").strip()
    if not token:
        fail("No token entered.")
    text = (
        "default_environment: default\nenvironments:\n  default:\n    connections:\n"
        "      motherduck:\n        - name: nursery\n          token: " + json.dumps(token) + "\n"
    )
    descriptor = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as out:
        out.write(text)
    test = bruin("connections", "test", "--config-file", str(CONFIG), "--name", "nursery")
    if test.returncode != 0:
        fail("MotherDuck did not accept the token.", test)
    print("MotherDuck connection works.")
    added = bruin(
        "cloud", "connections", "add", "--name", "nursery", "--config-file", str(CONFIG)
    )
    if added.returncode != 0 and "exist" not in (added.stdout + added.stderr).lower():
        fail("Could not store the connection in Bruin Cloud.", added)
    print("Bruin Cloud has the `nursery` connection (MotherDuck).")


def connect(_args):
    if project_id():
        print("This repository is already a Bruin Cloud project.")
        return
    result = bruin(
        "cloud", "projects", "create", "--name", "Last Light", "--repo-url", REPO,
        "--branch", "main",
    )
    print((result.stdout or "") + (result.stderr or ""))
    if result.returncode != 0:
        fail(
            "Bruin Cloud could not reach the repository. Install the Bruin GitHub App on "
            "dhirengshetty14/last-light from Bruin Cloud's project settings, then run this again."
        )


def sync(args):
    if not CONFIG.exists():
        fail("Run `python3 telemetry/cloud.py configure` first.")
    folder = args.flights or watch.default_flights()
    paths = sorted(folder.glob("*.jsonl"))
    rows = watch.stage(paths, UPLOAD)
    if not rows:
        fail(f"No match logs to upload in {folder}.")
    print(f"Uploading {rows:,} events from {len(paths)} matches to MotherDuck...")
    for sql in (
        "CREATE SCHEMA IF NOT EXISTS raw",
        "CREATE OR REPLACE TABLE raw.match_events AS SELECT * FROM read_json("
        + json.dumps(str(UPLOAD)).replace('"', "'")
        + ", columns=" + COLUMNS + ", format='newline_delimited')",
    ):
        result = bruin("query", "--config-file", str(CONFIG), "-c", "nursery", "-q", sql)
        if result.returncode != 0:
            fail("The upload to MotherDuck failed.", result)
    print("Uploaded. MotherDuck table raw.match_events is up to date.")
    if args.no_run:
        return
    project = project_id()
    if not project:
        print("No Bruin Cloud project for this repository yet: run `python3 telemetry/cloud.py connect`.")
        return
    result = bruin(
        "cloud", "runs", "trigger", "--project-id", project, "--pipeline", PIPELINE,
        "--var", 'source="cloud"', "--note", f"{rows} events from {len(paths)} matches",
    )
    print((result.stdout or "") + (result.stderr or ""))
    if result.returncode != 0:
        fail("The cloud run did not start.")


def status(_args):
    project = project_id()
    if not project:
        fail("No Bruin Cloud project for this repository yet.")
    print(bruin("cloud", "runs", "list", "--project-id", project, "--limit", "5").stdout)


def main():
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    steps = cli.add_subparsers(dest="step", required=True)
    steps.add_parser("configure").set_defaults(go=configure)
    steps.add_parser("connect").set_defaults(go=connect)
    up = steps.add_parser("sync")
    up.add_argument("--flights", type=Path, help="Upload this folder of match logs instead.")
    up.add_argument("--no-run", action="store_true", help="Upload only; do not start a cloud run.")
    up.set_defaults(go=sync)
    steps.add_parser("status").set_defaults(go=status)
    args = cli.parse_args()
    args.go(args)


if __name__ == "__main__":
    main()
