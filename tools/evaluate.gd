extends SceneTree
const Sim = preload("res://game/flight_sim.gd")
const Partners = preload("res://learning/train.gd")
const FIRST_SEED := 5017
const PAIRS := 45


func evaluate(storm: int, trained: bool) -> Dictionary:
	var tally := {
		"flights": PAIRS,
		"delivered": 0,
		"idle_flights": 0,
		"idle_agent_releases": 0,
		"response_full": 0,
		"response_attempts": 0,
		"catch_full": 0,
		"catch_attempts": 0
	}
	for n in PAIRS:
		var sim = Sim.new(FIRST_SEED + n, false, storm)
		if trained:
			sim.policy.load_checkpoint("res://learning/checkpoint.json")
		sim.policy.adaptive = false
		sim.policy.exploration = 0
		if n % 3 == 0:
			tally.idle_flights += 1
		while sim.ending.is_empty():
			if n % 3 != 0:
				Partners.drive_partner(sim, 0, n)
				Partners.drive_partner(sim, 1, n + 1)
			sim.step()
		if sim.ending in ["The herd answers", "The calf answers"]:
			tally.delivered += 1
		for flip in sim.causal_flips:
			if n % 3 == 0 and flip.released_reel and flip.hands_off:
				tally.idle_agent_releases += 1
		for grade in sim.grades:
			tally[grade.type + "_attempts"] += 1
			if grade["pass"]:
				tally[grade.type + "_full"] += 1
	return tally


func _initialize() -> void:
	var results := {}
	for storm in 2:
		results[["first_rescue", "ring_storm"][storm]] = {
			"prior": evaluate(storm, false), "trained": evaluate(storm, true)
		}
	var report := {
		"seeds": [FIRST_SEED, FIRST_SEED + PAIRS - 1],
		"same_partners": true,
		"policy_frozen": true,
		"results": results
	}
	var out := FileAccess.open("res://learning/evaluation.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  ") + "\n")
	out.close()
	print(JSON.stringify(results))
	quit()
