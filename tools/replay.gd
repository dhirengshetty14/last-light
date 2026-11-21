extends SceneTree
const Sim = preload("res://game/flight_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass an absolute .jsonl flight path after --")
		quit(2)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	if not f:
		push_error("Cannot read flight")
		quit(2)
		return
	var inputs: Dictionary = {}
	var header: Dictionary = {}
	var final: Dictionary = {}
	while f.get_position() < f.get_length():
		var row = JSON.parse_string(f.get_line())
		if not row is Dictionary:
			continue
		match row.get("kind"):
			"header":
				header = row
			"checkpoint":
				final = row
			"human_move", "human_action":
				var tick := int(row.tick)
				if not inputs.has(tick):
					inputs[tick] = []
				inputs[tick].append(row)
	if header.is_empty() or final.is_empty():
		push_error("Flight is still open or incomplete")
		quit(2)
		return
	var version := int(header.get("version", 1))
	if version not in [1, 2] or (version == 2 and header.get("ruleset", "") != Sim.RULESET):
		push_error("This recording uses a different ruleset")
		quit(2)
		return
	var s = Sim.new(int(header.seed), false, int(header.get("difficulty", 0)))
	s.policy.estimates = header.checkpoint
	while s.tick < int(final.tick):
		for row in inputs.get(s.tick, []):
			if row.kind == "human_move":
				s.input_move(int(row.seat), Vector2i(int(row.x), int(row.z)))
			else:
				s.human_action(int(row.seat), row.verb, int(row.target), row.job)
		if s.ending != "":
			break
		s.step()
	for row in inputs.get(s.tick, []):
		if row.kind == "human_move":
			s.input_move(int(row.seat), Vector2i(int(row.x), int(row.z)))
		else:
			s.human_action(int(row.seat), row.verb, int(row.target), row.job)
	var ok: bool = (s.legacy_digest() if version == 1 else s.digest()) == final.digest
	print("Replayed ", s.tick, " ticks. State digest matches: ", ok)
	quit(0 if ok else 1)
