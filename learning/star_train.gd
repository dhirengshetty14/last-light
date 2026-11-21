extends SceneTree
const Game = preload("res://game/star_match.gd")
const Policy = preload("res://learning/star_policy.gd")


## Four reproducible human styles: straight-line runner, passing pair, flank runner, turnover hunter.
static func drivers(s, style: int) -> Array:
	var inputs := [{}, {}]
	for i in 2:
		var p: Vector2 = s.pos[i]
		var dest: Vector2 = s.floor_ball()
		if s.owner == i:
			dest = s.goal(i)
			if style == 2 and p.x < 2.55:
				dest.y = 1.65 if i == 0 else -1.65
			var in_range := p.distance_to(s.goal(i)) <= 2.68
			inputs[i]["shoot"] = in_range
			inputs[i]["dash"] = not in_range and s.tick % 90 < 10 and style >= 2
			inputs[i]["pass"] = (
				style == 1 and not in_range and s.tick % 49 == i and s.partner(i) >= 0
			)
		elif s.owner >= 0 and s.team[s.owner] == s.team[i]:
			dest = Vector2(
				clampf(s.pos[s.owner].x + 2.1, -4.6, 4.45), 1.4 if s.pos[s.owner].y < 0 else -1.4
			)
		elif s.owner >= 0:
			inputs[i]["dash"] = p.distance_to(dest) < (.94 if style == 3 else .67)
		inputs[i]["move"] = p.direction_to(dest) if p.distance_to(dest) > .14 else Vector2.ZERO
	return inputs


func series(model, count: int, base: int, adapted: bool, windows: Array[int]) -> Dictionary:
	var gold := 0
	var blue := 0
	var attempts := 0
	var full := 0
	var wins := 0
	var surges := 0
	var worst: Dictionary = {}
	var rivals := {"matches": 0, "blue_wins": 0}
	var by_robot := {"Pip": 0, "Morrow": 0, "Zip": 0}
	for episode in count:
		var s = Game.new()
		s.setup(base + episode, episode % 3 == 1)
		s.configure_agents(model.estimates, {}, adapted, model.exploration)
		s.sample_time = episode < 4
		while not s.finished:
			var c := drivers(s, episode % 4)
			if s.open_crews and s.tick % 180 == 50:
				c[0]["invite"] = true
			s.step(c)
			for e in s.events:
				if e.kind == "action_grade" and e.type == "response":
					attempts += 1
					by_robot[Game.NAMES[e.seat]] += 1
					full += int(e.pass)
					if not e.pass:
						worst[e.action] = int(worst.get(e.action, 0)) + 1
				if e.kind == "aurora":
					surges += 1
			s.events.clear()
		if adapted:
			model.estimates = s.learned_weights()
		if not s.open_crews:
			rivals.matches += 1
			rivals.blue_wins += int(s.goals[1] > s.goals[0])
		blue += s.goals[1]
		gold += s.goals[0]
		wins += int(s.goals[1] > s.goals[0])
		windows.append_array(s.timings)
	return {
		"episodes": count,
		"rivals": rivals,
		"blue_wins": wins,
		"blue_goals": blue,
		"gold_goals": gold,
		"agent_events": surges,
		"verified_actions": attempts,
		"graded_by_robot": by_robot,
		"full_passes": full,
		"failures_by_action": worst
	}


func write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")


func _initialize() -> void:
	var p = Policy.new()
	var timings: Array[int] = []
	p.exploration = .21
	var train := series(p, 120, 7000, true, timings)
	write(
		"res://learning/star_checkpoint.json",
		{"schema": "response-policy-v1", "episodes": 120, "estimates": p.estimates}
	)
	var cold = Policy.new()
	cold.exploration = .04
	p.exploration = .04
	timings.clear()
	var base := series(cold, 32, 52001, false, timings)
	var eval_result := series(p, 32, 52001, false, timings)
	timings.sort()
	var report := {
		"training": train,
		"untrained": base,
		"trained": eval_result,
		"held_out_start": 52001,
		"timing_samples": timings.size(),
		"policy_callback_p95_us": timings[int(timings.size() * .95)],
		"policy_callback_p99_us": timings[int(timings.size() * .99)]
	}
	write("res://learning/star_eval.json", report)
	print(JSON.stringify(report))
	quit()
