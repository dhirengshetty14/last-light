"""Do the robots react better when they learn from each other through Bruin?

Plays learning/peer_eval.gd (two arms on the same seeds: live Bruin peer advice, and none; match 3
of every series is against a scripted pilot style the robots have not met), loads
every match log with Bruin, and compares the robots' reaction scores (flight.reactions):
per match of each series, first half against second half of each match, and by kind of moment.
Writes learning/peer_eval.json.

    python3 learning/peer_eval.py                     # 5 series, every pilot style held out once
                                                      # (about 4 minutes a series)
    python3 learning/peer_eval.py --score-only        # score the logs already in user://peer-eval
"""

import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "telemetry"))
from analyst import query  # noqa: E402
from watch import default_flights  # noqa: E402

LOGS = default_flights().parent / "peer-eval"


def godot():
    for candidate in [
        os.environ.get("GODOT", ""),
        str(Path.home() / "Applications/Godot 4.7.2.app/Contents/MacOS/Godot"),
        "/Applications/Godot.app/Contents/MacOS/Godot",
        "godot",
    ]:
        if candidate and (Path(candidate).exists() or candidate == "godot"):
            return candidate
    raise SystemExit("Godot 4.7.2 not found; set GODOT.")


def mean_error(values):
    values = [v for v in values if v is not None]
    if not values:
        return None
    n = len(values)
    mean = sum(values) / n
    spread = sum((v - mean) ** 2 for v in values) / max(1, n - 1)
    return [round(mean, 4), round(math.sqrt(spread / n), 4), n]


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--series", type=int, default=5)
    cli.add_argument("--score-only", action="store_true")
    args = cli.parse_args()
    if not args.score_only:
        for old in LOGS.glob("*.jsonl"):
            old.unlink()
        subprocess.run(
            [godot(), "--headless", "--path", str(ROOT), "-s", "learning/peer_eval.gd", "--", f"--series={args.series}"],
            check=True,
        )
    logs = sorted(LOGS.glob("*.jsonl"))
    which = {}
    for path in logs:
        head = json.loads(path.open().readline())
        prefix = int(head["run"].split("-")[0])
        offset = prefix % 1000
        which[head["run"]] = {
            "arm": head["origin"],
            "series": offset // 10,
            "match": offset % 10 + 1,
            "style": head.get("pilot_style", "dash thief"),
        }
    subprocess.run([sys.executable, str(ROOT / "telemetry/watch.py"), *map(str, logs)], check=True, capture_output=True)
    bruin = os.environ.get("BRUIN") or str(Path.home() / ".local/bin/bruin")
    config = ROOT / "telemetry/local/bruin.yml"
    rows = query(
        bruin,
        config,
        "SELECT run, category, tick >= 7200 AS late, count(*) AS n, sum(reaction) AS total "
        "FROM flight.reactions GROUP BY ALL",
    )
    advised = query(
        bruin,
        config,
        "SELECT run, count(*) AS decisions, count(analyst_lift) AS advised FROM flight.agent_decisions GROUP BY run",
    )
    goals = query(bruin, config, "SELECT run, gold_goals, blue_goals FROM flight.court_scoreboard")

    # Per run: mean reaction overall, by half, by kind of moment.
    per_run = {}
    for r in rows:
        if r["run"] not in which:
            continue
        d = per_run.setdefault(r["run"], {"n": 0, "t": 0.0, "half": [[0, 0.0], [0, 0.0]], "kind": {}})
        d["n"] += r["n"]
        d["t"] += r["total"]
        d["half"][int(r["late"])][0] += r["n"]
        d["half"][int(r["late"])][1] += r["total"]
        k = d["kind"].setdefault(r["category"], [0, 0.0])
        k[0] += r["n"]
        k[1] += r["total"]

    def mean_of(pair):
        return pair[1] / pair[0] if pair[0] else None

    report = {
        "what": "Robots' reaction score 0 to 1 (flight.reactions): peer = live Bruin advice from teammates every 3 s, solo = none. Same seeds and pilots.",
        "series": len({(v["arm"], v["series"]) for v in which.values()}) // 2,
        "arms": {},
    }
    paired = {1: [], 2: [], 3: []}
    by_key = {(v["arm"], v["series"], v["match"]): run for run, v in which.items()}
    for arm in ["solo", "peer"]:
        runs = [run for run, v in which.items() if v["arm"] == arm and run in per_run]
        out = {"reaction_by_match": {}, "first_vs_second_half": {}, "by_kind": {}}
        for m in (1, 2, 3):
            out["reaction_by_match"][m] = mean_error(
                [per_run[r]["t"] / per_run[r]["n"] for r in runs if which[r]["match"] == m]
            )
        out["first_vs_second_half"] = {
            "first": mean_error([mean_of(per_run[r]["half"][0]) for r in runs]),
            "second": mean_error([mean_of(per_run[r]["half"][1]) for r in runs]),
        }
        kinds = sorted({k for r in runs for k in per_run[r]["kind"]})
        out["by_kind"] = {k: mean_error([mean_of(per_run[r]["kind"].get(k, [0, 0])) for r in runs]) for k in kinds}
        adv = {a["run"]: a for a in advised}
        out["decisions_with_advice"] = round(
            sum(adv[r]["advised"] for r in runs if r in adv) / max(1, sum(adv[r]["decisions"] for r in runs if r in adv)), 4
        )
        g = {x["run"]: x for x in goals}
        out["goals_humans_robots"] = [
            round(sum(g[r]["gold_goals"] for r in runs if r in g) / max(1, len(runs)), 2),
            round(sum(g[r]["blue_goals"] for r in runs if r in g) / max(1, len(runs)), 2),
        ]
        report["arms"][arm] = out
    for (arm, series, m), run in by_key.items():
        if arm != "peer":
            continue
        twin = by_key.get(("solo", series, m))
        if twin in per_run and run in per_run:
            paired[m].append(per_run[run]["t"] / per_run[run]["n"] - per_run[twin]["t"] / per_run[twin]["n"])
    report["peer_minus_solo_by_match"] = {m: mean_error(v) for m, v in paired.items()}
    # The overfitting test: match 3 of every series is against a pilot style the robots had not met.
    report["peer_minus_solo_unseen_style"] = report["peer_minus_solo_by_match"][3]
    styles = {}
    for (arm, series, m), run in by_key.items():
        twin = by_key.get(("solo", series, m))
        if arm == "peer" and run in per_run and twin in per_run:
            styles.setdefault(which[run]["style"] + (" (unseen)" if m == 3 else " (learning)"), []).append(
                per_run[run]["t"] / per_run[run]["n"] - per_run[twin]["t"] / per_run[twin]["n"]
            )
    report["peer_minus_solo_by_pilot_style"] = {k: mean_error(v) for k, v in sorted(styles.items())}
    (ROOT / "learning/peer_eval.json").write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
