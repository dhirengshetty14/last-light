extends SceneTree
## Do the robots react better when they learn from each other through Bruin?
##
## Every series is three Rivals matches in a row, and the robots carry what they learned from one
## match into the next. The two humans are scripted, in one of five styles: the dash thief of the
## steal test, and the straight-line runner, passing pair, flank runner and turnover hunter of the
## trainer. So that the robots cannot just learn one habit, matches 1 and 2 of a series use two
## styles and match 3 a style the robots have NOT met in that series; series n holds out style n % 5,
## so over five series every style is the unseen one once. Two arms play the same seeds and pilots:
##   peer  court 13 with live Bruin: every 3 s of play the match log so far is loaded with Bruin
##         (telemetry/watch.py), and each robot receives the moves with which its teammates reacted
##         best in each situation, exactly as in a live Rivals match
##   solo  the same robots learning only from their own graded decisions, with no Bruin advice
## The match logs go to user://peer-eval/. learning/peer_eval.py runs this and scores the logs with
## Bruin (flight.reactions). Options: --series=N (default 5, one per held-out style), --arms=peer,solo.
const Game = preload("res://game/star_match.gd")
const Policy = preload("res://learning/star_policy.gd")
const Steal = preload("res://learning/steal_eval.gd")
const Analyst = preload("res://game/bruin_analyst.gd")
const Train = preload("res://learning/star_train.gd")
const STYLES := ["dash thief", "straight runner", "passing pair", "flank runner", "turnover hunter"]


static func pilots(s, style: int) -> Array:
	return Steal.thieves(s) if style == 0 else Train.drivers(s, style - 1)


## The pilots' style for match m (0 to 2) of series n: two styles to learn from, then the held-out one.
static func style_for(n: int, m: int) -> int:
	var held := n % STYLES.size()
	return held if m == 2 else (held + 1 + m) % STYLES.size()
const MATCHES := 3
const DIR := "user://peer-eval/"


func bruin(files: Array) -> void:
	var out := []
	var args := [ProjectSettings.globalize_path("res://telemetry/watch.py")]
	for path in files:
		args.append(ProjectSettings.globalize_path(path))
	if OS.execute("python3", args, out, true) != 0:
		printerr("Bruin refresh failed: ", out)


func play(
	arm: String, seed_value: int, run: String, style: int, weights: Dictionary, memory: Dictionary, earlier: Array
) -> Dictionary:
	var s = Game.new()
	s.setup(seed_value, false)
	s.configure_agents(weights, memory, true, .04)
	var path := DIR + run + ".jsonl"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(
		JSON.stringify(
			{
				"kind": "header",
				"run": run,
				"seed": seed_value,
				"game": "last-light-v13",
				"court_version": 13,
				"origin": arm,
				"open_crews": false,
				"free_agents": false,
				"input_schema": 1,
				"moving_passes": s.moving_passes,
				"dock_relay": s.relay_rules,
				"social_learning": s.social_learning,
				"bruin_analyst": arm == "peer",
				"pilot_style": STYLES[style],
				"starting_policy": weights,
				"starting_relationships": memory
			}
		)
	)
	var analyst := Analyst.new(run)
	analyst.path = ProjectSettings.globalize_path("res://telemetry/local/bruin-analyst.json")
	var advised := 0
	while not s.finished:
		var packets := []
		if arm == "peer" and s.tick >= analyst.next_tick:
			f.flush()
			bruin(earlier + [path])
			packets = analyst.poll(s)
		s.step(pilots(s, style), packets)
		for e in s.events:
			if e.kind == "analyst_advice" and e.result == "available":
				advised += 1
			f.store_line(JSON.stringify(e))
		s.events.clear()
	f.store_line(JSON.stringify({"kind": "footer", "tick": s.tick, "completed": true, "gold": s.goals[0], "blue": s.goals[1]}))
	f.close()
	return {"path": path, "weights": s.learned_weights(), "memory": s.relationships(), "goals": s.goals.duplicate(), "advice": advised}


func _initialize() -> void:
	var series_count := 5
	var arms := ["solo", "peer"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--series="):
			series_count = int(arg.trim_prefix("--series="))
		if arg.begins_with("--arms="):
			arms = Array(arg.trim_prefix("--arms=").split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var start = Policy.new()
	start.load_checkpoint("res://learning/star_checkpoint.json")
	for arm in arms:
		for n in series_count:
			var weights: Dictionary = start.estimates.duplicate(true)
			var memory := {}
			var files := []
			for m in MATCHES:
				var seed_value := 91000 + n * 7 + m
				# Run names start with a time, which orders matches; the arm and series are in it too.
				var run := "%d-%d" % [(1900000000000000 if arm == "peer" else 1800000000000000) + n * 10 + m, seed_value]
				var style := style_for(n, m)
				var r := play(arm, seed_value, run, style, weights, memory, files)
				files.append(r.path)
				weights = r.weights
				memory = r.memory
				print(
					(
						"%s series %d match %d (%s%s): goals %s, advice packets %d"
						% [arm, n + 1, m + 1, STYLES[style], ", unseen" if m == 2 else "", r.goals, r.advice]
					)
				)
	quit(0)
