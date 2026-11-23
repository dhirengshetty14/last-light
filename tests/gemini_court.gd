extends SceneTree
## Exercise three overlapping asynchronous turns using synthetic game service replies.
const Court = preload("res://game/star_match.gd")
const Coach = preload("res://game/gemini_coach.gd")
const Replay = preload("res://tools/replay_court.gd")


class FakeCoach:
	extends Coach
	var requests: Dictionary = {}

	func dispatch(slot: int, body: Dictionary) -> Error:
		requests[slot] = body
		return OK


var failures := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", msg)


func _initialize() -> void:
	run.call_deferred()


func answer(slot: int) -> PackedByteArray:
	var plan := {}
	for phase in Coach.OPTIONS:
		plan[phase] = {
			"move": Coach.OPTIONS[phase][0],
			"reason": "Cover the lane for " + Coach.ROLES[slot] + "."
		}
	return (
		JSON
		. stringify(
			{
				"plan": plan,
				"model_version": "fixture",
				"input_tokens": 52,
				"output_tokens": 38,
				"total_tokens": 90
			}
		)
		. to_utf8_buffer()
	)


func run() -> void:
	var world = Court.new()
	world.setup(87, false)
	var radio = FakeCoach.new()
	root.add_child(radio)
	radio.configure("fixture-only")
	radio.next_ms = [0, 0, 0]
	var packets: Array = radio.poll(world)
	check(packets.size() == 3, "all three nonblocking dispatches")
	for i in 3:
		var obs: Dictionary = packets[i].observation
		check(
			obs.name == Coach.ROLES[i] and obs.goal == world.agents[i].GOALS[i], "own observation"
		)
		check(
			not JSON.stringify(obs).contains("points") and not obs.has("estimates"), "reward hidden"
		)
		check(
			(
				radio.requests[i].name == Coach.ROLES[i]
				and not radio.requests[i].has("systemInstruction")
			),
			"structured request"
		)
	check(radio.poll(world).is_empty(), "no overlapping calls for same robot")
	check(
		Coach.validate_plan({"defend": {"move": "cheat", "reason": "score"}}).is_empty(),
		"reject incomplete playbook"
	)
	check(
		Coach.decode('{"candidates":[]}'.to_utf8_buffer()).is_empty(), "reject empty API response"
	)
	var args := OS.get_cmdline_user_args()
	var path := str(args[0]) if not args.is_empty() else "user://gemini-fixture.jsonl"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(
		JSON.stringify(
			{
				"kind": "header",
				"origin": "fixture",
				"input_schema": 1,
				"game": "last-light-v12",
				"court_version": 12,
				"moving_passes": true,
				"run": "gemini-test-87",
				"seed": 87,
				"open_crews": false,
				"starting_policy": {},
				"starting_relationships": {},
				"gemini_models": radio.models
			}
		)
	)
	var applied := {}
	var outcomes := {}
	for t in 500:
		if t == 2:
			for i in [2, 0, 1]:
				radio._reply(HTTPRequest.RESULT_SUCCESS, 200, [], answer(i), i)
		if t > 0:
			packets = radio.poll(world)
		world.step([{}, {}], packets)
		for e in world.events:
			check(
				(
					not JSON.stringify(e).contains("private test marker")
					and not JSON.stringify(e).contains("fixture-only")
				),
				"no hidden text or secret in logs"
			)
			if (
				e.kind == "response_intent"
				and e.has("gemini")
				and e.gemini.disposition == "applied"
			):
				check(
					(
						e.choice == e.gemini.proposal
						and e.reason.ends_with(Coach.ROLES[e.seat - 2] + ".")
					),
					"reply goes to its own robot and executes"
				)
				applied[e.source] = e.seat
			if e.kind == "action_grade" and e.type == "response" and applied.has(e.source):
				outcomes[e.seat] = true
			f.store_line(JSON.stringify(e, "", true, true))
		world.events.clear()
		if world.finished:
			break
	f.store_line(
		JSON.stringify({"kind": "footer", "tick": world.tick, "completed": world.finished})
	)
	f.close()
	check(outcomes.size() == 3, "Gemini decisions for every robot reach deterministic verifier")
	var replay = Replay.new()
	check(replay.verify(path), "replay cloud-conditioned match without network")
	replay.free()
	var actor = world.agents[0]
	actor.change_team()
	var ticket = {
		"actor": 2,
		"id": 9,
		"team_epoch": 0,
		"asked_tick": world.tick,
		"model": Coach.MODEL,
		"state": "request"
	}
	actor.accept_packet(ticket, world.tick)
	ticket.state = "ready"
	ticket.plan = Coach.decode(answer(0)).plan
	check(
		actor.accept_packet(ticket, world.tick) == "stale" and actor.model_plan.is_empty(),
		"old alliance cannot apply a reply"
	)
	ticket.id = 10
	ticket.team_epoch = actor.team_epoch
	ticket.state = "request"
	actor.accept_packet(ticket, world.tick)
	ticket.state = "ready"
	actor.accept_packet(ticket, world.tick)
	actor.local_preference = "screen"
	actor.record_grade("trial", "press", 10)
	actor.record_grade("trial", "press", 10)
	check(
		(
			actor.advice("defend", "trial", ["screen", "press"], world.tick).disposition
			== "learner_override"
		),
		"verified failures can override model"
	)
	check(
		actor.advice("defend", "trial", ["screen"], world.tick).disposition == "illegal_here",
		"illegal actions masked"
	)
	check(actor.advice("defend", "trial", ["press"], world.tick + 721).is_empty(), "plan expires")
	radio.next_ms = [0, 0, 0]
	radio.poll(world)
	radio._reply(HTTPRequest.RESULT_SUCCESS, 403, [], PackedByteArray(), 0)
	radio._reply(HTTPRequest.RESULT_TIMEOUT, 0, [], PackedByteArray(), 1)
	var closed: Array = radio.close()
	check(
		(
			closed.size() == 3
			and closed[0].state == "http_error"
			and closed[1].state == "timeout"
			and closed[2].state == "cancelled"
		),
		"separate error, timeout and cancellation telemetry"
	)
	radio.free()
	print("Gemini fixture: verified robots ", outcomes.keys(), " failures ", failures)
	quit(int(failures > 0))
