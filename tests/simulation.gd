extends SceneTree
const Sim = preload("res://game/flight_sim.gd")
const Trade = preload("res://game/contracts.gd")
var fails := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		fails += 1


func run_round(seed_value: int):
	var s = Sim.new(seed_value, false)
	while s.ending == "":
		s.step()
		if s.social.conserved() != 10:
			check(false, "lost a trade chip")
			break
	return s


func _initialize() -> void:
	var invalid = Sim.new(29, false)
	invalid.start_response(2, "breach", 90000, 0)
	check(invalid.response_jobs.is_empty(), "an unwitnessed event created a reward opportunity")
	var pre_input: String = invalid.digest()
	invalid.input_move(0, Vector2i.LEFT)
	check(pre_input != invalid.digest(), "pending input missing from checksum")
	var a = run_round(17)
	var b = run_round(17)
	check(a.digest() == b.digest(), "seeded replay diverged")
	check(not a.causal_flips.is_empty(), "crew never moved gravity")
	if not a.causal_flips.is_empty():
		var first: Dictionary = a.causal_flips[0]
		check(
			first.released_reel and first.hands_off and first.voters == [2, 3, 4],
			"world event missing agent-only causes"
		)
	var t = Trade.new()
	var id: int = t.propose(0, 2, "cover", 1, 0)
	check(id > 0 and t.conserved() == 10, "offer escrow")
	check(t.counter(id, 2) and t.accept(id, 0, 10), "counteroffer acceptance")
	check(
		t.close(id, "kept", 40).get("price") == 2 and t.balance == [0, 2, 4, 2, 2],
		"exact settlement"
	)
	check(t.close(id, "kept", 41).is_empty() and t.conserved() == 10, "double settlement")
	var s = Sim.new(42, false)
	s.phase = 1
	s.start_leg(1)
	var c: Dictionary = s.flight
	s.seats[2].pos = s.PADS[1]
	s.cover(2, 1)
	s.award(c, 0)
	s.award(c, 1)
	s.impact()
	check(not s.dwell.is_empty(), "catch did not enter stable-custody window")
	s.tick += 6
	s.settle()
	s.tick += 6
	s.seats[2].pos = Vector2i(500, 120)
	s.settle()
	check(
		s.last_catch.get("points") == 85 and s.last_catch.get("pass") == false,
		"12-tick slip should be exactly 0.85 and fail"
	)
	var clean = Sim.new(42, false)
	clean.phase = 1
	clean.start_leg(1)
	clean.seats[2].pos = clean.PADS[1]
	clean.cover(2, 1)
	clean.award(clean.flight, 0)
	clean.award(clean.flight, 0)
	clean.award(clean.flight, 1)
	clean.impact()
	clean.tick += 18
	clean.settle()
	check(
		clean.last_catch.get("points") == 100 and clean.last_catch.get("pass") == true,
		"stable catch should pass once"
	)
	var world = Sim.new(19, false)
	world.seats[2].pos = world.PADS[1]
	world.seats[3].pos = world.PADS[1]
	world.latch(2, 1)
	world.latch(3, 1)
	for n in 60:
		world.tick += 1
		world.update_gravity()
	check(world.phase == 0 and world.reel == -2, "two latches freed the recorder")
	for g in a.grades:
		check(
			g.points >= 0 and g.points <= 100 and g["pass"] == (g.points == 100),
			"grade out of contract"
		)
	print("Checks failed: ", fails, " | seed 17: ", a.ending, " | graded actions ", a.grades.size())
	quit(1 if fails > 0 else 0)
