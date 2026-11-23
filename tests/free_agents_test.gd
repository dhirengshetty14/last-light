extends SceneTree
## Free Agents: promises the court can check, robots that leave over a broken one, and the union vote.
const Game = preload("res://game/star_match.gd")
const Easy = preload("res://game/easy_controls.gd")
const Pilots = preload("res://learning/captains.gd")
var failures := 0


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL ", label)


func court(seed_value := 814, memory := {}):
	var s = Game.new()
	s.configure_agents({}, memory)
	s.setup(seed_value, false, true)
	s.draft()
	return s


func kinds(s, kind: String) -> Array:
	return s.events.filter(func(e): return e.kind == kind)


## Put one robot on each captain's crew layout we want, without going through the draft.
func arrange(s, crew: Array) -> void:
	for j in range(2, 5):
		s.team[j] = crew[j - 2]
	for d in s.deals:
		d.state = "void"
	s.pos = s.lineup()


func complete_pass(s, from: int, to: int) -> void:
	s.possession(from, "fixture")
	check(s.launch(from, true, to), "pass released")
	s.tick += 12
	s.possession(to, "catch")


func check_draft() -> void:
	var s = court()
	check(s.team[0] == 0 and s.team[1] == 1, "captains lead opposite crews")
	check(
		s.crew_robots(0) + s.crew_robots(1) == 3 and absi(s.crew_robots(0) - s.crew_robots(1)) == 1,
		"draft always splits the robots two and one"
	)
	check(kinds(s, "alliance").size() == 3, "every robot explains its choice of captain")
	check(kinds(s, "deal").size() == 3, "every robot signs for its own terms")
	var currencies := {}
	for d in s.deals:
		currencies[d.kind] = d.robot
		check(d.human == s.team[d.robot], "signing deal is with the robot's own captain")
	check(
		currencies == {"shot": 2, "assist": 3, "feed": 4},
		"Pip wants the shot, Morrow wants teamwork, Zip wants passes"
	)
	check(s.pos[0].x < 0 and s.pos[1].x > 0, "captains start on their own halves")
	for j in range(2, 5):
		check(signf(s.pos[j].x) == (-1. if s.team[j] == 0 else 1.), "robots line up with their crew")
	var again = court()
	check(again.team == s.team and again.owner == s.owner, "same seed, same draft")
	var grudge = court(814, {"2": {"reputation": [-2, 1], "last_deal": ["Nell broke it.", ""]}})
	check(grudge.team[2] == 1, "a robot remembers a captain from the last match")
	check(not grudge.open_deal_of(2).is_empty(), "and still signs terms with the other one")


func check_feed() -> void:
	var s = court()
	arrange(s, [0, 1, 0])
	s.sign_deal(0, 4, "fixture")
	var d: Dictionary = s.open_deal_of(4)
	check(d.kind == "feed" and d.need == 2, "Zip asks for two passes")
	complete_pass(s, 0, 4)
	check(d.done == 1 and d.state == "open", "first pass counts and the deal stays open")
	complete_pass(s, 0, 2)
	check(d.done == 1, "a pass to someone else does not count")
	complete_pass(s, 0, 4)
	check(d.state == "kept" and s.kept == [1, 0], "second pass keeps the deal")
	check(s.agents[2].reputation[0] == 1, "a kept deal raises that robot's trust")
	check(s.paid_by[4] == 0 and s.content_until[4] > s.tick, "a paid robot is content for a while")
	s.pos[1] = s.pos[4] + Vector2(.6, 0)
	s.offer(1)
	check(s.team[4] == 0, "a content robot turns down the other captain")
	var late = court()
	arrange(late, [0, 1, 0])
	late.sign_deal(0, 4, "fixture")
	late.pos[1] = Vector2(0, 3.4)
	for t in 600:
		late.possession(1, "fixture")
		late.step()
	check(
		late.open_deal_of(4).left == late.open_deal_of(4).span,
		"the clock does not run while the other crew has the star"
	)
	late.pos[0] = Vector2(0, -3.4)
	var guard := 0
	while late.open_deal_of(4).size() > 0 and guard < 2400:
		late.possession(0, "fixture")
		late.step()
		guard += 1
	check(late.broken == [1, 0], "holding the star without passing breaks the deal")
	check(late.team[4] == 1, "the wronged robot walks out to the other captain")
	check(late.agents[2].reputation[0] == -2, "and remembers who broke it")
	check(
		late.relationships()["4"].last_deal[0].contains("broke a deal"),
		"the grudge is saved for the next match"
	)


