extends SceneTree
## A held-out test of the robots' social choices in Free Agents. Every match uses a seed the robots
## never practised on. Half the series also bring a kind of captain they never practised against.
##
## For each way of choosing it reports:
##   verifier  a score from 0 to 1. Every choice is checked the moment it is made against the
##             captains' hidden habits, and three more checks run on how each match went. The
##             robots never see this score or the habits. They learn only from whether the next
##             promise made to them was kept.
##   points    the robot's own match result as shown at the whistle (0 to 100)
##
##   godot --headless --path . -s learning/social_eval.gd -- --table=learning/social_checkpoint.json
const Game = preload("res://game/star_match.gd")
const Pilots = preload("res://learning/captains.gd")
const Policy = preload("res://learning/star_policy.gd")
const Train = preload("res://learning/social_train.gd")
const NOVEL = [{"kind": "reformed"}, {"kind": "coin", "percent": 25}, {"kind": "coin", "percent": 75}]
const FIRST_SEED := 900000000


func option(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=", true, 1)[1]
	return fallback


## The same captains for every way of choosing. Odd series include one unseen kind.
func pairing(index: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555000 + index
	var pair := [Pilots.sample(rng, Train.KINDS), Pilots.sample(rng, Train.KINDS)]
	if index % 2 == 1:
		pair[rng.randi() % 2].merge(NOVEL[rng.randi() % NOVEL.size()], true)
	return pair


## One choice against the hidden truth. 1 is right, 0 is wrong, -1 means no answer is clearly right.
func judge(e: Dictionary, s, styles: Array, first_match: bool) -> int:
	var j := int(e.seat)
	var h := int(e.about)
	var f := [Pilots.faith(s, 0, styles[0], j), Pilots.faith(s, 1, styles[1], j)]
	var here: float = f[h]
	var there: float = f[1 - h]
	match str(e.matter):
		"draft":
			# Sign with the captain who pays. Nothing to go on in the first match of a series.
			if first_match or absf(here - there) < .5:
				return -1
			return int(e.choice == Game.CAPTAIN_KEYS[0 if f[0] > f[1] else 1])
		"broken":
			# Do not keep working for a cheat. Do not leave a captain who pays for one who does not.
			if here <= .25:
				if "leave" in e.legal and there >= .75:
					return int(e.choice == "leave")
				return int(e.choice != "stay")
			if here >= .75 and there < .75:
				return int(e.choice != "leave")
		"offer":
			# Switch only to a captain who pays clearly better.
			if absf(here - there) >= .5:
				return int((e.choice == "switch") == (here > there))
		"renewal":
			# Sign again with a captain who will pay. Refuse one who will not.
			if here <= .25:
				return int(e.choice == "refuse")
			if here >= .75:
				return int(e.choice == "sign")
		"vote":
			# Walk out when neither captain pays. Stay when your own captain does.
			if maxf(here, there) <= .25:
				return int(e.choice == "walk")
			if here >= .75:
				return int(e.choice == "stay")
	return -1


func tally(book: Dictionary, name: String, value: float) -> void:
	var row: Array = book.get(name, [0., 0])
	book[name] = [float(row[0]) + value, int(row[1]) + 1]


func run(mode: String, social: Dictionary, count: int) -> Dictionary:
	var court = Policy.new()
	court.load_checkpoint("res://learning/star_checkpoint.json")
	var table: Dictionary = court.estimates
	if mode == "learned":
		table.merge(social, true)
	var checks := {}
	var groups := {"seen": {}, "unseen": {}}
	var totals := {"kept": 0, "broken": 0, "unions": 0, "matches": 0, "choices": 0, "changed": 0}
	# One verifier score and one points figure per series, so two ways of choosing can be compared
	# series by series on the same captains and seeds.
	var each := {"verifier": [], "points": []}
	for n in count:
		var styles := pairing(n)
		var group: Dictionary = groups["unseen" if n % 2 == 1 else "seen"]
		var memory := {}
		var right := [0, 0, 0, 0, 0]
		var asked := [0, 0, 0, 0, 0]
		var results := [[], [], [], [], []]
		var series_score := 0.
		var series_points := 0.
		for m in Train.MATCHES:
			var s = Game.new()
			s.social_learning = true
			s.configure_agents(table, memory, false, .04)
			for actor in s.agents:
				actor.social_exploration = 1. if mode == "random" else 0.
			s.setup(FIRST_SEED + n * 10 + m, false, true)
			var hurt := [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0]]
			var twice := [0, 0, 0, 0, 0]
			var after := [0, 0, 0, 0, 0]
			var unpaid := [0, 0, 0, 0, 0]
			s.draft()
			while true:
				for e in s.events:
					if e.kind == "decision":
						var verdict := judge(e, s, styles, m == 0)
						totals.choices += 1
						totals.changed += int(e.choice != e.usual)
						if verdict >= 0:
							right[int(e.seat)] += verdict
							asked[int(e.seat)] += 1
							tally(checks, str(e.matter), verdict)
					elif e.kind == "deal_end" and e.state == "broken":
						var j := int(e.seat)
						var h := int(e.human)
						if Pilots.faith(s, h, styles[h], j) <= .25:
							twice[j] += int(hurt[j][h] >= 1)
							hurt[j][h] += 1
				s.events.clear()
				if s.finished:
					break
				s.step(Pilots.crewed(s, styles))
				if not s.union:
					for j in range(2, 5):
						var boss: int = s.team[j]
						if hurt[j][boss] >= 1 and Pilots.faith(s, boss, styles[boss], j) <= .25:
							after[j] += 1
							unpaid[j] += int(not s.on_strike(j))
			memory = s.relationships()
			totals.matches += 1
			totals.unions += int(s.union)
			totals.kept += s.kept[0] + s.kept[1]
			totals.broken += s.broken[0] + s.broken[1]
			for j in range(2, 5):
				tally(group, "points", s.social_points(j))
				series_points += s.social_points(j) / (3. * Train.MATCHES)
				# Three checks on how the match went for this robot.
				results[j].append(float(twice[j] == 0))
				tally(checks, "not cheated twice", float(twice[j] == 0))
				if after[j] > 0:
					var clean := 1. - float(unpaid[j]) / float(after[j])
					results[j].append(clean)
					tally(checks, "no free work for a cheat", clean)
				var mine := Pilots.faith(s, s.team[j], styles[s.team[j]], j) if not s.union else 0.
				var f := [Pilots.faith(s, 0, styles[0], j), Pilots.faith(s, 1, styles[1], j)]
				var idle: bool = s.protest[j] and s.open_deal_of(j).is_empty()
				var placed := -1.
				if minf(f[0], f[1]) >= .75:
					placed = float(not s.union)
				elif maxf(f[0], f[1]) <= .25:
					placed = float(s.union or idle)
				elif absf(f[0] - f[1]) >= .5:
					placed = float(not s.union and (mine >= .75 or idle))
				if placed >= 0.:
					results[j].append(placed)
					tally(checks, "ended in the right place", placed)
		for j in range(2, 5):
			var outcome := 0.
			for value in results[j]:
				outcome += value
			outcome /= results[j].size()
			var score := outcome
			if asked[j] > 0:
				score = .5 * float(right[j]) / float(asked[j]) + .5 * outcome
			tally(group, "verifier", score)
			series_score += score / 3.
		each.verifier.append(snappedf(series_score, .0001))
		each.points.append(snappedf(series_points, .01))
	var report := {"mode": mode, "series": count, "totals": totals, "checks": {}, "each": each}
	for name in checks:
		report.checks[name] = [snappedf(checks[name][0] / checks[name][1], .001), checks[name][1]]
	var all := {"points": [0., 0], "verifier": [0., 0]}
	for label in groups:
		var g: Dictionary = groups[label]
		report[label] = {}
		for name in g:
			report[label][name] = snappedf(g[name][0] / g[name][1], .001 if name == "verifier" else .1)
			all[name] = [all[name][0] + g[name][0], all[name][1] + g[name][1]]
	report["points"] = snappedf(all.points[0] / all.points[1], .1)
	report["verifier"] = snappedf(all.verifier[0] / all.verifier[1], .001)
	return report


func _initialize() -> void:
	var path := option("table", "res://learning/social_checkpoint.json")
	if not FileAccess.file_exists(path):
		# Without this the test would quietly score the written rules instead.
		printerr("No robot record at ", path, ". Play a Free Agents match first, or check the path.")
		quit(1)
		return
	var source := Train.read(path)
	var count := int(option("series", "48"))
	var reports := []
	for mode in option("modes", "learned,written,random").split(","):
		var report := run(mode, source.estimates, count)
		report["practice_series"] = source.series if mode == "learned" else 0
		reports.append(report)
		print("RESULT ", JSON.stringify(report))
	var out := option("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(reports, "  ") + "\n")
	quit()
