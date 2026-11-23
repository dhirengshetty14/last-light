"""The Bruin Analyst: turn Bruin's tables into advice for the robots and a live dashboard.

watch.py calls export_analyst() and write_dashboard() after every successful `bruin run`.
Standard library only.
"""

import html
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROBOTS = {2: "Pip", 3: "Morrow", 4: "Zip"}
# Validated categorical slots 1-3 (light, dark) from the dataviz reference palette.
COLORS = {2: ("#2a78d6", "#3987e5"), 3: ("#eb6834", "#d95926"), 4: ("#1baf7a", "#199e70")}


def query(bruin, config, sql):
    """Run one read-only query through Bruin and return a list of dicts."""
    out = subprocess.run(
        [bruin, "query", "--config-file", str(config), "-c", "nursery", "-o", "json", "-q", sql],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(out.stdout)
    names = [c["name"] for c in data["columns"]]
    return [dict(zip(names, row)) for row in data.get("rows") or []]


def latest_run(bruin, config):
    rows = query(
        bruin,
        config,
        "SELECT run, mode FROM flight.learning_curve ORDER BY started_usec DESC LIMIT 1",
    )
    return rows[0] if rows else None


def export_analyst(bruin, config, output):
    """Write the Analyst's advice for the newest match. The game reads this file every 10 s."""
    latest = latest_run(bruin, config)
    if not latest:
        return None
    run = latest["run"]
    advice_rows = query(
        bruin,
        config,
        "SELECT seat, robot, phase, scene, prefer, prefer_score, avoid, avoid_score, teacher, reason, through_tick "
        f"FROM flight.analyst_advice WHERE run = '{run}' ORDER BY seat, phase, scene",
    )
    curve = query(
        bruin,
        config,
        "SELECT seat, robot, match_number, reaction, reaction_change, reactions "
        f"FROM flight.learning_curve WHERE run = '{run}' ORDER BY seat",
    )
    advice = {}
    for r in advice_rows:
        entry = {
            "prefer": r["prefer"],
            "avoid": r["avoid"],
            "prefer_score": r["prefer_score"],
            "avoid_score": r["avoid_score"],
            "teacher": r["teacher"],
            "reason": r["reason"],
        }
        phase = advice.setdefault(str(r["seat"]), {}).setdefault(r["phase"], {})
        if r["scene"] == "*":
            phase.update(entry)
        else:
            phase.setdefault("scenes", {})[r["scene"]] = entry
    summary = {}
    for r in curve:
        change = r["reaction_change"]
        summary[str(r["seat"])] = {
            "robot": r["robot"],
            "match_number": r["match_number"],
            "reactions": r["reactions"],
            "score": r["reaction"],
            "previous": None if change is None else round(r["reaction"] - change, 4),
        }
    body = {
        "schema": "bruin-analyst-v1",
        # Wall-clock milliseconds only order the files; the game records what it accepted.
        "seq": time.time_ns() // 1_000_000,
        "run": run,
        "mode": latest["mode"],
        "through_tick": max([r["through_tick"] or 0 for r in advice_rows] or [0]),
        "advice": advice,
        "summary": summary,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_suffix(".next")
    tmp.write_text(json.dumps(body, indent=1))
    tmp.replace(output)
    return body


def _line_chart(series, x_label, y_label, x_fmt, width=1030, height=300):
    """series: {seat: [(x, y, tooltip), ...]}. Returns an inline SVG line chart, y fixed 0..1."""
    left, right, top, bottom = 44, 70, 14, 34
    xs = [p[0] for pts in series.values() for p in pts]
    if not xs:
        return '<p class="empty">No graded robot decisions yet.</p>'
    x0, x1 = min(xs), max(xs)
    span = (x1 - x0) or 1

    def px(x):
        return left + (x - x0) / span * (width - left - right) if x1 != x0 else (left + width - right) / 2

    def py(y):
        return top + (1 - y) * (height - top - bottom)

    parts = [
        f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="{html.escape(y_label)} by {html.escape(x_label)}">'
    ]
    for g in (0, 0.25, 0.5, 0.75, 1):
        parts.append(f'<line class="grid" x1="{left}" x2="{width - right}" y1="{py(g):.1f}" y2="{py(g):.1f}"/>')
        parts.append(f'<text class="tick" x="{left - 6}" y="{py(g) + 4:.1f}" text-anchor="end">{g:.2f}</text>')
    ticks = sorted(set(xs))
    step = max(1, len(ticks) // 8)
    for x in ticks[::step]:
        parts.append(f'<text class="tick" x="{px(x):.1f}" y="{height - bottom + 16}" text-anchor="middle">{x_fmt(x)}</text>')
    parts.append(f'<text class="axis" x="{(left + width - right) / 2}" y="{height - 4}" text-anchor="middle">{html.escape(x_label)}</text>')
    for seat, pts in series.items():
        pts = sorted(pts)
        path = " ".join(f"{'M' if i == 0 else 'L'}{px(x):.1f},{py(y):.1f}" for i, (x, y, _) in enumerate(pts))
        parts.append(f'<path class="line s{seat}" d="{path}"/>')
        for x, y, tip in pts:
            parts.append(
                f'<g class="pt"><circle class="hit" cx="{px(x):.1f}" cy="{py(y):.1f}" r="10"/>'
                f'<circle class="dot s{seat}" cx="{px(x):.1f}" cy="{py(y):.1f}" r="4"/>'
                f"<title>{html.escape(tip)}</title></g>"
            )
    # Direct labels at each line's end, nudged apart so they never overlap.
    ends = sorted(
        (py(max(pts)[1]), px(max(pts)[0]), seat) for seat, pts in series.items() if pts
    )
    last = -1e9
    for y, x, seat in ends:
        y = max(y, last + 15)
        last = y
        parts.append(f'<text class="label" x="{x + 10:.1f}" y="{y + 4:.1f}">{ROBOTS[seat]}</text>')
    parts.append("</svg>")
    return "".join(parts)


def _legend():
    return '<div class="legend">' + "".join(
        f'<span><i class="sw s{s}"></i>{n}</span>' for s, n in ROBOTS.items()
    ) + "</div>"


def _table(rows, cols):
    head = "".join(f"<th>{html.escape(label)}</th>" for _, label in cols)
    body = "".join(
        "<tr>" + "".join(f"<td>{html.escape('' if r.get(k) is None else str(r.get(k)))}</td>" for k, _ in cols) + "</tr>"
        for r in rows
    )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def write_dashboard(bruin, config, output, checks_passed=True):
    latest = latest_run(bruin, config)
    if not latest:
        return
    run, mode = latest["run"], latest["mode"]
    windows = query(
        bruin,
        config,
        "SELECT seat, start_second, reactions, reaction, speed, direction, outcome, advised_reactions, decision_grade "
        f"FROM flight.score_windows WHERE run = '{run}' ORDER BY seat, start_second",
    )
    curve = query(
        bruin,
        config,
        "SELECT run, seat, robot, match_number, origin, reactions, reaction, reaction_when_advised, "
        "reaction_unadvised, reaction_change, ball, human, teammate, wall, decision_grade, human_goals, robot_goals "
        "FROM flight.learning_curve "
        f"WHERE mode IS NOT DISTINCT FROM {'NULL' if mode is None else repr(mode)} ORDER BY match_number, seat",
    )
    advice = query(
        bruin,
        config,
        "SELECT robot, phase, CASE WHEN scene = '*' THEN 'any situation' ELSE replace(scene, '/', ', ') END AS scene, "
        "prefer, prefer_score, avoid, avoid_score, evidence, teacher, reason "
        f"FROM flight.analyst_advice WHERE run = '{run}' ORDER BY seat, phase, evidence DESC",
    )
    in_match = {s: [] for s in ROBOTS}
    for r in windows:
        if r["seat"] in in_match:
            in_match[r["seat"]].append(
                (
                    r["start_second"],
                    r["reaction"],
                    f"{ROBOTS[r['seat']]}, {r['start_second']}-{r['start_second'] + 15} s: reaction {r['reaction']:.2f} "
                    f"over {r['reactions']} moments (speed {r['speed']:.2f}, direction {r['direction']:.2f}, "
                    f"outcome {r['outcome']:.2f}; {r['advised_reactions']} with Bruin advice)",
                )
            )
    across = {s: [] for s in ROBOTS}
    for r in curve:
        if r["seat"] in across:
            across[r["seat"]].append(
                (r["match_number"], r["reaction"], f"{r['robot']}, match {r['match_number']}: reaction {r['reaction']:.2f} over {r['reactions']} ball events")
            )
    this = {r["seat"]: r for r in curve if r["run"] == run}
    tiles = "".join(
        f'<div class="tile"><div class="name"><i class="sw s{s}"></i>{n}</div>'
        f'<div class="big">{this[s]["reaction"]:.2f}</div>'
        f'<div class="sub">{"first " + html.escape(str(mode or "")) + " match" if this[s]["reaction_change"] is None else ("%+.2f" % this[s]["reaction_change"]) + " vs last match"}'
        f'{"" if this[s]["reaction_when_advised"] is None else " · %.2f with advice, %s without" % (this[s]["reaction_when_advised"], "–" if this[s]["reaction_unadvised"] is None else "%.2f" % this[s]["reaction_unadvised"])}</div></div>'
        for s, n in ROBOTS.items()
        if s in this
    )
    color_css = "".join(f".s{s}{{--c:{light}}}" for s, (light, _) in COLORS.items())
    dark_css = "".join(f".s{s}{{--c:{dark}}}" for s, (_, dark) in COLORS.items())
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="3">
<title>Bruin Analyst · Last Light</title><style>
:root{{color-scheme:light;--bg:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--grid:#e6e5e0;--card:#ffffff}}
@media (prefers-color-scheme:dark){{:root{{color-scheme:dark;--bg:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--grid:#3a3a37;--card:#232322}}{dark_css}}}
{color_css}
body{{margin:0;font:15px/1.45 system-ui,sans-serif;background:var(--bg);color:var(--ink)}}
main{{max-width:1080px;margin:0 auto;padding:24px}}
h1{{font-size:22px;margin:0}} h2{{font-size:16px;margin:28px 0 8px}}
.meta,.sub,.tick,.axis,.empty{{color:var(--ink2);fill:var(--ink2);font-size:12px}}
.tiles{{display:flex;gap:12px;margin-top:16px}} .tile{{flex:1;background:var(--card);border:1px solid var(--grid);border-radius:8px;padding:12px}}
.big{{font-size:30px;font-weight:600}} .name{{font-weight:600}}
.sw{{display:inline-block;width:10px;height:10px;border-radius:5px;background:var(--c);margin-right:6px}}
.legend{{display:flex;gap:16px;font-size:13px;color:var(--ink2)}}
svg{{width:100%;max-width:1030px;height:auto;background:var(--card);border:1px solid var(--grid);border-radius:8px}}
.grid{{stroke:var(--grid);stroke-width:1}} .line{{fill:none;stroke:var(--c);stroke-width:2}}
.dot{{fill:var(--c);stroke:var(--card);stroke-width:2}} .hit{{fill:transparent}} .pt:hover .dot{{r:6}}
.label{{fill:var(--ink);font-size:12px}}
table{{border-collapse:collapse;width:100%;font-size:13px;background:var(--card)}}
th,td{{text-align:left;padding:6px 8px;border-bottom:1px solid var(--grid)}} th{{color:var(--ink2);font-weight:600}}
</style></head><body><main>
<h1>Bruin Analyst</h1>
<div class="meta">Newest match {html.escape(run)} · {html.escape(str(mode))} · updated {time.strftime('%H:%M:%S')} ·
{'all Bruin data checks passed' if checks_passed else 'a Bruin data check FAILED'} · refreshes every 3 s</div>
<div class="tiles">{tiles}</div>
<h2>This match: reaction score per 15 seconds</h2>
<div class="meta">Every time something happens to a robot it is scored 0 to 1: the ball (a rival passes or takes it), a human (dashes at it while it carries the star), a teammate (gets the star), a wall (it carries the star to the side wall). 0.3 how soon it reacted, 0.3 whether it moved the right way, 0.4 how it turned out. Each reaction is filed under the situation it happened in (star near or far, coming or going, ahead or behind, a human pressing, a wall near). Goals are not counted.</div>
{_legend()}{_line_chart(in_match, "seconds into the match", "score", lambda x: f"{x}s")}
<h2>Across matches ({html.escape(str(mode))}): average reaction per match</h2>
{_legend()}{_line_chart(across, "match number", "score", lambda x: f"#{x}")}
<h2>What each robot is learning from its teammates</h2>
{_table(advice, [("robot", "Robot"), ("phase", "When"), ("scene", "Situation"), ("prefer", "Prefer"), ("prefer_score", "Teammates' reaction"), ("avoid", "Avoid"), ("avoid_score", "Teammates' reaction"), ("teacher", "Learned from"), ("reason", "Why")]) if advice else '<p class="empty">Not enough reactions yet: each move needs 3 by a teammate.</p>'}
<h2>Every match (table)</h2>
{_table(curve, [("match_number", "Match"), ("robot", "Robot"), ("origin", "Origin"), ("reactions", "Moments"), ("reaction", "Reaction"), ("reaction_change", "Change"), ("ball", "Ball"), ("human", "Humans"), ("teammate", "Teammates"), ("wall", "Walls"), ("reaction_when_advised", "With advice"), ("reaction_unadvised", "Without"), ("decision_grade", "Court grade"), ("human_goals", "Human goals"), ("robot_goals", "Robot goals")])}
</main></body></html>"""
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_suffix(".next")
    tmp.write_text(page)
    tmp.replace(output)