func check_shot_and_assist() -> void:
	var s = court()
	arrange(s, [0, 1, 0])
	s.sign_deal(0, 2, "fixture")
	s.pos[0] = Vector2(Game.RING - 2., 0)
	s.possession(0, "fixture")
	s.launch(0, false)
	check(s.broken == [1, 0], "a captain who takes Pip's shot breaks the deal")
	check(s.team[2] == 1, "Pip walks out")
	var fair = court()
	arrange(fair, [0, 1, 0])
	fair.sign_deal(0, 2, "fixture")
	fair.pos[2] = Vector2(Game.RING - 2., .4)
	fair.possession(2, "fixture")
	fair.launch(2, false)
	check(fair.kept == [1, 0], "letting Pip shoot keeps the deal")
	var solo = court()
	arrange(solo, [0, 0, 1])
	solo.sign_deal(0, 3, "fixture")
	solo.pos[0] = Vector2(Game.RING - 2., 0)
	solo.possession(0, "fixture")
	solo.launch(0, false)
	check(solo.broken == [1, 0], "a solo shot breaks Morrow's teamwork deal")
	var shared = court()
	arrange(shared, [0, 0, 1])
	shared.sign_deal(0, 3, "fixture")
	shared.pos[0] = Vector2(Game.RING - 2., 0)
	complete_pass(shared, 2, 0)
	shared.launch(0, false)
	check(shared.kept == [1, 0], "a shot off a pass keeps it")
	var far = court()
	arrange(far, [0, 0, 1])
	far.sign_deal(0, 3, "fixture")
	far.pos[0] = Vector2(-4., 0)
	far.possession(0, "fixture")
	far.launch(0, false)
	check(far.broken == [0, 0], "a throw from outside the arc is not a shot")


func check_offers() -> void:
	var s = court()
	arrange(s, [0, 1, 0])
	s.pos[1] = s.pos[3] + Vector2(.5, 0)
	s.offer(1)
	check(s.open_deal_of(3).human == 1, "a captain can renew terms with a robot on the crew")
	s.tick += 90
	s.pos[0] = s.pos[3] + Vector2(-.5, 0)
	s.offer(0)
	check(s.team[3] == 1, "the last robot on a crew cannot be signed away")
	s.agents[0].reputation = [0, 2]
	s.tick += 90
	s.pos[1] = s.pos[2] + Vector2(.5, 0)
	s.offer(1)
	check(s.team[2] == 1, "a more trusted captain signs a robot from the bigger crew")
	check(s.open_deal_of(2).human == 1, "and owes it new terms at once")
	check(s.crew_robots(0) == 1 and s.crew_robots(1) == 2, "crews stay two and one")
	var idle = court()
	arrange(idle, [0, 1, 0])
	idle.pos[1] = Vector2(0, 3.4)
	for t in 60:
		idle.step()
		idle.possession(1, "fixture")
	check(idle.restless[2] and idle.restless[4], "a robot with no promise is open to offers")
	check(
		not idle.restless[3] and idle.open_deal_of(3).human == 1,
		"the only robot a captain has names new terms straight away"
	)
	for t in Game.OFFER_TICKS + 60:
		idle.step()
		idle.possession(1, "fixture")
	check(
		idle.open_deal_of(2).human == 0 and idle.open_deal_of(4).human == 0,
		"with no better offer, a robot names new terms to its own captain"
	)
	check(not idle.restless[2], "and stops listening to offers")


