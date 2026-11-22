extends SceneTree
const Game = preload("res://game/star_match.gd")
var failures := 0


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL ", label)


func court(crews := false):
	var s = Game.new()
	s.setup(814, crews)
	return s


func grade(s, category: String) -> Dictionary:
	for e in s.events:
		if e.kind == "action_grade" and e.type == category:
			return e
	return {}


func check_relay() -> void:
	for crews in [true, false]:
		var s = court(crews)
		s.cooldown.fill(160)
		s.tick = 20
		for receiver in [1, 0, 1]:
			var sender: int = s.owner
			check(s.launch(sender, true, receiver), "relay pass released")
			s.tick += 10
			s.possession(receiver, "catch")
			if receiver == 0:
				check(
					s.cooldown[0] == (s.tick if crews else 160),
					"second completed pass restores the crew dash"
				)
				check(s.cooldown[2] == 160, "opponent keeps its cooldown")
				s.cooldown[1] = 120
		check(s.cooldown[1] == 120, "third pass in possession cannot recharge repeatedly")
		check(s.relay_passes == (2 if crews else 0), "relay progress belongs to Open Crews")
		s.possession(2, "steal")
		check(s.relay_passes == 0, "steal breaks the passing sequence")
	var s = court(true)
	s.launch(0, true, 1)
	s.possession(1, "catch")
	s.launch(1, true, 0)
	s.possession(4, "catch")
	check(s.relay_passes == 0, "intercepted throw cannot complete relay")


func check_court_geometry() -> void:
	var game = court(true)
	game.team[2] = 0
	game.pos[2] = game.pos[0] + Vector2(.8, .4)
	game.step([{"pass": true}, {}])
	check(game.target == 1, "regular pass picks Rafi even with a closer machine ally")
	game.possession(1, "fixture")
	game.step([{}, {"pass": true}])
	check(game.target == 0, "second human can pass directly back to Nell")
	game.possession(0, "fixture")
	game.step([{"ally_pass": true}, {}])
	check(game.target == 2, "separate ally button reaches a recruited machine")
	game.team[2] = 1
	game.tick += 15
	game.throw_checks.flight = true
	game.possession(2, "catch")
	var turnover_grade: Dictionary = (
		game.events.filter(func(e): return e.kind == "action_grade").back()
	)
	check(
		not turnover_grade["pass"] and not turnover_grade.flags[3],
		"a receiver who switched sides cannot earn teammate credit"
	)
	var defend = court()
	defend.pos[0] = Vector2.ZERO
	defend.pos[2] = Vector2(.55, 0)
	defend.safe_until = 0
	defend.burst(2, Vector2.LEFT)
	defend.step([{"dash": true, "move": Vector2.UP}, {}])
	check(
		defend.owner == 0 and defend.dash_until[0] > defend.tick,
		"timed dodge protects the carrier from a live tackle"
	)
	for backwards in [false, true]:
		var rim = court()
		rim.launch(0, false)
		rim.ball = Vector3(
			Game.RING + (.04 if backwards else -.04), Game.HEIGHT, 0. if backwards else .61
		)
		rim.motion = Vector3(-5. if backwards else 5., 0, 0)
		rim.advance_ball()
		check(rim.goals == [0, 0], "backwards entry and clipping the rim cannot score")
		if not backwards:
			check(rim.motion.x < 0., "a clipped shot rebounds onto the deck")


