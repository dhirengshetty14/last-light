extends SceneTree
## Do the robots stop handing the star to pilots who keep robbing them?
##
## Both pilots play the habit seen in live play on court 10: run at whichever robot has the star and
## dash into it as soon as the dash can reach, then carry the star to the ring (dashing clear when a
## robot closes in) and shoot. Every series is three Rivals matches in a row, and the robots carry
## what they learned from one match into the next, as they do on a player's Mac.
##
## Four kinds of robot face the same seeds and the same pilots:
##   learning  the court as shipped: every decision is graded and the grade changes the next choice
##   frozen    the same court and checkpoint with learning switched off
##   court 12  the robots before version 13: the old outcome checks and the checkpoint trained on
##             court 9
##   court 11  the robots before version 12, on that same old checkpoint
##
## The verifier reads only the court's own event log. For each series it checks:
##   0.40  steals in match 3 are at most 80% of match 1 (learning across matches)
##   0.40  in match 1, steals in the last two minutes are at most 80% of the first two (within one)
##   0.20  in match 1, robots under pressure pick a move that got them robbed in that situation less
##         often after half time than before
## A series scores the sum of the checks it passes, from 0 to 1. The report also gives the paired
## difference between learning and frozen robots on the same seeds, with its standard error.
const Game = preload("res://game/star_match.gd")
const Policy = preload("res://learning/star_policy.gd")
const MATCHES := 3
const KINDS := ["learning", "frozen", "court 12", "court 11"]


static func thieves(s) -> Array:
	var inputs := [{}, {}]
	for i in 2:
		var p: Vector2 = s.pos[i]
		var dest: Vector2 = s.floor_ball()
		var ready: bool = s.tick >= s.cooldown[i]
		if s.owner == i:
			dest = s.goal(i)
			var marker := 99.
			for j in range(2, 5):
				marker = minf(marker, p.distance_to(s.pos[j]))
			if p.distance_to(s.goal(i)) <= s.shot_range(i) - .12:
				inputs[i]["shoot"] = true
			elif marker < 1.5 and ready:
				# Nell's Ferry Run keeps the star; Rafi's dash at least gets clear.
				inputs[i]["dash"] = true
			elif marker < 1.1 and s.pos[1 - i].x > p.x + 1.5:
				inputs[i]["pass"] = true
		elif s.owner >= 0 and s.team[s.owner] == s.team[i]:
			var lane := 2.4 if s.pos[s.owner].y < 0 else -2.4
			dest = Vector2(clampf(s.pos[s.owner].x + 3.2, -s.bounds.x, s.bounds.x - 1.), lane)
		elif s.owner < 0 and s.target == i:
			dest = s.reception_point
		elif s.owner >= 0:
			# The habit: run at the carrier and dash into it as soon as the dash can reach.
			dest = s.pos[s.owner] + Vector2(s.vel[s.owner]) * .15
			var reach: float = [2.3, 1.4][i]
			inputs[i]["dash"] = p.distance_to(dest) < reach and ready
		inputs[i]["move"] = p.direction_to(dest) if p.distance_to(dest) > .14 else Vector2.ZERO
	return inputs


static func play(kind: String, seed_value: int, weights: Dictionary, memory: Dictionary) -> Dictionary:
	var s = Game.new()
	if kind == "court 11":
		s.steady_pace = false
		s.wary_robots = false
	if kind in ["court 11", "court 12"]:
		s.team_outcomes = false
		s.fair_play = false
		s.team_talk = false
	s.setup(seed_value, false)
	s.configure_agents(weights, memory, kind != "frozen", .04)
	var steals_by_minute := [0, 0, 0, 0]
	var burned_picks := [[0, 0], [0, 0]]
	var counts := {
		"lessons": 0, "jukes": 0, "graded": 0, "points": 0, "passes": 0, "instant": 0,
		"won_back": 0, "completed": 0
	}
	var gained := {}
	while not s.finished:
		var burned := {}
		for actor in s.agents:
			burned.merge(actor.burned)
		s.step(thieves(s))
		for e in s.events:
			match e.kind:
				"custody":
					gained[e.seat] = e.tick
					if e.method == "steal" and e.seat < 2 and int(e["from"]) >= 2:
						steals_by_minute[mini(3, int(e.tick / 3600))] += 1
					# The robots took the star off the pilots: a steal or an interception.
					if e.seat >= 2 and int(e["from"]) >= 0 and int(e["from"]) < 2:
						counts.won_back += int(e.method == "steal" or e.intercepted)
				"throw":
					if e.seat >= 2 and e.action == "pass" and gained.has(e.seat):
						counts.passes += 1
						counts.instant += int(e.tick - gained[e.seat] <= 15)
				"lesson":
					counts.lessons += 1
				"juke":
					counts.jukes += 1
				"response_intent":
					if e.has("pressure") and burned.has(e.context):
						var half := int(e.tick >= 7200)
						burned_picks[half][0] += int(e.choice == burned[e.context])
						burned_picks[half][1] += 1
				"action_grade":
					if e.type == "response":
						counts.graded += 1
						counts.points += int(e.points)
					elif e.type == "court_throw" and e.seat >= 2 and e.action == "pass":
						counts.completed += int(e.pass)
		s.events.clear()
	return {
		"steals": steals_by_minute,
		"goals": s.goals.duplicate(),
		"burned_picks": burned_picks,
		"counts": counts,
		"weights": s.learned_weights(),
		"memory": s.relationships()
	}