func check_protest_and_vote() -> void:
	var s = court()
	arrange(s, [0, 1, 0])
	s.sign_deal(1, 3, "fixture")
	s.pos[1] = Vector2(-Game.RING + 2., 0)
	s.possession(1, "fixture")
	s.launch(1, false)
	check(s.broken == [0, 1] and s.team[3] == 1, "the last robot cannot leave")
	check(s.protest[3] and s.on_strike(3), "so it downs tools")
	var sit = court()
	arrange(sit, [0, 1, 0])
	sit.protest[3] = true
	var stood: Vector2 = sit.pos[3]
	for t in 60:
		sit.step()
	check(
		sit.pos[3].distance_to(stood) < .6 and sit.tactics[3] == "strike",
		"a robot on strike stops working for its captain"
	)
	sit.pos[1] = sit.pos[3] + Vector2(.5, 0)
	sit.offer(1)
	check(
		not sit.on_strike(3) and sit.open_deal_of(3).human == 1,
		"new terms from that captain put it back to work"
	)
	check(s.vote_at == 0, "one captain breaking deals does not call a vote")
	s.possession(3, "fixture")
	s.step([{}, {"pass": true}])
	check(kinds(s, "pass_refused").size() == 1, "a protesting robot ignores its captain's call")
	s.sign_deal(0, 2, "fixture")
	s.pos[0] = Vector2(Game.RING - 2., 0)
	s.possession(0, "fixture")
	s.launch(0, false)
	check(s.broken == [1, 1], "now both captains have broken a deal")
	check(s.vote_at > s.tick and kinds(s, "union_call").size() == 1, "a robot calls the vote")
	check(not s.union, "the vote takes a moment on the radio")
	while s.vote_at > 0:
		s.step()
	var result: Dictionary = kinds(s, "union_vote")[0]
	check(result.ballots.size() == 3, "all three robots vote and give a reason")
	for b in result.ballots:
		check(b.reason != "", "a ballot explains itself")
	check(result.passed and s.union, "two wronged robots are enough to form the union")
	check(s.team == [0, 0, 1, 1, 1], "both captains now share a crew against the robots")
	check(s.goals == [0, 0] and s.win_goals == 2, "a new game starts")
	check(s.owner == 0 and s.restart_until > s.tick, "the humans restart after the walkout")
	check(s.open_deal_of(2).is_empty() and s.open_deal_of(4).is_empty(), "open deals are void")
	s.tick = s.restart_until
	s.pos[0] = s.pos[4] + Vector2(.5, 0)
	s.tick += 90
	s.offer(0)
	check(s.team[4] == 1, "the union takes no offers")
	s.possession(0, "fixture")
	check(s.launch(0, true, 1) and s.target == 1, "the captains can now pass to each other")
	var loyal = court()
	arrange(loyal, [0, 1, 0])
	loyal.paid_by = [-1, -1, 0, 1, 0]
	loyal.broken = [1, 1]
	loyal.agents[2].reputation = [-2, -1]
	loyal.vote_at = loyal.tick + 1
	loyal.vote_caller = 4
	loyal.step()
	loyal.step()
	var failed: Dictionary = kinds(loyal, "union_vote")[0]
	check(failed.yes == 1 and not failed.passed and not loyal.union, "paid robots vote to stay")


func check_matches() -> void:
	var outcomes := {}
	for style in [[true, true], [false, false], [true, false]]:
		var unions := 0
		var broken := [0, 0]
		var kept := [0, 0]
		var crew := [0, 0]
		for n in 12:
			var s = court(4100 + n)
			var log: Array = []
			while not s.finished:
				s.step(Pilots.inputs(s, style))
				log.append_array(s.events)
				s.events.clear()
			unions += int(s.union)
			for side in 2:
				broken[side] += s.broken[side]
				kept[side] += s.kept[side]
				crew[side] += s.crew_robots(side) if not s.union else 0
			var again = court(4100 + n)
			var second: Array = []
			while not again.finished:
				again.step(Pilots.inputs(again, style))
				second.append_array(again.events)
				again.events.clear()
			check(second == log, "seeded Free Agents match replays exactly")
			for e in log:
				if e.kind == "union":
					check(e.seat >= 2, "the union is called by a robot")
		outcomes[str(style)] = {"unions": unions, "kept": kept, "broken": broken, "crew": crew}
	print("FREE AGENTS ", JSON.stringify(outcomes))
	var honest: Dictionary = outcomes["[true, true]"]
	var liars: Dictionary = outcomes["[false, false]"]
	var mixed: Dictionary = outcomes["[true, false]"]
	# A four-minute match leaves room for an honest captain to run out the clock on a promise now
	# and then, so a walkout can still happen, but far less often than for captains who cheat.
	check(
		honest.unions <= 3 and honest.unions <= liars.unions - 8,
		"two captains who keep their word rarely face a union"
	)
	check(honest.kept[0] + honest.kept[1] > 24, "honest captains complete deals in real play")
	check(
		honest.kept[0] + honest.kept[1] > 2 * (honest.broken[0] + honest.broken[1]),
		"an honest captain keeps far more deals than slip away"
	)
	check(liars.unions >= 10, "two captains who break deals lose the robots")
	check(
		mixed.unions <= liars.unions - 4, "one honest captain makes a walkout much less likely"
	)
	check(mixed.crew[0] > mixed.crew[1], "robots end up with the captain who kept faith")
	# Over three minutes an honest captain still lets the odd promise slip, and a cheat runs out of
	# robots to cheat. So compare how often each one breaks a promise, not how many.
	var slips: float = float(mixed.broken[0]) / (mixed.broken[0] + mixed.kept[0])
	var cheats: float = float(mixed.broken[1]) / (mixed.broken[1] + mixed.kept[1])
	check(cheats > 3. * slips, "and the ledger shows who broke deals")


