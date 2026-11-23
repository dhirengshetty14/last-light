"""Put Last Light's Bruin pipeline in Bruin Cloud, with the match data in MotherDuck.

The live robot report keeps running on the game's Mac (telemetry/dashboard.py). This script adds a
copy in the cloud that the team and the Bruin Cloud dashboards and agents can see:

    python3 telemetry/cloud.py configure   once: your MotherDuck token, asked for privately
    python3 telemetry/cloud.py connect     once: link this GitHub repository as a Bruin Cloud project
    python3 telemetry/cloud.py sync        upload the recorded matches and run the pipeline in the cloud
    python3 telemetry/cloud.py status      the latest cloud runs
    python3 telemetry/cloud.py coach       ask Coach Bruin (the team's Bruin agent) for notes the
                                           robots use from their next match

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
import time
from datetime import datetime, timedelta, timezone
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
    # A run needs a date window. This pipeline is not partitioned by date, so today's is used.
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    result = bruin(
        "cloud", "runs", "trigger", "--project-id", project, "--pipeline", PIPELINE,
        "--start-date", today.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "--end-date", (today + timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "--var", 'source="cloud"', "--note", f"{rows} events from {len(paths)} matches",
    )
    print((result.stdout or "") + (result.stderr or ""))
    if result.returncode != 0:
        fail("The cloud run did not start.")


TASK_PHASE = {
    "Win the star back": "defend",
    "Reach a loose star first": "loose",
    "Get open for a teammate": "support",
    "Keep the star under pressure": "carry",
    "Carry the star forward": "carry",
    "Complete a pass": "carry",
    "Finish at the ring": "carry",
}
MOVES = {
    "defend": ["press", "screen", "cut"],
    "loose": ["recover", "lead"],
    "support": ["outlet", "advance"],
    "carry": ["drive", "flank", "pass", "finish", "evade"],
}
NOTE = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "robot": {"type": "string", "enum": ["Pip", "Morrow", "Zip"]},
        "task": {"type": "string", "enum": list(TASK_PHASE)},
        "situation": {"type": "string"},
        "move": {"type": "string", "description": "The move that keeps failing."},
        "full_rate": {"type": "number"},
        "breaks_at": {"type": "string"},
        "try_move": {
            "type": "string",
            "enum": sorted({m for moves in MOVES.values() for m in moves}),
            "description": "The move to try instead, legal in the same situation.",
        },
        "advice": {"type": "string", "description": "One sentence with the evidence, for the robot to say."},
    },
    "required": ["robot", "task", "situation", "move", "full_rate", "breaks_at", "try_move", "advice"],
}
SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "summary": {"type": "string", "description": "Two sentences on where the robots fail most."},
        "notes": {"type": "array", "items": NOTE},
    },
    "required": ["summary", "notes"],
}
QUESTION = (
    "You coach three robot agents, Pip, Morrow and Zip, in the game Last Light. In the MotherDuck "
    "connection, the table flight.robot_failure_modes has one row for each verifier generation, robot, "
    "task, situation and move: attempts (graded decisions), full_rate (share passing all five verifier "
    "checks), miss rates for each check, breaks_at (the check it usually fails) and lost_score (verifier "
    "score left on the table). Use only rows with the highest verifier value. Find the three rows with "
    "the largest lost_score. For each, pick the move the robot should try instead: another move it has "
    "used in the same task and situation that scored better, with at least 10 attempts. Write the advice "
    "as one sentence the robot can say, with the numbers. Use the data only."
)


def coach(args):
    team_agents = bruin("cloud", "agents", "list", "-o", "json")
    if team_agents.returncode != 0:
        fail("Could not list Bruin Cloud agents. Run: bruin cloud login --global", team_agents)
    listed = json.loads(team_agents.stdout)
    listed = listed.get("agents", listed) if isinstance(listed, dict) else listed
    agent_id = str(args.agent or listed[0]["id"])
    schema_file = LOCAL / "coach-schema.json"
    schema_file.write_text(json.dumps(SCHEMA))
    sent = bruin(
        "cloud", "agents", "send", "--agent-id", agent_id, "-o", "json",
        "--output-schema-file", str(schema_file), "--message", QUESTION,
    )
    if sent.returncode != 0:
        fail("Coach Bruin did not take the question.", sent)
    ticket = json.loads(sent.stdout)
    print("Asked Coach Bruin; waiting for the answer (usually under a minute)...")
    answer = {}
    for _ in range(60):
        time.sleep(5)
        polled = bruin(
            "cloud", "agents", "status", "--agent-id", agent_id,
            "--thread-id", str(ticket["thread_id"]), "--message-id", str(ticket["message_pair_id"]),
            "-o", "json",
        )
        try:
            answer = json.loads(polled.stdout)
        except ValueError:
            continue
        if answer.get("status") in ("completed", "failed"):
            break
    found = answer.get("structured_output")
    if answer.get("status") != "completed" or not found:
        fail("Coach Bruin did not answer in time; try again in a minute.")
    notes = []
    for note in found["notes"]:
        phase = TASK_PHASE.get(note["task"])
        if not phase or note["move"] not in MOVES[phase] or note["try_move"] not in MOVES[phase]:
            continue
        if note["move"] == note["try_move"]:
            continue
        notes.append({
            "robot": note["robot"], "phase": phase, "try": note["try_move"],
            "avoid": note["move"], "advice": note["advice"],
            "task": note["task"], "situation": note["situation"],
            "full_rate": note["full_rate"], "breaks_at": note["breaks_at"],
        })
    record = {
        "schema": "bruin-coach-v1",
        "asked_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "agent_id": agent_id,
        "thread_id": ticket["thread_id"],
        "summary": found["summary"],
        "notes": notes,
    }
    for target in (watch.default_flights().parent / "bruin-coach.json", LOCAL / "bruin-coach.json"):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(record, indent=1))
    print(found["summary"])
    for note in notes:
        print(f"  {note['robot']} ({note['phase']}): try {note['try']}, not {note['avoid']}. {note['advice']}")
    print(f"{len(notes)} notes saved. The robots use them from the next match the game starts.")


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
    asked = steps.add_parser("coach")
    asked.add_argument("--agent", help="Bruin Cloud agent id (default: the team's first agent).")
    asked.set_defaults(go=coach)
    args = cli.parse_args()
    args.go(args)


if __name__ == "__main__":
    main()