static func total(row: Array) -> int:
	var n := 0
	for v in row:
		n += int(v)
	return n


static func mean_and_error(values: Array) -> Array:
	var n := float(values.size())
	var mean := 0.
	for v in values:
		mean += float(v)
	mean /= n
	var spread := 0.
	for v in values:
		spread += pow(float(v) - mean, 2)
	var error := sqrt(spread / maxf(1., n - 1.) / n)
	return [snappedf(mean, .01), snappedf(error, .01)]


func _initialize() -> void:
	var series_count := 16
	# The shipped results live in learning/steal_eval.json; a quick check writes somewhere else.
	var out_path := "res://learning/steal_eval.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--series="):
			series_count = int(arg.trim_prefix("--series="))
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var start = Policy.new()
	start.load_checkpoint("res://learning/star_checkpoint.json")
	# What the robots shipped with before version 13, for the two older kinds.
	var earlier = Policy.new()
	earlier.load_checkpoint("res://learning/star_checkpoint_court9.json")
	var report := {"series": series_count, "matches_per_series": MATCHES, "first_seed": 91000}
	var steals := {}
	for kind in KINDS:
		var scores := []
		var per_series := []
		var goals := [0, 0, 0]
		var robot_goals := [0, 0, 0]
		var halves := [0, 0]
		var counts := {
			"lessons": 0, "jukes": 0, "graded": 0, "points": 0, "passes": 0, "instant": 0,
			"won_back": 0, "completed": 0
		}
		var shipped = earlier if kind in ["court 11", "court 12"] else start
		for n in series_count:
			var weights: Dictionary = shipped.estimates.duplicate(true)
			var memory := {}
			var matches := []
			for m in MATCHES:
				var r := play(kind, 91000 + n * 7 + m, weights, memory)
				weights = r.weights
				memory = r.memory
				matches.append(r)
				goals[m] += int(r.goals[0])
				robot_goals[m] += int(r.goals[1])
				for key in counts:
					counts[key] += int(r.counts[key])
			var one: Dictionary = matches[0]
			var early := int(one.steals[0]) + int(one.steals[1])
			var late := int(one.steals[2]) + int(one.steals[3])
			halves[0] += early
			halves[1] += late
			var picks: Array = one.burned_picks
			var before := float(picks[0][0]) / maxf(1., float(picks[0][1]))
			var after := float(picks[1][0]) / maxf(1., float(picks[1][1]))
			var score := 0.
			score += .4 * float(total(matches[2].steals) <= .8 * total(one.steals))
			score += .4 * float(late <= .8 * early)
			score += .2 * float(picks[0][1] > 0 and picks[1][1] > 0 and after < before)
			scores.append(score)
			per_series.append([total(matches[0].steals), total(matches[1].steals), total(matches[2].steals)])
		steals[kind] = per_series
		var by_match := []
		for m in MATCHES:
			var column := []
			for row in per_series:
				column.append(row[m])
			by_match.append(mean_and_error(column))
		var change := []
		for row in per_series:
			change.append(int(row[2]) - int(row[0]))
		report[kind] = {
			"verifier_score": mean_and_error(scores),
			"steals_per_match": by_match,
			"match_3_minus_match_1": mean_and_error(change),
			"match_1_steals_first_vs_last_two_minutes": halves,
			"pilot_goals_per_match": [
				snappedf(goals[0] / float(series_count), .01),
				snappedf(goals[1] / float(series_count), .01),
				snappedf(goals[2] / float(series_count), .01)
			],
			"robot_goals_per_match": [
				snappedf(robot_goals[0] / float(series_count), .01),
				snappedf(robot_goals[1] / float(series_count), .01),
				snappedf(robot_goals[2] / float(series_count), .01)
			],
			"won_back_per_match": snappedf(counts.won_back / float(series_count * MATCHES), .01),
			"robot_passes_completed_per_match": snappedf(
				counts.completed / float(series_count * MATCHES), .01
			),
			"lessons_said": counts.lessons,
			"jukes": counts.jukes,
			"mean_decision_grade": snappedf(float(counts.points) / maxf(1., counts.graded) / 100., .001),
			"robot_passes_within_quarter_second_of_getting_the_star": snappedf(
				float(counts.instant) / maxf(1., counts.passes), .001
			)
		}
		print(kind, " ", JSON.stringify(report[kind]))
	for m in [0, 2]:
		var paired := []
		for n in series_count:
			paired.append(int(steals["learning"][n][m]) - int(steals["frozen"][n][m]))
		report["learning_minus_frozen_match_%d" % (m + 1)] = mean_and_error(paired)
	print("paired ", report["learning_minus_frozen_match_1"], " ", report["learning_minus_frozen_match_3"])
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  ") + "\n")
	quit()