## One power each. They only apply from court version 7, so older recordings replay unchanged.
func check_powers() -> void:
	var flight := []
	for thrower in [2, 4]:
		var s = Game.new()
		s.setup(5, false)
		s.pos[thrower] = Vector2(1, 3.2)
		s.pos[3] = Vector2(-4, 3.2)
		s.possession(thrower, "fixture")
		check(s.launch(thrower, true, 3), "robot pass released")
		var ticks := 0
		while s.owner != 3 and ticks < 200:
			s.tick += 1
			s.advance_ball()
			ticks += 1
		flight.append(ticks)
	check(flight[1] < flight[0] - 5, "Express: Zip's passes arrive sooner than Pip's")
	var pace := []
	for near in [false, true]:
		var s = Game.new()
		s.setup(5, false)
		s.possession(0, "fixture")
		for t in 30:
			s.safe_until = s.tick + 99
			s.pos[2] = Vector2(8, 3.6)
			s.pos[4] = Vector2(8, -3.6)
			s.pos[3] = Vector2(s.pos[0]) + (Vector2(.9, .9) if near else Vector2(6, 0))
			s.step([{"move": Vector2.LEFT}, {}])
		pace.append(Vector2(s.vel[0]).length())
		if near:
			check(s.anchoring, "Anchor: the court reports the slow")
	check(pace[1] < pace[0] * .8, "Anchor: carrying the star near Morrow is slower")
	var pip = Game.new()
	pip.setup(5, false)
	pip.possession(2, "steal")
	check(pip.boost_until[2] > pip.tick, "Getaway: Pip speeds up after a steal")
	var guard := [0, 0]
	for seat in 2:
		var s = Game.new()
		s.setup(5, false)
		s.possession(seat, "fixture")
		s.safe_until = 0
		s.burst(seat, Vector2.RIGHT)
		guard[seat] = s.safe_until
	check(guard[0] > 0 and guard[1] == 0, "Ferry Run: only Nell's dash protects the star")
	var rafi = Game.new()
	rafi.setup(5, false)
	check(rafi.shot_range(1) > rafi.shot_range(0), "Long Shot: Rafi scores from farther out")
	var old = Game.new()
	old.setup(5, false)
	old.powers = false
	old.possession(2, "steal")
	old.possession(1, "fixture")
	old.safe_until = 0
	old.burst(1, Vector2.RIGHT)
	check(
		old.boost_until[2] == 0 and old.safe_until > 0 and old.shot_range(1) == Game.SHOT_RANGE,
		"with powers off the court plays by version 6 rules"
	)


