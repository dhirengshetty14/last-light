extends SceneTree
## A submitted policy contains numbers only. The verifier replays the real world under five starting conditions.
const Sim = preload("res://game/flight_sim.gd")
const Policy = preload("res://learning/response_policy.gd")
const SEEDS := [43, 79, 101, 154, 213]


class SubmittedResponse:
	extends Policy
	var verb := "guard"

	func choose(
		_context: String, legal: Array, preferred: String, _rng: RandomNumberGenerator
	) -> String:
		return verb if legal.has(verb) else preferred if legal.has(preferred) else str(legal[0])


func catch_window(cfg: Dictionary, world_seed: int) -> int:
	var sim = Sim.new(world_seed, false)
	sim.phase = 1
	sim.gravity = 1
	sim.seats[1].pos = Sim.PADS[1] + Vector2i(182 + world_seed % 77, 0)
	sim.start_leg(1)
	sim.flight.assigned = 1
	var arrival: int = sim.flight.end
	while sim.tick <= arrival + 18 and sim.last_catch.is_empty():
		var ticks_left: int = arrival - sim.tick
		var direction := Vector2i.ZERO
		if ticks_left < -int(cfg.hold):
			direction = Vector2i.RIGHT
		elif ticks_left <= int(cfg.lead) and ticks_left > 0:
			if sim.seats[1].pos.x > Sim.PADS[1].x + 28:
				direction = Vector2i.LEFT
			elif sim.seats[1].cover_until < arrival + 18:
				sim.human_action(1, "cover")
		sim.input_move(1, direction)
		sim.step(false)
	return int(sim.last_catch.get("points", 0))


func broken_promise(cfg: Dictionary, world_seed: int) -> int:
	var sim = Sim.new(world_seed, false)
	var policy := SubmittedResponse.new()
	policy.verb = Policy.CHOICES[int(cfg.choice)]
	sim.policy = policy
	sim.seats[2].pos = Sim.PADS[1] + Vector2i(148 + world_seed % 87, 18)
	for seat in [3, 4]:
		sim.seats[seat].pos = Sim.PADS[1]
		sim.latch(seat, 1)
	var pact: int = sim.social.propose(2, 0, "vote", 1, sim.tick)
	sim.respond_pact(0, "agree")
	sim.respond_pact(0, "break")
	for n in 447:
		if sim.tick >= int(cfg.delay) and sim.response_jobs.has(2):
			sim.set_job_plan(2, sim.response_jobs[2])
			sim.motor(2)
		sim.step(false)
	for grade in sim.grades:
		if grade.actor == 2 and grade.type == "response" and grade.trigger == "breach":
			return int(grade.points)
	return 0


func bounded(config: Dictionary, field: String, limit: int) -> bool:
	var value: Variant = config.get(field)
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value == floor(float(value))
		and value >= 0
		and value <= limit
	)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected task, policy JSON path and output path")
		quit(2)
		return
	var policy_file := (
		FileAccess.open(args[1], FileAccess.READ) if FileAccess.file_exists(args[1]) else null
	)
	var cfg: Variant = null
	if policy_file and policy_file.get_length() <= 2048:
		cfg = JSON.parse_string(policy_file.get_as_text())
	var points := 0
	if cfg is Dictionary and cfg.size() == 2:
		var catching: bool = (
			args[0] == "catch-window" and bounded(cfg, "lead", 235) and bounded(cfg, "hold", 90)
		)
		var breach: bool = (
			args[0] == "broken-promise" and bounded(cfg, "choice", 3) and bounded(cfg, "delay", 440)
		)
		if catching or breach:
			for seed_value in SEEDS:
				points += (
					catch_window(cfg, seed_value) if catching else broken_promise(cfg, seed_value)
				)
	var maximum := SEEDS.size() * 100
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	if not f:
		quit(2)
		return
	f.store_line(
		JSON.stringify({"score": float(points) / maximum, "all_pass": int(points == maximum)})
	)
	f.close()
	quit()