func _initialize() -> void:
	check_court_geometry()
	check_relay()
	var moving = court()
	moving.pos[0] = Vector2(-3.5, -1.)
	moving.pos[1] = Vector2(.2, -1.)
	moving.vel[1] = Vector2(0., 3.65)
	moving.ball = moving.hand(0)
	moving.launch(0, true, 1)
	for t in 48:
		moving.tick += 1
		moving.pos[1] += moving.vel[1] * moving.DT
		moving.advance_ball()
		if moving.owner >= 0:
			break
	check(moving.owner == 1, "ballistic lead reaches a receiver sprinting across court")
	for seat in 2:
		var s = court()
		s.pos[seat] = Vector2(Game.RING - 1.78, -.5)
		s.possession(seat, "fixture")
		check(s.launch(seat, false), "legal human shot")
		check(not s.launch(seat, false), "airborne ball cannot launch twice")
		for t in 90:
			if s.goals[0] > 0:
				break
			s.advance_ball()
			s.tick += 1
		check(s.goals[0] == 1, "gold hoop can be scored by either seat")
		var verified := grade(s, "court_throw")
		check(verified.get("points", 0) == 100, "physical shot full verifier")
	var missed = court()
	missed.launch(0, false)
	for t in 120:
		missed.tick += 1
		missed.advance_ball()
		if missed.owner >= 0:
			break
	missed.grade_throw(false, false)
	check(
		missed.goals[0] == 0 and grade(missed, "court_throw").get("points", 100) < 100,
		"range failure"
	)
	var s = court(true)
	s.pos[2] = s.pos[0] + Vector2(.71, 0)
	s.invite(0)
	check(s.team[2] == 0, "Pip accepts")
	s.pos[2] = Vector2(-1.6, .85)
	s.pos[1] = Vector2(-3., -1.5)
	s.launch(0, true, 2)
	for t in 90:
		s.tick += 1
		s.advance_ball()
		if s.owner >= 0:
			break
	check(
		s.owner == 2 and not s.robot_chain and grade(s, "court_throw").get("points", 0) == 100,
		"human assist catches without AI-only credit"
	)
	s.tick += 90
	s.pos[0] = s.pos[2] + Vector2(.5, 0)
	s.invite(0)
	check(s.team[2] == 1, "human breaks deal")
	s.tick += 90
	s.invite(0)
	check(s.team[2] == 1, "Pip remembers broken deal")
	var rival = court()
	rival.pos[2] = rival.pos[0]
	rival.invite(0)
	check(rival.team[2] == 1, "opposition locked in rivals")
	var trade = court(true)
	trade.pos[2] = trade.pos[0] + Vector2(.60, 0)
	trade.invite(0)
	for n in 2:
		trade.pos[0] = Vector2(-1., .35)
		trade.pos[2] = Vector2(1.2, .35)
		trade.possession(0, "fixture")
		trade.launch(0, false)
	check(trade.team[2] == 1, "ignored openings trigger independent betrayal")
	var defensive = court()
	var traces := {}
	var awards := {}
	var world_event := false
	while not defensive.finished:
		defensive.step()
	for e in defensive.events:
		if e.kind == "response_intent":
			traces[e.source] = e
		if e.kind == "action_grade" and e.type == "response":
			check(
				traces.has(e.source) and not awards.has(e.source),
				"one grade per witnessed decision"
			)
			awards[e.source] = true
			check(
				(
					e.flags.size() == 5
					and e.points >= 0
					and e.points <= 100
					and e.pass == (e.points == 100)
					and e.pass == (false not in e.flags)
				),
				"deterministic all-check grading"
			)
		if e.kind == "aurora":
			world_event = true
	check(world_event, "agents alone can light the beacon")
	check(traces.size() == awards.size(), "all decisions settled on final whistle")
	var replay = court()
	while not replay.finished:
		replay.step()
	check(replay.events == defensive.events, "seeded replay matches full ledger")
	var model = Game.Policy.new()
	model.exploration = 0
	var rng = RandomNumberGenerator.new()
	var options := ["press", "cut"]
	check(model.choose("same", options, "press", rng) == "press", "preference before experience")
	for t in 4:
		model.observe("same", "press", 20)
		model.observe("same", "cut", 100)
	check(
		(
			model.choose("same", options, "press", rng) == "cut"
			and model.choose("other", options, "press", rng) == "press"
		),
		"verified outcomes change next choice only in matching context"
	)
	var personal = court(true)
	personal.pos[0] = Vector2.ZERO
	personal.pos[2] = Vector2(.5, 0)
	personal.pos[3] = Vector2(5., 1.8)
	personal.pos[4] = Vector2(-4.8, -1.8)
	personal.launch(0, true, 1)
	check(
		(
			personal.agents[0].scouting[0][1] == 1
			and personal.agents[1].scouting[0][1] == 0
			and personal.agents[2].scouting[0][1] == 0
		),
		"out-of-range robots do not inherit Pip's observation"
	)
	personal.invite(0)
	personal.tick += 90
	personal.invite(0)
	var next = court(true)
	next.configure_agents({}, personal.relationships())
	check(
		(
			next.agents[0].reputation[0] < 0
			and next.agents[0].reputation[1] >= 0
			and next.agents[1].reputation[0] == 0
		),
		"broken promise survives rematch, bound to one human and one robot"
	)
	check(next.agents[0].scouting[0][1] == 0, "new match clears temporary scouting")
	for actor in defensive.agents:
		var own = 0
		for event in defensive.events:
			if (
				event.kind == "action_grade"
				and event.type == "response"
				and event.seat == actor.role
			):
				own += 1
		var learned = 0
		for key in actor.estimates:
			check(key.begins_with("star2/" + str(actor.role) + "/"), "isolated policy rows")
			learned += int(actor.estimates[key][0])
		check(
			own > 0 and own == actor.decisions_graded and learned == own,
			"each verified action trains its owner exactly once"
		)
	var restored = court()
	restored.configure_agents(defensive.learned_weights())
	for i in 3:
		check(
			restored.agents[i].estimates == defensive.agents[i].estimates,
			"checkpoint restores each policy"
		)
		check(restored.agents[i].recent.is_empty(), "recent tactical evidence starts fresh")
	print("Court regression failures: ", failures)
	quit(int(failures > 0))