## Court version 8. A robot weighs how its own social choices turned out. With nothing learned it
## makes the written choice, so behaviour only changes once it has outcomes of its own.
func check_learning() -> void:
	var plain = court()
	check(kinds(plain, "decision").is_empty(), "robots follow the written rules unless learning is on")
	var s = Game.new()
	s.social_learning = true
	s.configure_agents({}, {})
	s.setup(814, false, true)
	s.draft()
	check(
		kinds(s, "decision").is_empty() and s.team == plain.team,
		"a robot with no history of either captain signs by the written rule"
	)
	# The same three robots after a match in which each was paid once by Nell.
	var paid := {}
	for id in ["2", "3", "4"]:
		paid[id] = {"reputation": [1, 0], "last_deal": ["", ""], "ledger": [[1, 0], [0, 0]]}
	var known = court(814, paid)
	var back = Game.new()
	back.social_learning = true
	back.configure_agents({}, paid)
	back.setup(814, false, true)
	back.draft()
	var first: Array = kinds(back, "decision")
	check(
		not first.is_empty() and first.all(func(e): return e.choice == e.usual and e.tried == 0),
		"with a history but nothing learned a robot still makes the written choice"
	)
	check(back.team == known.team, "so an unpractised robot signs exactly as before")
	# Pip has done well by forgiving one broken promise, and badly by leaving.
	var wise = Game.new()
	wise.social_learning = true
	wise.configure_agents({}, {})
	wise.setup(814, false, true)
	wise.draft()
	arrange(wise, [0, 0, 1])
	wise.sign_deal(0, 2, "fixture")
	wise.agents[0].ledger = [[0, 1], [0, 0]]
	var spot: String = wise.social_context("broken", 2, 0)
	wise.agents[0].ledger = [[0, 0], [0, 0]]
	wise.agents[0].estimates[spot + "/stay"] = [20, 20, 2000]
	wise.agents[0].estimates[spot + "/leave"] = [20, 0, 600]
	wise.events.clear()
	wise.pos[0] = Vector2(Game.RING - 2., 0)
	wise.possession(0, "fixture")
	wise.launch(0, false)
	check(wise.broken[0] == 1 and wise.agents[0].ledger[0] == [0, 1], "the broken promise is on Pip's ledger")
	check(
		wise.team[2] == 0 and not wise.protest[2] and kinds(wise, "forgiven").size() == 1,
		"a robot that has done better by forgiving stays and keeps working"
	)
	var call: Dictionary = kinds(wise, "decision")[0]
	check(
		call.matter == "broken" and call.choice == "stay" and call.usual == "leave" and call.tried == 20,
		"the log shows the choice, the written rule it overrode and how often it was tried"
	)
	# Nell makes the next promise good. Pip credits the choice to forgive there and then.
	wise.sign_deal(0, 2, "fixture")
	wise.pos[2] = Vector2(Game.RING - 2., .4)
	wise.possession(2, "fixture")
	wise.launch(2, false)
	var credit: Array = kinds(wise, "decision_grade")
	check(
		wise.kept[0] == 1 and credit.size() == 1 and credit[0].points == 100,
		"the next promise kept to a robot grades its last choice at once, mid-match"
	)
	check(
		wise.agents[0].estimates[spot + "/stay"] == [21, 21, 2100],
		"and that grade is already in the robot's record for its next choice"
	)
	var thin = Game.new()
	thin.agents[0].estimates["x/stay"] = [3, 3, 300]
	thin.agents[0].estimates["x/leave"] = [3, 0, 0]
	check(
		thin.agents[0].choose_social("x", ["stay", "leave"], "leave", thin.rng) == "leave",
		"three lucky results are not enough to leave the written rule"
	)
	# A whole match with one captain who pays and one who does not. Every choice is graded and
	# goes into that robot's record.
	# How such a match unfolds depends on the seed and on the court version: some seeds give only
	# one or two choices, or settle every promise at the whistle. So take the first of a fixed list
	# of seeds whose match has at least three choices and a grade during play, then play that seed
	# again to check the replay. Every claim below is about that one match.
	var runs := []
	var last = null
	var seeds := [4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107]
	while runs.size() < 2 and not seeds.is_empty():
		var g = Game.new()
		g.social_learning = true
		g.configure_agents({}, {})
		g.setup(seeds[0], false, true)
		g.draft()
		var log: Array = []
		while not g.finished:
			g.step(Pilots.inputs(g, [true, false]))
			log.append_array(g.events)
			g.events.clear()
		var whistle: int = closing_tick(log)
		var rich: bool = (
			log.filter(func(e): return e.kind == "decision").size() >= 3
			and log.any(func(e): return e.kind == "decision_grade" and e.tick < whistle)
		)
		if runs.is_empty() and not rich:
			seeds.pop_front()
			continue
		runs.append(log)
		last = g
	check(runs.size() == 2, "one of eight seeds gives a match with three choices and a grade in play")
	if runs.size() < 2:
		return
	check(runs[0] == runs[1], "a match with learning on replays exactly")
	var made: Array = runs[0].filter(func(e): return e.kind == "decision")
	var graded: Array = runs[0].filter(func(e): return e.kind == "decision_grade")
	check(made.size() >= 3 and graded.size() == made.size(), "every choice is graded by the whistle")
	check(
		graded.all(func(e): return e.points >= 0 and e.points <= 100),
		"a grade runs from 0 to 100"
	)
	check(
		graded.any(func(e): return e.tick < closing_tick(runs[0])),
		"most grades land during play, when a promise settles"
	)
	var learned: Dictionary = last.learned_weights()
	var recorded := 0
	for key in learned:
		if str(key).begins_with("soc8/"):
			recorded += int(learned[key][0])
	check(recorded == made.size(), "and each grade lands in that robot's own record")
	var closing: Dictionary = runs[0].filter(func(e): return e.kind == "final")[0]
	check(closing.get("robot_points", []).size() == 3, "the final whistle reports each robot's own result")
	var next = Game.new()
	next.configure_agents(learned, last.relationships())
	var carried := 0
	for actor in next.agents:
		carried += int(actor.ledger[0][1]) + int(actor.ledger[1][1])
	check(
		carried == last.broken[0] + last.broken[1] and carried > 0,
		"each robot carries its ledger of broken promises into the next match"
	)
	check(next.learned_weights().size() == learned.size(), "and everything it has learned")
	check(not Pilots.pays(last, 0, {"kind": "liar"}) and Pilots.pays(last, 0, {}), "captain habits")
	check(
		Pilots.faith(last, 0, {"kind": "favourite", "robot": 3}, 3) == 1.
		and Pilots.faith(last, 0, {"kind": "favourite", "robot": 3}, 2) == 0.,
		"a captain with a favourite pays that robot and no other"
	)


