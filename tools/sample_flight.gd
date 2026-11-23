extends SceneTree
const Sim = preload("res://game/flight_sim.gd")
const Partners = preload("res://learning/train.gd")


func _initialize() -> void:
	var s = Sim.new(291, true)
	s.policy.load_checkpoint("res://learning/checkpoint.json")
	var original: Dictionary = s.policy.estimates.duplicate(true)
	while s.ending == "":
		Partners.drive_partner(s, 0, 2)
		Partners.drive_partner(s, 1, 3)
		s.step()
	var file := FileAccess.open("res://docs/sample-flight.jsonl", FileAccess.WRITE)
	file.store_line(
		JSON.stringify(
			{
				"kind": "header",
				"version": 2,
				"ruleset": Sim.RULESET,
				"run": "sample-291",
				"seed": 291,
				"checkpoint": original,
				"physics_hz": 60
			}
		)
	)
	for e in s.events:
		file.store_line(JSON.stringify(e))
	file.store_line(
		JSON.stringify(
			{"kind": "checkpoint", "tick": s.tick, "digest": s.digest(), "ending": s.ending}
		)
	)
	file.close()
	print(s.ending, " | ", s.events.size(), " recorded events")
	quit()
