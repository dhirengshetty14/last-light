extends SceneTree
## Reconstruct a recorded human match from its initial estimates and input edges.
const Game = preload("res://game/star_match.gd")


func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for k in a.size():
			if not equivalent(a[k], b[k]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	return a == b


func verify(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var head: Variant = JSON.parse_string(f.get_line())
	if not head is Dictionary or head.get("input_schema") != 1:
		return false
	var s = (
		Game.new()
		if head.get("court_version", 5) >= 6
		else preload("res://tools/court_rules_v5.gd").new()
	)
	if head.get("court_version", 5) >= 6 and head.get("court_version", 5) < 9:
		# Versions 6 to 8 were played on the earlier, smaller court.
		s.call("old_court")
	if head.get("court_version", 5) == 9:
		# Version 9 played two or three minutes, and Rivals and Open Crews ended at three goals.
		s.set("long_match", false)
	if head.get("free_agents", false):
		# Dynamic calls: the frozen version 5 court has neither the third argument nor a draft.
		s.call("setup", int(head.seed), false, true)
	else:
		s.setup(int(head.seed), head.open_crews)
	if head.get("court_version", 5) >= 6:
		s.set("powers", head.get("court_version", 5) >= 7)
		s.set("social_learning", head.get("social_learning", false))
	s.moving_passes = head.get("moving_passes", false)
	s.relay_rules = head.get("dock_relay", false)
	s.legacy_replay = not head.has("starting_relationships")
	s.configure_agents(head.starting_policy, head.get("starting_relationships", {}))
	if head.get("free_agents", false):
		# The draft reads each robot's restored memory, so it runs after the policy is loaded.
		s.call("draft")
	var inputs: Dictionary = {}
	var expected: Array = []
	var remote: Dictionary = {}
	var closing: Dictionary = {}
	var final_tick := 0
	var sealed := false
	while f.get_position() < f.get_length():
		var event: Variant = JSON.parse_string(f.get_line())
		if not event is Dictionary:
			return false
		if event.kind == "footer":
			final_tick = int(event.tick)
			sealed = true
			break
		expected.append(event)
		if event.kind == "model_transport":
			var stream: Dictionary = closing if event.after_step else remote
			var t := int(event.tick)
			if not stream.has(t):
				stream[t] = []
			stream[t].append(event.packet)
		if event.kind == "human_input":
			var at := int(event.tick)
			if not inputs.has(at):
				inputs[at] = []
			inputs[at].append(event)
	# Free Agents runs a longer clock and adds time when the robots form a union.
	if not sealed or final_tick > 60 * 400:
		return false
	var stick := [Vector2.ZERO, Vector2.ZERO]
	var cursor := 0
	for at in range(1, final_tick + 1):
		var cmd := [{}, {}]
		for edge in inputs.get(at, []):
			var seat := int(edge.seat)
			stick[seat] = Vector2(edge.move[0], edge.move[1])
			for button in edge.buttons:
				cmd[seat][button] = true
		for seat in 2:
			cmd[seat]["move"] = stick[seat]
		s.step(cmd, remote.get(at, []))
		s.apply_model_packets(closing.get(at, []), true)
		for actual in s.events:
			if cursor >= expected.size() or not equivalent(actual, expected[cursor]):
				printerr("First divergent event at tick ", at, ", sequence ", cursor + 1)
				return false
			cursor += 1
		s.events.clear()
	print("Replayed ", cursor, " events across ", s.tick, " ticks. Final score ", s.goals)
	return cursor == expected.size()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	quit(0 if args.size() == 1 and verify(args[0]) else 1)