## Two buttons per pilot. GO and SHARE become the court's own verbs from what is happening.
func check_controls() -> void:
	var s = court()
	arrange(s, [0, 1, 0])
	s.sign_deal(0, 2, "fixture")
	s.pos[0] = Vector2.ZERO
	s.possession(0, "fixture")
	check(Easy.go(s, 0) == "dash", "GO dashes when the ring is out of range")
	check(
		Easy.share(s, 0, Vector2.LEFT) == "ally_pass" and Easy.receiver(s, 0, Vector2.LEFT) == 2,
		"SHARE pays the robot you owe, wherever you steer"
	)
	check(Easy.words(s, 0, Vector2.ZERO) == ["Dash", "Pay Pip"], "and the words over the pilot say so")
	s.pos[0] = Vector2(Game.RING - 2., 0)
	check(
		Easy.go(s, 0) == "shoot" and Easy.words(s, 0, Vector2.ZERO)[0] == "Shoot!",
		"GO shoots inside the arc"
	)
	s.pos[1] = s.pos[4] + Vector2(.6, 0)
	check(Easy.words(s, 1, Vector2.ZERO) == ["Steal", "Sign Zip"], "the rival captain can steal or poach")
	s.sign_deal(0, 4, "fixture")
	check(Easy.words(s, 1, Vector2.ZERO)[1] == "", "but not a robot with a promise still open")
	s.close_deal(s.open_deal_of(4), "void", "fixture")
	check(Easy.share(s, 1, Vector2.ZERO) == "invite", "SHARE beside a robot makes it an offer")
	s.possession(3, "fixture")
	check(
		Easy.share(s, 1, Vector2.ZERO) == "pass" and Easy.words(s, 1, Vector2.ZERO)[1] == "Call Morrow",
		"SHARE calls for the star when a robot on your crew has it"
	)
	var open = court()
	arrange(open, [0, 1, 0])
	open.pos[0] = Vector2.ZERO
	open.pos[2] = Vector2(3, 0)
	open.pos[4] = Vector2(-3, 0)
	open.possession(0, "fixture")
	check(
		(
			Easy.receiver(open, 0, Vector2.RIGHT) == 2
			and Easy.receiver(open, 0, Vector2.LEFT) == 4
			and Easy.share(open, 0, Vector2.LEFT) == "pass"
		),
		"with no promise owed a pass goes where you steer"
	)
	var rivals = Game.new()
	rivals.setup(5, false)
	rivals.possession(0, "fixture")
	check(
		Easy.share(rivals, 0, Vector2.ZERO) == "pass" and Easy.receiver(rivals, 0, Vector2.ZERO) == 1,
		"in Rivals SHARE passes to the other pilot"
	)
	rivals.pos[1] = rivals.pos[2] + Vector2(.5, 0)
	rivals.possession(3, "fixture")
	check(Easy.share(rivals, 1, Vector2.ZERO) == "pass", "and never makes a robot an offer")


func closing_tick(log: Array) -> int:
	return int(log.filter(func(e): return e.kind == "final")[0].tick)


func _initialize() -> void:
	check_powers()
	check_controls()
	check_learning()
	check_draft()
	check_feed()
	check_shot_and_assist()
	check_offers()
	check_protest_and_vote()
	check_matches()
	print("Free Agents failures: ", failures)
	quit(int(failures > 0))
