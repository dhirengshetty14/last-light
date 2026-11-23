extends SceneTree
## Practice for the robots' social choices in Free Agents: which captain to sign with, what to do
## about a broken promise, an offer or new terms, and how to vote.
##
## One series is three matches against the same two captains. Their habits with promises are
## hidden. A robot's memory of the captains lasts the series. What it has learned lasts for good.
## A robot grades each choice by the next promise made to it: kept is good, broken is bad. That is
## all it learns from, and it is the same thing it sees when it plays with people.
##
##   godot --headless --path . -s learning/social_train.gd -- --series=250 --seed=1 --out=a.json
##   godot --headless --path . -s learning/social_train.gd -- --merge=a.json,b.json --out=all.json
##
## Add --from=<table> to continue from an earlier table, and --cap=<tries> when merging the table
## that ships, so that what a robot sees in live play can outweigh practice.
const Game = preload("res://game/star_match.gd")
const Pilots = preload("res://learning/captains.gd")
const Policy = preload("res://learning/star_policy.gd")
## The kinds of captain the robots practise against. The held-out test adds kinds not listed here.
const KINDS = ["honest", "liar", "late", "favourite", "coin"]
const MATCHES := 3


func option(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=", true, 1)[1]
	return fallback


static func read(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"series": 0, "estimates": {}}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("estimates") is Dictionary:
		return {"series": 0, "estimates": {}}
	return {"series": int(data.get("series", 0)), "estimates": data.estimates}


## `floor` drops entries tried fewer times than that. `cap` scales an entry down to that many
## tries and keeps its average, so what a robot later sees in live play is not drowned out.
static func write(
	path: String, estimates: Dictionary, series: int, floor: int = 1, cap: int = 0
) -> void:
	var keys: Array = estimates.keys()
	keys.sort()
	var lines: Array = []
	for key in keys:
		if not str(key).begins_with("soc8/"):
			continue
		var row: Array = estimates[key]
		var tries := int(row[0])
		if tries < floor:
			continue
		var wins := int(row[1])
		var total := int(row[2])
		if cap > 0 and tries > cap:
			wins = roundi(float(wins) * cap / tries)
			total = roundi(float(total) * cap / tries)
			tries = cap
		lines.append('  "%s": [%d, %d, %d]' % [key, tries, wins, total])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(
		(
			'{\n "schema": "response-policy-v1",\n "series": %d,\n "estimates": {\n%s\n }\n}\n'
			% [series, ",\n".join(lines)]
		)
	)


func _initialize() -> void:
	var start := read(option("from", ""))
	var out := option("out", "res://learning/social_checkpoint.json")
	var parts := option("merge", "")
	if parts != "":
		# Workers that started from the same table each add only what they saw.
		var total: Dictionary = start.estimates.duplicate(true)
		var series: int = start.series
		for path in parts.split(","):
			var part := read(path)
			series += int(part.series) - int(start.series)
			for key in part.estimates:
				var was: Array = start.estimates.get(key, [0, 0, 0])
				var sum: Array = total.get(key, [0, 0, 0])
				var now: Array = part.estimates[key]
				total[key] = [
					int(sum[0]) + int(now[0]) - int(was[0]),
					int(sum[1]) + int(now[1]) - int(was[1]),
					int(sum[2]) + int(now[2]) - int(was[2])
				]
		write(out, total, series, int(option("floor", "1")), int(option("cap", "0")))
		print("merged ", series, " series, ", total.size(), " entries")
		quit()
		return
	var count := int(option("series", "100"))
	var base := int(option("seed", "1"))
	var explore := float(option("explore", ".25"))
	var court = Policy.new()
	court.load_checkpoint("res://learning/star_checkpoint.json")
	var table: Dictionary = court.estimates
	table.merge(start.estimates, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = base * 104729 + 7
	var points := 0
	for n in count:
		var styles := [Pilots.sample(rng, KINDS), Pilots.sample(rng, KINDS)]
		var memory := {}
		for m in MATCHES:
			var s = Game.new()
			s.keep_events = false
			s.social_learning = true
			s.configure_agents(table, memory, true, .08)
			for actor in s.agents:
				actor.social_exploration = explore
			s.setup(base * 1000003 + n * 10 + m, false, true)
			s.draft()
			while not s.finished:
				s.step(Pilots.crewed(s, styles))
			table = s.learned_weights()
			memory = s.relationships()
			for j in range(2, 5):
				points += s.social_points(j)
		if (n + 1) % 25 == 0:
			print("series ", n + 1, "  mean robot points ", snappedf(points / (25. * MATCHES * 3), .1))
			points = 0
	write(out, table, int(start.series) + count)
	quit()
