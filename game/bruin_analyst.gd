extends RefCounted
## The Bruin Analyst, the robots' sideline coach. It never touches the simulation directly.
##
## While a match is played, telemetry/watch.py loads the match log into DuckDB with Bruin every
## 2 s. Bruin scores how well each robot reacted to every ball event (flight.reactions: how soon it
## moved, how much ground it closed, whether it won the star) and, for each robot, finds the move
## with which its TEAMMATES reacted best and worst (flight.analyst_advice). The watcher writes that
## to user://bruin-analyst.json. Every 3 s this reads the file and, when it is new and about this
## very match, turns it into one packet per robot. The packets go into `sim.step` at a tick
## boundary, like Gemini replies, and are recorded, so replays stay exact. Each robot keeps its own
## memory: what it hears from its teammates is advice it weighs, not a copy of their memory.
const PATH := "user://bruin-analyst.json"
const EVERY_TICKS := 180
const OPTIONS := {
	"defend": ["press", "screen", "cut"],
	"support": ["advance", "outlet"],
	"carry": ["drive", "flank", "pass", "finish", "evade"],
	"loose": ["lead", "recover"]
}
var run := ""
## Tests point this at a fixture so they never read the player's own file.
var path := PATH
var next_tick := EVERY_TICKS
var last_seq := 0
var serial := 0


func _init(run_name: String) -> void:
	run = run_name


func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if (
		not data is Dictionary
		or data.get("schema") != "bruin-analyst-v1"
		or str(data.get("run", "")) != run
	):
		return {}
	return data


func poll(sim) -> Array:
	if sim.tick < next_tick:
		return []
	next_tick = sim.tick + EVERY_TICKS
	var data := read()
	var seq := int(data.get("seq", 0))
	if data.is_empty() or seq <= last_seq:
		return []
	last_seq = seq
	serial += 1
	var packets := []
	var advice: Variant = data.get("advice", {})
	if not advice is Dictionary:
		return []
	for seat in [2, 3, 4]:
		var phases: Variant = advice.get(str(seat), {})
		if not phases is Dictionary:
			continue
		var clean := {}
		for phase in phases:
			var entry: Variant = phases[phase]
			if not OPTIONS.has(phase) or not entry is Dictionary:
				continue
			var kept := tidy(phase, entry)
			var scenes := {}
			var given: Variant = entry.get("scenes", {})
			if given is Dictionary:
				for situation in given:
					var one := tidy(phase, given[situation])
					if not one.is_empty():
						scenes[str(situation)] = one
			if not scenes.is_empty():
				kept["scenes"] = scenes
			if kept.has("prefer") or kept.has("scenes"):
				clean[phase] = kept
		if not clean.is_empty():
			packets.append(
				{
					"source": "bruin",
					"actor": seat,
					"id": serial,
					"through_tick": int(data.get("through_tick", 0)),
					"advice": clean
				}
			)
	return packets


## One piece of advice, kept only when both moves are real moves for that phase.
func tidy(phase: String, entry: Variant) -> Dictionary:
	if (
		not entry is Dictionary
		or str(entry.get("prefer", "")) not in OPTIONS[phase]
		or str(entry.get("avoid", "")) not in OPTIONS[phase]
	):
		return {}
	return {
		"prefer": str(entry.prefer),
		"avoid": str(entry.avoid),
		"teacher": str(entry.get("teacher", "")),
		"reason": str(entry.get("reason", ""))
	}


## One line for the final card: each robot's score this match, and in its previous match.
func summary_line() -> String:
	var summary: Variant = read().get("summary", {})
	if not summary is Dictionary or summary.is_empty():
		return ""
	var now: Array[String] = []
	var before: Array[String] = []
	for seat in ["2", "3", "4"]:
		var row: Variant = summary.get(seat)
		if not row is Dictionary:
			continue
		now.append("%s %.2f" % [row.robot, float(row.score)])
		if row.get("previous") != null:
			before.append("%s %.2f" % [row.robot, float(row.previous)])
	var line := "Bruin Analyst, reaction to the ball 0 to 1   " + " · ".join(now)
	if not before.is_empty():
		line += "      last match   " + " · ".join(before)
	return line
