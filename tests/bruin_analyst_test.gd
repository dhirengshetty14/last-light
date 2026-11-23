extends SceneTree
## Court version 13: the Bruin Analyst's advice reaches only its own robot, lifts the advised move,
## changes nothing when there is no advice, and replays exactly from the recording.
const Court = preload("res://game/star_match.gd")
const Analyst = preload("res://game/bruin_analyst.gd")
const Replay = preload("res://tools/replay_court.gd")
var failures := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", msg)


func _initialize() -> void:
	no_advice_plays_as_version_12()
	analyst_file()
	advised_match()
	quit(int(failures > 0))


func no_advice_plays_as_version_12() -> void:
	var a = Court.new()
	var b = Court.new()
	b.bruin_analyst = false
	a.setup(87, false)
	b.setup(87, false)
	for t in 900:
		a.step([{"move": Vector2(1, .2)}, {"dash": t % 50 == 0}])
		b.step([{"move": Vector2(1, .2)}, {"dash": t % 50 == 0}])
	# Version 13 notes the situation of each decision; apart from that, nothing may change.
	var noted := 0
	for e in a.events:
		if e.kind == "response_intent" and e.has("scene"):
			e.erase("scene")
			noted += 1
	check(noted > 0, "decisions record their situation")
	check(JSON.stringify(a.events) == JSON.stringify(b.events), "no advice plays as version 12")


func analyst_file() -> void:
	var fixture := "user://bruin-analyst-fixture.json"
	var f := FileAccess.open(fixture, FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{
				"schema": "bruin-analyst-v1",
				"seq": 1795468706238,
				"run": "this-match",
				"through_tick": 500,
				"advice":
				{
					"2":
					{
						"carry":
						{
							"prefer": "pass",
							"avoid": "flank",
							"reason": "flank went wrong",
							"scenes":
							{
								"near/coming/ahead/pressed": {"prefer": "evade", "avoid": "drive"},
								"far/going/ahead": {"prefer": "drive", "avoid": "pass"},
								"far/slow/ahead/free": {"prefer": "cheat", "avoid": "drive"}
							}
						}
					},
					"3": {"defend": {"prefer": "cheat", "avoid": "cut", "reason": "not a move"}},
				},
				"summary":
				{
					"2": {"robot": "Pip", "score": .51, "previous": .47},
					"3": {"robot": "Morrow", "score": .45, "previous": null}
				}
			}
		)
	)
	f.close()
	var sim = Court.new()
	sim.setup(87, false)
	var other = Analyst.new("another-match")
	other.path = fixture
	sim.tick = 600
	check(other.poll(sim).is_empty(), "advice about another match is ignored")
	var coach = Analyst.new("this-match")
	coach.path = fixture
	sim.tick = 10
	check(coach.poll(sim).is_empty(), "the analyst waits 3 s between reads")
	sim.tick = 600
	var packets: Array = coach.poll(sim)
	check(packets.size() == 1 and packets[0].actor == 2, "only legal advice becomes a packet")
	var kept: Array = packets[0].advice.carry.scenes.keys()
	kept.sort()
	check(
		kept == ["far/going/ahead", "near/coming/ahead/pressed"],
		"advice for a situation is kept only when its moves are legal"
	)
	var pip = sim.agents[0]
	pip.accept_analyst(packets[0], sim.tick)
	var legal := ["drive", "flank", "pass", "evade"]
	check(
		pip.analyst_bias("carry", "near/coming/ahead/pressed", legal, sim.tick) == {"evade": .04, "drive": -.04},
		"a robot uses the advice for its exact situation"
	)
	check(
		pip.analyst_bias("carry", "far/going/ahead/free/wall", legal, sim.tick) == {"drive": .04, "pass": -.04},
		"then to the broader situation"
	)
	check(
		pip.analyst_bias("carry", "far/going/behind/free", legal, sim.tick) == {"pass": .04, "flank": -.04},
		"otherwise it falls back to the advice for the phase"
	)
	sim.tick = 1200
	check(coach.poll(sim).is_empty(), "the same file is read once")
	check(
		coach.summary_line().contains("Pip 0.51") and coach.summary_line().contains("last match"),
		"final card line"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))


func advised_match() -> void:
	var world = Court.new()
	world.setup(87, false)
	# Pass a path to keep the advised recording, for example to load it with Bruin.
	var args := OS.get_cmdline_user_args()
	var path := str(args[0]) if not args.is_empty() else "user://bruin-analyst-replay.jsonl"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(
		JSON.stringify(
			{
				"kind": "header",
				"origin": "fixture",
				"input_schema": 1,
				"game": "last-light-v13",
				"court_version": 13,
				"moving_passes": true,
				"run": "%d-87" % (Time.get_unix_time_from_system() * 1000000),
				"seed": 87,
				"open_crews": false,
				"bruin_analyst": true,
				"starting_policy": {},
				"starting_relationships": {}
			}
		)
	)
	var tip := {}
	for phase in Analyst.OPTIONS:
		tip[phase] = {
			"prefer": Analyst.OPTIONS[phase][1],
			"avoid": Analyst.OPTIONS[phase][0],
			"reason": "fixture"
		}
	var results := {}
	var lifted := 0
	for t in 1500:
		var packets := []
		if t == 120:
			for seat in [2, 3, 4]:
				packets.append({"source": "bruin", "actor": seat, "id": 1, "advice": tip})
		if t == 121:
			packets.append({"source": "bruin", "actor": 2, "id": 1, "advice": tip})
		world.step([{"move": Vector2(1, .1)}, {"dash": t % 40 == 0}], packets)
		for e in world.events:
			if e.kind == "analyst_advice":
				results[e.result] = results.get(e.result, 0) + 1
			if e.kind == "response_intent" and e.has("analyst"):
				lifted += 1
				var lift: Dictionary = e.analyst.lift
				for move in lift:
					check(
						move in e.legal_choices and absf(absf(lift[move]) - .04) < 1e-6,
						"lift is small and only on legal moves"
					)
				check(t >= 120, "no lift before advice arrives")
			f.store_line(JSON.stringify(e, "", true, true))
		world.events.clear()
	f.store_line(JSON.stringify({"kind": "footer", "tick": world.tick, "completed": false}))
	f.close()
	check(results.get("available", 0) == 3, "each robot accepts its advice")
	check(results.get("superseded", 0) == 1, "repeated advice is ignored")
	check(lifted > 20, "robots weigh the advice in their decisions")
	var replay = Replay.new()
	check(replay.verify(path), "an advised match replays exactly")
	replay.free()
	if args.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Bruin Analyst: ", results, ", ", lifted, " advised decisions")
