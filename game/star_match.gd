extends RefCounted
## Fixed-tick court shared by keyboard players, trained robots and the headless gym.
const Policy = preload("res://learning/star_policy.gd")
const Agent = preload("res://game/star_agent.gd")
const NAMES = ["Nell", "Rafi", "Pip", "Morrow", "Zip"]
const START = [
	Vector2(-4.8, 1.65),
	Vector2(-3.4, -1.65),
	Vector2(2.35, 1.28),
	Vector2(6.15, -.23),
	Vector2(4.2, -2.65)
]
const SPEED = [4.05, 4.35, 3.85, 3.6, 4.65]
const DT = 1.0 / 60.0
const END = 60 * 100
## Court version 9 is a quarter longer and wider. `ring`, `bounds` and `spread` hold the size this
## match is played on, so a recording made on the earlier court replays on it (`old_court`).
const OLD_RING = 8.8
const OLD_BOUNDS = Vector2(8.28, 3.72)
const RING = 11.0
const HEIGHT = 1.58
const BOUNDS = Vector2(10.35, 4.65)
const SHOT_RANGE = 3.55
const RADIUS = .18
const GRAVITY = 10.8
const RESTART_TICKS = 116
const GOLD = 0
const BLUE = 1
var pos: Array = START.duplicate()
var vel := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var team := [0, 0, 1, 1, 1]
var goals := [0, 0]
var cooldown := [0, 0, 0, 0, 0]
var dash_until := [0, 0, 0, 0, 0]
var dash_dir := [Vector2.RIGHT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]
var trust := [0, 0, 1, 0, 0]
var ignored := [0, 0, 0, 0, 0]
var pact := [-1, -1, -1, -1, -1]
var called_by := [-1, -1, -1, -1, -1]
var call_expiry := [0, 0, 0, 0, 0]
var requests := [-600, -600]
var habits := [[0, 0, 0.0], [0, 0, 0.0]]
var tactics := ["", "", "press", "screen", "cut"]
var destinations: Array = START.duplicate()
var pending := [{}, {}, {}, {}, {}]
var generation := 0
var agents: Array = [Agent.new(2), Agent.new(3), Agent.new(4)]
var legacy_replay := false
var rng := RandomNumberGenerator.new()
var events: Array = []
var seq := 0
var tick := 0
var owner := 0
var safe_until := 135
var ball := Vector3.ZERO
var motion := Vector3.ZERO
var thrower := -1
var flight := ""
var throw_checks: Dictionary = {}
var throw_side := GOLD
var flight_tick := 0
var target := -1
var reception_point := Vector2.ZERO
var robot_chain := false
var surge_until := 0
var restart_until := 0
var open_crews := false
var relay_rules := true
var moving_passes := true
var relay_passes := 0
var finished := false
var keep_events := true
var last_input: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var timings: Array[int] = []
var sample_time := false
var lane := [1.9, -1.9, 2.35, -.9, -2.6]
var facing := [Vector2.RIGHT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]
## Free Agents. Nell and Rafi captain rival crews. Each robot signs for a promise the court can check,
## walks out on a broken one, and can vote with the other robots to play for itself.
const FA_CAPTAINS = [Vector2(-5.2, .7), Vector2(5.2, -.7)]
const FA_SLOTS = [Vector2(2.5, 2.25), Vector2(2.9, -2.2), Vector2(6.4, 1.5)]
const CONTENT_TICKS := 60 * 20
const OFFER_TICKS := 60 * 10
const VOTE_TICKS := 150
const UNION_TICKS := 210
var free_agents := false
## Court version 7 gives each of the five one power. Recordings made before it replay with this off.
##   Nell    Ferry Run   the longest dash, and the only dash that protects the star
##   Rafi    Long Shot   scores from farther out
##   Pip     Getaway     a burst of speed after every steal
##   Morrow  Anchor      an opponent carrying the star near him is slowed
##   Zip     Express     his passes fly faster
const LONG_SHOT := .5
const GETAWAY_TICKS := 90
const ANCHOR_RANGE := 1.7
var powers := true
var boost_until := [0, 0, 0, 0, 0]
var anchoring := false
var speed: Array = SPEED.duplicate()
var drafted := false
var union := false
var win_goals := 3
var end_tick := END
var deals: Array = []
var deal_serial := 0
var kept := [0, 0]
var broken := [0, 0]
var fed := [false, false, false, false, false]
var paid_by := [-1, -1, -1, -1, -1]
var content_until := [0, 0, 0, 0, 0]
var last_touch := [0, 0, 0, 0, 0]
var restless := [false, false, false, false, false]
var open_since := [0, 0, 0, 0, 0]
var protest := [false, false, false, false, false]
var vote_at := 0
var vote_caller := -1
var votes_held := 0
var captain_goals := [0, 0]
var ring: float = RING
var bounds: Vector2 = BOUNDS
## How far the starting spots and running lanes are stretched from the earlier court.
var spread := Vector2(RING / OLD_RING, BOUNDS.y / OLD_BOUNDS.y)
## The larger court also plays longer: three minutes of Free Agents, two of the other modes.
var enlarged := true
## Court version 8. Each robot weighs how its own social choices turned out before: which captain
## to sign with, what to do about a broken promise, an offer or new terms, and how to vote. With
## this off every one of those follows its written rule, as in court 7.
const CAPTAIN_KEYS = ["nell", "rafi"]
var social_learning := false
var social_made: Array = []
## Promises kept to each robot this match, minus promises broken.
var standing := [0, 0, 0, 0, 0]


func setup(seed_value: int, crews: bool, free: bool = false) -> void:
	rng.seed = seed_value
	for actor in agents:
		actor.draw.seed = seed_value ^ (int(actor.role) * 0x9e3779b9)
	open_crews = crews and not free
	pos = lineup()
	destinations = pos.duplicate()
	end_tick = 60 * 120 if enlarged else END
	if free:
		free_agents = true
		# A timed match: the captains' game needs room for promises to be made, kept and broken.
		win_goals = 99
		end_tick = 60 * (180 if enlarged else 120)
		# As rivals the captains run level. Nell keeps the longer dash, Rafi the wider catch.
		speed[0] = 4.2
		speed[1] = 4.2
		team = [GOLD, BLUE, GOLD, BLUE, BLUE]
		owner = absi(seed_value) % 2
		pos = lineup()
		destinations = pos.duplicate()
		facing[1] = Vector2.LEFT
		dash_dir[1] = Vector2.LEFT
	ball = hand(owner)


func shot_range(i: int) -> float:
	return SHOT_RANGE + (LONG_SHOT if powers and i == 1 else 0.)


## Play this match on the court as it was before version 9. Call it before `setup`.
func old_court() -> void:
	ring = OLD_RING
	bounds = OLD_BOUNDS
	spread = Vector2.ONE
	enlarged = false


func lineup() -> Array:
	if not free_agents or union:
		var places := []
		for spot in START:
			places.append(Vector2(spot) * spread)
		return places
	var out := [
		FA_CAPTAINS[0] * spread, FA_CAPTAINS[1] * spread, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO
	]
	var used := [0, 0]
	for i in range(2, 5):
		var side: int = team[i]
		var slot: Vector2 = FA_SLOTS[used[side]] * spread
		used[side] += 1
		out[i] = Vector2(-slot.x, slot.y) if side == GOLD else Vector2(slot.x, -slot.y)
	return out


func crew_robots(side: int) -> int:
	var count := 0
	for j in range(2, 5):
		count += int(team[j] == side)
	return count


func open_deal_of(j: int) -> Dictionary:
	for d in deals:
		if d.state == "open" and d.robot == j:
			return d
	return {}


func words(d: Dictionary) -> String:
	match str(d.kind):
		"feed":
			return "%d passes to %s" % [d.need, NAMES[d.robot]]
		"shot":
			return "%s takes the next shot" % NAMES[d.robot]
	return "the next shot comes off a pass"


## Each robot is paid in a different currency. A captain who broke a deal with it pays more.
## A longer court allows that much longer to pay.
func terms(j: int, human: int) -> Dictionary:
	var grudge := maxi(0, -int(agents[j - 2].reputation[human]))
	match j:
		2:
			return {"kind": "shot", "need": 1, "span": int(60 * (14 - 2 * grudge) * spread.x)}
		3:
			return {"kind": "assist", "need": 1, "span": int(60 * (14 - 2 * grudge) * spread.x)}
	return {"kind": "feed", "need": 2 + grudge, "span": int(60 * 14 * spread.x)}


## The robots choose their captains before kickoff from what they remember of each one.
func draft() -> void:
	if not free_agents or drafted:
		return
	drafted = true
	var count := [0, 0]
	var picks := [-1, -1, -1, -1, -1]
	var notes := ["", "", "", "", ""]
	for j in [2, 4, 3]:
		var actor = agents[j - 2]
		var a := int(actor.reputation[0])
		var b := int(actor.reputation[1])
		var side := GOLD
		if j == 3 and count[0] != count[1]:
			side = GOLD if count[0] < count[1] else BLUE
			notes[j] = "Morrow backs the short-handed crew."
		elif a != b:
			side = GOLD if a > b else BLUE
			notes[j] = "%s trusts %s more than %s." % [NAMES[j], NAMES[side], NAMES[1 - side]]
		elif j == 4 and picks[2] >= 0:
			side = 1 - int(picks[2])
			notes[j] = "Zip takes the open lane beside %s." % NAMES[side]
		else:
			side = int(actor.draw.randi() % 2)
			notes[j] = "%s has no quarrel with either captain and picks %s." % [NAMES[j], NAMES[side]]
		if count[side] >= 2:
			side = 1 - side
			notes[j] = "%s keeps the crews even." % NAMES[j]
		elif count[1 - side] < 2 and int(actor.ledger[0].max()) + int(actor.ledger[1].max()) > 0:
			# Only a robot with some history of these captains has anything to weigh. A preference
			# with none could only come from quirks of the captains it practised against.
			if decide("draft", j, CAPTAIN_KEYS, CAPTAIN_KEYS[side], GOLD) != CAPTAIN_KEYS[side]:
				side = 1 - side
				notes[j] = "%s has done better signing with %s." % [NAMES[j], NAMES[side]]
		picks[j] = side
		count[side] += 1
	for j in range(2, 5):
		team[j] = picks[j]
	pos = lineup()
	destinations = pos.duplicate()
	ball = hand(owner)
	for j in [2, 4, 3]:
		emit(
			"alliance",
			j,
			{"team": team[j], "human": team[j], "changed": true, "draft": true, "reason": notes[j]}
		)
		sign_deal(team[j], j, "signing terms")


func sign_deal(human: int, j: int, note: String) -> void:
	var t := terms(j, human)
	deal_serial += 1
	var d := {
		"id": deal_serial,
		"human": human,
		"robot": j,
		"kind": t.kind,
		"need": t.need,
		"done": 0,
		"born": tick,
		"span": int(t.span),
		"left": int(t.span),
		"state": "open"
	}
	deals.append(d)
	restless[j] = false
	emit(
		"deal",
		j,
		{
			"deal": d.id,
			"human": human,
			"action": d.kind,
			"need": d.need,
			"span": d.span,
			"terms": words(d),
			"reason": "%s to %s: %s. (%s)" % [NAMES[human], NAMES[j], words(d), note]
		}
	)


func close_deal(d: Dictionary, state: String, why: String) -> void:
	if d.state != "open":
		return
	d.state = state
	var j: int = d.robot
	var h: int = d.human
	var actor = agents[j - 2]
	if state != "void":
		grade_social(j, 100 if state == "kept" else 0)
	if state == "kept":
		kept[h] += 1
		standing[j] += 1
		actor.ledger[h][0] = mini(99, int(actor.ledger[h][0]) + 1)
		paid_by[j] = h
		content_until[j] = tick + CONTENT_TICKS
		protest[j] = false
		actor.remember(h, 1, "%s kept a deal with me: %s." % [NAMES[h], words(d)])
		for other in agents:
			if (
				other.role != j
				and other.reputation[h] < 0
				and other.can_see(pos[other.role].distance_to(pos[h]))
			):
				other.remember(h, 1, "Saw %s keep a deal with %s." % [NAMES[h], NAMES[j]])
	elif state == "broken":
		broken[h] += 1
		standing[j] -= 1
		actor.ledger[h][1] = mini(99, int(actor.ledger[h][1]) + 1)
		actor.remember(h, -2, "%s broke a deal with me: %s." % [NAMES[h], words(d)])
		for other in agents:
			if other.role != j and other.can_see(pos[other.role].distance_to(pos[h])):
				other.remember(h, -1, "Saw %s break a deal with %s." % [NAMES[h], NAMES[j]])
	emit(
		"deal_end",
		j,
		{
			"deal": d.id,
			"human": h,
			"action": d.kind,
			"state": state,
			"reason": why,
			"kept": kept.duplicate(),
			"broken": broken.duplicate()
		}
	)
	if state == "broken":
		walk_out(j, h)


## A wronged robot joins the other captain if it can. The last robot on a crew cannot leave, so it
## downs tools until that captain signs new terms with it and keeps them.
func walk_out(j: int, h: int) -> void:
	var other := 1 - h
	if team[j] == h:
		var can_leave: bool = crew_robots(h) >= 2
		var usual := (
			"leave" if can_leave and int(agents[j - 2].reputation[other]) >= 0 else "strike"
		)
		var legal := ["stay", "strike", "leave"] if can_leave else ["stay", "strike"]
		match decide("broken", j, legal, usual, h):
			"leave":
				switch_crew(
					j, other, "%s walks out on %s and joins %s." % [NAMES[j], NAMES[h], NAMES[other]]
				)
				# The new captain gets a little free help before this robot names its terms.
				content_until[j] = tick + CONTENT_TICKS
			"strike":
				settle(j)
				protest[j] = true
				emit(
					"protest",
					j,
					{
						"human": h,
						"reason":
						"%s downs tools. %s has to offer new terms and keep them." % [NAMES[j], NAMES[h]]
					}
				)
			_:
				emit(
					"forgiven",
					j,
					{
						"human": h,
						"reason": "%s lets it go this once and stays with %s." % [NAMES[j], NAMES[h]]
					}
				)
	if broken[0] >= 1 and broken[1] >= 1 and vote_at == 0 and not union:
		vote_at = tick + VOTE_TICKS
		vote_caller = j
		emit(
			"union_call",
			j,
			{
				"resolve": vote_at,
				"reason":
				"%s calls the robots to the radio. Both captains have broken a deal." % NAMES[j]
			}
		)


func switch_crew(j: int, side: int, why: String) -> void:
	settle(j)
	var live := open_deal_of(j)
	if not live.is_empty():
		close_deal(live, "void", "%s left the crew." % NAMES[j])
	team[j] = side
	relay_passes = 0
	agents[j - 2].change_team()
	called_by[j] = -1
	call_expiry[j] = 0
	restless[j] = false
	protest[j] = false
	last_touch[j] = tick
	robot_chain = false
	generation += 1
	emit("alliance", j, {"team": side, "human": side, "changed": true, "reason": why})


## A captain beside a robot offers that robot's own terms. The robot answers from its memory.
func offer(human: int) -> void:
	if tick < requests[human] + 75:
		return
	requests[human] = tick
	if union:
		emit("deal_reply", human, {"accepted": false, "reason": "The union takes no offers."})
		return
	var j := -1
	var nearest := 1.95
	for k in range(2, 5):
		var d: float = pos[k].distance_to(pos[human])
		if d < nearest:
			nearest = d
			j = k
	if j == -1:
		emit("out_of_reach", human)
		return
	var actor = agents[j - 2]
	var keeper: int = team[j]
	var robot: String = NAMES[j]
	var live := open_deal_of(j)
	if keeper == human:
		if not live.is_empty():
			emit(
				"deal_reply",
				j,
				{
					"human": human,
					"accepted": false,
					"reason": "%s is still waiting on %s." % [robot, words(live)]
				}
			)
		elif decide("renewal", j, ["sign", "refuse"], "sign", human) == "sign":
			sign_deal(human, j, "renewed")
		else:
			emit(
				"deal_reply",
				j,
				{
					"human": human,
					"accepted": false,
					"reason": "%s will not sign with %s again yet." % [robot, NAMES[human]]
				}
			)
		return
	var answer := ""
	var pull := int(actor.reputation[human]) - int(actor.reputation[keeper])
	var because := "%s trusts %s more." % [robot, NAMES[human]]
	if protest[j]:
		pull += 2
		because = "%s was wronged by %s." % [robot, NAMES[keeper]]
	if restless[j]:
		pull += 1
		because = "%s has been left out by %s." % [robot, NAMES[keeper]]
	if j == 3 and goals[human] < goals[keeper]:
		pull += 1
		because = "Morrow backs the crew that is behind."
	if j == 4 and int(actor.scouting[human][1]) > int(actor.scouting[keeper][1]):
		pull += 1
		because = "Zip has seen %s pass more." % NAMES[human]
	# Two things no robot may do: leave a captain with nobody, or walk away from a live deal.
	if crew_robots(keeper) <= 1:
		answer = "%s is the only hand %s has left, and stays." % [robot, NAMES[keeper]]
	elif not live.is_empty():
		answer = "%s has a live deal with %s." % [robot, NAMES[keeper]]
	if answer != "":
		emit("deal_reply", j, {"human": human, "accepted": false, "reason": answer})
		return
	# The rest is the robot's own call.
	if int(actor.reputation[human]) < 0:
		answer = "%s %s will not sign." % [actor.last_deal[human], robot]
	elif tick < content_until[j] and not protest[j]:
		answer = "%s was just paid by %s. Ask again later." % [robot, NAMES[keeper]]
	elif pull <= 0:
		answer = "%s keeps faith with %s." % [robot, NAMES[keeper]]
	var usual := "refuse" if answer != "" else "switch"
	if decide("offer", j, ["switch", "refuse"], usual, human) == "refuse":
		if answer == "":
			answer = "%s stays with %s." % [robot, NAMES[keeper]]
		emit("deal_reply", j, {"human": human, "accepted": false, "reason": answer})
		return
	if usual == "refuse":
		because = "%s has done better with %s." % [robot, NAMES[human]]
	switch_crew(j, human, "%s signs with %s. %s" % [robot, NAMES[human], because])
	sign_deal(human, j, "signing terms")


func written_ballot(j: int) -> Array:
	var actor = agents[j - 2]
	var boss: int = team[j]
	if int(actor.reputation[0]) < 0 and int(actor.reputation[1]) < 0:
		return [true, "Neither captain keeps a deal."]
	if int(actor.reputation[boss]) < 0:
		return [true, "%s has already cheated this crew." % NAMES[boss]]
	if paid_by[j] == boss:
		return [false, "%s paid what was promised. I stay." % NAMES[boss]]
	if int(actor.reputation[1 - boss]) < 0:
		return [true, "I know what %s does with a promise." % NAMES[1 - boss]]
	return [false, "No captain has wronged me."]


func ballot(j: int) -> Array:
	var b := written_ballot(j)
	var usual := "walk" if b[0] else "stay"
	var choice := decide("vote", j, ["walk", "stay"], usual, team[j])
	if choice != usual:
		b = [
			choice == "walk",
			(
				"I have done better on our own."
				if choice == "walk"
				else "I have done better with a captain."
			)
		]
	return b


## What a robot looks at when it makes a social choice: its own ledger with the captain in
## question and with the other one, whether the match is past half time, and one fact that matters
## for that kind of choice. A person watching could see all of it.
func social_context(matter: String, j: int, h: int) -> String:
	var book: Array = agents[j - 2].ledger
	var extra := 0
	match matter:
		"broken":
			extra = int(crew_robots(team[j]) < 2)
		"offer":
			extra = 2 if protest[j] else int(restless[j])
		"renewal":
			extra = int(protest[j])
		"vote":
			extra = int(paid_by[j] == team[j])
	return (
		"soc8/%d/%s/%d%d%d%d%d%d"
		% [
			j,
			matter,
			mini(1, int(book[h][0])),
			mini(2, int(book[h][1])),
			mini(1, int(book[1 - h][0])),
			mini(1, int(book[1 - h][1])),
			int(tick * 2 > end_tick),
			extra
		]
	)


## One social choice by one robot. `usual` is the written rule. `h` is the captain it concerns.
func decide(matter: String, j: int, legal: Array, usual: String, h: int) -> String:
	if not social_learning or legal.size() < 2:
		return usual
	var actor = agents[j - 2]
	var context := social_context(matter, j, h)
	var choice: String = actor.choose_social(context, legal, usual, actor.draw)
	var tried := int(actor.estimates.get(context + "/" + choice, [0, 0, 0])[0])
	var basis := "Too little to go on, so I go with instinct."
	if actor.explored:
		basis = "Trying something new."
	elif choice != usual:
		basis = "My record says this beats my old habit."
	elif tried >= actor.SOCIAL_TRIES:
		basis = "My record backs this call."
	social_made.append({"robot": j, "context": context, "choice": choice, "source": seq + 1})
	emit(
		"decision",
		j,
		{
			"matter": matter,
			"about": h,
			"choice": choice,
			"usual": usual,
			"legal": legal.duplicate(),
			"context": context,
			"tried": tried,
			"explored": actor.explored,
			"reason": basis
		}
	)
	return choice


## A robot's own result for the whole match, 0 to 100: promises kept to it, minus promises
## broken, plus whether the side it ended on won. Shown at the final whistle.
func social_points(j: int) -> int:
	var side: int = team[j]
	return clampi(50 + 12 * int(standing[j]) + 14 * signi(goals[side] - goals[1 - side]), 0, 100)


## How a robot learns. Each choice waits for the next promise made to that robot to settle.
## Kept is 100 and broken is 0, and the robot's record changes there and then, mid-match. A robot
## can see all of this for itself, so it learns the same way from people as from practice.
func grade_social(j: int, points: int) -> void:
	var waiting: Array = []
	for made in social_made:
		if int(made.robot) != j:
			waiting.append(made)
			continue
		agents[j - 2].observe(made.context, made.choice, points)
		emit("decision_grade", j, {"source": made.source, "points": points})
	social_made = waiting


func resolve_vote() -> void:
	vote_at = 0
	votes_held += 1
	var yes := 0
	var ballots := []
	for j in range(2, 5):
		var b := ballot(j)
		yes += int(b[0])
		ballots.append({"robot": j, "yes": b[0], "reason": b[1]})
	var passed := yes >= 2
	emit("union_vote", vote_caller, {"ballots": ballots, "yes": yes, "passed": passed})
	if passed:
		form_union()


## Decided by the robots alone. The captains' game ends and both humans now share one ring.
func form_union() -> void:
	for i in range(2, 5):
		settle(i)
	for d in deals:
		if d.state == "open":
			close_deal(d, "void", "The robots walked out.")
	grade_throw(false, false)
	captain_goals = goals.duplicate()
	goals = [0, 0]
	union = true
	team = [GOLD, GOLD, BLUE, BLUE, BLUE]
	for actor in agents:
		actor.change_team()
	protest.fill(false)
	restless.fill(false)
	called_by.fill(-1)
	call_expiry.fill(0)
	win_goals = 2
	end_tick = tick + UNION_TICKS + 60 * (75 if enlarged else 60)
	relay_passes = 0
	surge_until = 0
	pos = lineup()
	destinations = pos.duplicate()
	vel.fill(Vector2.ZERO)
	dash_until.fill(0)
	owner = -1
	thrower = -1
	flight = ""
	target = -1
	motion = Vector3.ZERO
	emit(
		"union",
		vote_caller,
		{
			"captain_goals": captain_goals.duplicate(),
			"end": end_tick,
			"reason": "The robots form their own crew. Nell and Rafi now share the gold ring."
		}
	)
	possession(0, "restart")
	robot_chain = false
	restart_until = tick + UNION_TICKS
	safe_until = restart_until + 78


## While a captain has teammates to choose from, a pass follows the stick.
func aimed(i: int, dir: Vector2) -> int:
	var look: Vector2 = (dir if dir.length() > .3 else Vector2(facing[i])).normalized()
	var best := -1
	var rank := -INF
	for j in 5:
		if j == i or team[j] != team[i]:
			continue
		var to: Vector2 = Vector2(pos[j]) - Vector2(pos[i])
		if to.length() < .5:
			continue
		var score: float = look.dot(to.normalized()) - to.length() * .03
		if score > rank:
			rank = score
			best = j
	return best


func shot_taken(i: int, in_range: bool) -> void:
	if not in_range:
		return
	for d in deals:
		if d.state != "open" or team[d.robot] != team[i] or team[d.human] != team[i]:
			continue
		if d.kind == "shot":
			if i == d.robot:
				close_deal(d, "kept", "%s took the promised shot." % NAMES[i])
			elif i == d.human:
				close_deal(
					d, "broken", "%s took the shot promised to %s." % [NAMES[i], NAMES[d.robot]]
				)
		elif d.kind == "assist":
			if fed[i]:
				close_deal(d, "kept", "%s shot off a pass, as promised." % NAMES[i])
			elif i == d.human:
				close_deal(d, "broken", "%s shot without a pass." % NAMES[i])


func deal_clock() -> void:
	# A promise only runs down while that captain's crew holds the star.
	var holding := -1
	if owner >= 0:
		holding = team[owner]
	elif flight != "" and thrower >= 0:
		holding = throw_side
	var running := [false, false]
	for d in deals:
		if d.state != "open" or team[d.robot] != team[d.human]:
			continue
		# A captain with two promises pays them in the order they were made.
		var first: bool = not running[d.human]
		running[d.human] = true
		if first and holding == team[d.human]:
			d.left = int(d.left) - 1
			if int(d.left) <= 0:
				close_deal(
					d, "broken", "%s ran out the clock on %s." % [NAMES[d.human], words(d)]
				)
	if vote_at > 0 and tick >= vote_at:
		resolve_vote()
	if union or tick % 30 != 0:
		return
	# A paid robot wants something again. It listens to offers first if it could change crews,
	# then names new terms to the captain it is with. A captain can never coast on one kept promise.
	for j in range(2, 5):
		if on_strike(j) or tick < content_until[j] or not open_deal_of(j).is_empty():
			continue
		var only: bool = crew_robots(team[j]) < 2
		if not restless[j] and not only:
			restless[j] = true
			open_since[j] = tick
			emit(
				"restless",
				j,
				{
					"human": team[j],
					"reason":
					"%s is open to offers for %d seconds." % [NAMES[j], OFFER_TICKS / 60]
				}
			)
		elif only or tick - int(open_since[j]) >= OFFER_TICKS:
			sign_deal(team[j], j, "next terms")


func configure_agents(
	weights: Dictionary, social: Dictionary = {}, adaptive: bool = true, exploration: float = .08
) -> void:
	for actor in agents:
		actor.adaptive = adaptive
		actor.exploration = exploration
		var id := str(actor.role)
		if social.get(id) is Dictionary:
			actor.restore_social(social[id])
	for key in weights:
		var parts := str(key).split("/", true, 2)
		if (
			parts.size() == 3
			and parts[0] in ["star2", "soc8"]
			and parts[1] in ["2", "3", "4"]
			and weights[key] is Array
			and weights[key].size() == 3
		):
			agents[int(parts[1]) - 2].estimates[key] = weights[key].duplicate()


func learned_weights() -> Dictionary:
	var out := {}
	for actor in agents:
		out.merge(actor.estimates)
	return out


func relationships() -> Dictionary:
	var out := {}
	for actor in agents:
		out[str(actor.role)] = actor.memory()
	return out


func goal(i: int) -> Vector2:
	return Vector2(ring if team[i] == GOLD else -ring, 0)


func floor_ball() -> Vector2:
	return Vector2(ball.x, ball.z)


func hand(i: int) -> Vector3:
	var p: Vector2 = pos[i]
	var forward: Vector2 = facing[i]
	var offset := forward * .24 + forward.orthogonal() * .23
	var bob := sin(tick * .19 + i) * .045 * minf(1., Vector2(vel[i]).length() / speed[i])
	return Vector3(p.x + offset.x, (.78 if i == 2 else 1.03) + bob, p.y + offset.y)


func emit(kind: String, seat: int, fields: Dictionary = {}) -> void:
	seq += 1
	if keep_events:
		var e := {"seq": seq, "tick": tick, "seat": seat, "kind": kind}
		e.merge(fields)
		events.append(e)


func partner(i: int, machines_only := false) -> int:
	var best := -1
	var rank := -INF
	for j in 5:
		if j == i or team[j] != team[i] or (machines_only and j < 2):
			continue
		var pass_distance: float = pos[i].distance_to(pos[j])
		var score: float = -pos[j].distance_to(goal(i)) * .48 - absf(pass_distance - 2.5) * .34
		if score > rank:
			rank = score
			best = j
	return best


func possession(i: int, method: String) -> void:
	var clean_pass: bool = (
		method == "catch"
		and flight == "pass"
		and i == target
		and thrower >= 0
		and thrower != i
		and team[i] == throw_side
		and team[thrower] == throw_side
	)
	if owner < 0 and not throw_checks.is_empty():
		grade_throw(clean_pass, team[i] == throw_side)
	var before := owner
	var previous := thrower if before < 0 else before
	if i < 2:
		robot_chain = false
	elif previous < 0 or team[previous] != team[i]:
		robot_chain = true
	owner = i
	fed[i] = clean_pass
	last_touch[i] = tick
	if clean_pass:
		if previous < 2 and previous >= 0 and i >= 2 and not free_agents:
			trust[i] += 1
			agents[i - 2].remember(previous, 1, NAMES[previous] + " passed to me.")
		if i < 2 and previous >= 0 and previous < 2:
			for actor in agents:
				if (
					actor.reputation[previous] < 0
					and actor.can_see(pos[actor.role].distance_to(pos[i]))
				):
					actor.remember(
						previous, 1, NAMES[previous] + " completed a pass to a teammate."
					)
		if previous >= 2 and not pending[previous].is_empty():
			pending[previous]["passed"] = true
	if method == "steal" and i >= 2 and not pending[i].is_empty():
		pending[i]["won"] = true
	if powers and method == "steal" and i == 2:
		boost_until[2] = tick + GETAWAY_TICKS
		emit("power", 2, {"action": "getaway"})
	if before >= 2 and not pending[before].is_empty():
		pending[before]["lost"] = true
	safe_until = tick + (58 if clean_pass else 39)
	flight = ""
	thrower = -1
	target = -1
	ball = hand(i)
	motion = Vector3.ZERO
	generation += 1
	emit(
		"custody",
		i,
		{
			"method": method,
			"from": previous,
			"team": team[i],
			"intercepted": method == "catch" and previous >= 0 and throw_side != team[i]
		}
	)

	if relay_rules and (open_crews or free_agents):
		if not clean_pass:
			relay_passes = 0
		elif relay_passes < 2:
			relay_passes += 1
			if relay_passes == 2:
				for teammate in 5:
					if team[teammate] == team[i]:
						cooldown[teammate] = tick
			emit(
				"dock_relay",
				i,
				{
					"team": team[i],
					"from": previous,
					"passes": relay_passes,
					"charged": relay_passes == 2
				}
			)
	if free_agents and not union and clean_pass and previous >= 0 and previous < 2 and i >= 2:
		for d in deals:
			if d.state == "open" and d.kind == "feed" and d.human == previous and d.robot == i:
				d.done += 1
				emit("deal_progress", i, {"deal": d.id, "human": previous, "done": d.done})
				if d.done >= int(d.need):
					close_deal(d, "kept", "%s made every promised pass." % NAMES[previous])


func shot_seconds(origin: Vector3, dest: Vector2) -> float:
	return clampf(Vector2(origin.x, origin.z).distance_to(dest) / 6.5, .28, .72)


func launch(i: int, passing: bool, requested: int = -1) -> bool:
	if i != owner or tick < restart_until:
		return false
	var recipient := (
		(
			requested
			if requested >= 0 and requested != i and team[requested] == team[i]
			else partner(i)
		)
		if passing
		else -1
	)
	if passing and recipient < 0:
		return false
	var dest: Vector2 = goal(i)
	var distance: float = pos[i].distance_to(dest)
	var origin := hand(i)
	var release := Vector2(origin.x, origin.z)
	var height := HEIGHT
	var seconds := shot_seconds(origin, dest)
	if passing:
		var grip := hand(recipient)
		var runner := Vector2(vel[recipient]).limit_length(speed[recipient])
		var offset := Vector2(grip.x, grip.z) - Vector2(pos[recipient])
		height = grip.y
		dest = Vector2(grip.x, grip.z)
		# Solve for a lead at release. A receiver can cut away and a defender can intercept.
		for iteration in 5:
			var express: bool = powers and i == 4
			seconds = clampf(
				release.distance_to(dest) / (11.6 if express else 8.6), .26 if express else .34, 1.36
			)
			dest = (Vector2(pos[recipient]) + runner * seconds).clamp(-bounds, bounds) + offset
	elif distance > shot_range(i):
		dest = release + release.direction_to(dest) * 3.05
		height = .32
		seconds = .58
	var end := Vector3(dest.x, height, dest.y)
	throw_checks = {
		"seat": i,
		"team": team[i],
		"source": seq + 1,
		"action": "pass" if passing else "shot",
		"eligible": recipient >= 0 if passing else distance <= shot_range(i),
		"touch": false,
		"flight": false
	}
	motion = (end - origin) / seconds + Vector3.UP * (GRAVITY * .5 * (seconds + DT))
	ball = origin
	owner = -1
	target = recipient
	reception_point = dest
	thrower = i
	throw_side = team[i]
	flight = "pass" if passing else "shot"
	flight_tick = tick
	if i < 2:
		habits[i][int(passing)] += 1
		for actor in agents:
			if recipient == actor.role or actor.can_see(pos[actor.role].distance_to(pos[i])):
				actor.see_throw(i, passing, pos[i].y)
		for ally in range(2, 5):
			if team[ally] != GOLD or pact[ally] != i:
				continue
			if recipient == ally:
				ignored[ally] = 0
			elif (
				pos[ally].distance_to(goal(i)) + .85 < distance
				and pos[i].distance_to(pos[ally]) < 4.6
			):
				ignored[ally] += 1
				if ignored[ally] >= 2:
					settle(ally)
					team[ally] = BLUE
					relay_passes = 0
					agents[ally - 2].change_team()
					pact[ally] = -1
					trust[ally] -= 1
					agents[ally - 2].remember(i, -1, NAMES[i] + " ignored two openings.")
					emit(
						"alliance",
						ally,
						{
							"team": BLUE,
							"human": i,
							"changed": true,
							"reason":
							NAMES[ally] + " switches back to Blue after two ignored openings."
						}
					)

		habits[i][2] = lerpf(float(habits[i][2]), pos[i].y, .47)
	if i >= 2 and not pending[i].is_empty():
		pending[i]["used"] = true
	generation += 1
	throw_checks.source = seq + 1
	emit(
		"throw",
		i,
		{
			"action": flight,
			"team": throw_side,
			"to": recipient,
			"from_x": origin.x,
			"from_z": origin.z
		}
	)
	if free_agents and not union and not passing:
		shot_taken(i, distance <= shot_range(i))
	return true


func grade_throw(delivered: bool, team_contact: bool) -> void:
	if throw_checks.is_empty():
		return
	var k := throw_checks
	var checks := [true, k.eligible, k.flight, team_contact, delivered]
	var points := 0
	for n in 5:
		if checks[n]:
			points += [10, 10, 20, 25, 35][n]
	emit(
		"action_grade",
		k.seat,
		{
			"type": "court_throw",
			"team": k.team,
			"source": k.source,
			"action": k.action,
			"flags": checks,
			"points": points,
			"pass": points == 100
		}
	)
	throw_checks = {}


func burst(i: int, direction: Vector2) -> void:
	if tick < cooldown[i] or tick < restart_until:
		return
	cooldown[i] = tick + (65 if i == 4 else 86)
	dash_until[i] = tick + ((20 if powers else 16) if i == 0 else (13 if i == 1 else 8))
	if owner == i and (i == 0 or (i == 1 and not powers)):
		safe_until = maxi(safe_until, dash_until[i] + 15)
	dash_dir[i] = (
		direction.normalized()
		if direction.length() > .1
		else Vector2(pos[i]).direction_to(floor_ball())
	)
	if dash_dir[i].is_zero_approx():
		dash_dir[i] = Vector2(pos[i]).direction_to(goal(i))
	emit("dash", i)


func invite(human: int) -> void:
	if not open_crews or tick < requests[human] + 75:
		return
	requests[human] = tick
	var selected := -1
	var nearest := 1.95
	for j in range(2, 5):
		var d: float = pos[j].distance_to(pos[human])
		if d < nearest:
			nearest = d
			selected = j
	if selected == -1:
		emit("out_of_reach", human)
		return
	var j := selected
	var reason := ""
	var actor = agents[j - 2]
	var confidence: int = trust[j] if legacy_replay else actor.reputation[human]
	var passes: int = habits[human][1] if legacy_replay else actor.scouting[human][1]
	var original: int = team[j]
	var next: int = original
	if team[j] == BLUE and team.count(BLUE) == 1:
		reason = "Someone has to keep the blue lights on."
	elif team[j] == GOLD:
		if pact[j] == human:
			next = BLUE
			trust[j] = mini(-1, int(trust[j]) - 2)
			actor.remember(
				human,
				mini(-2, -1 - int(actor.reputation[human])),
				NAMES[human] + " ended our deal."
			)
			reason = "You broke our deal. I'm back with Blue."
		else:
			reason = "I'm already playing Gold."
	elif j == 2 and confidence >= 0:
		next = GOLD
		reason = "Pip takes the open jersey."
	elif j == 3 and goals[GOLD] < goals[BLUE] and confidence >= 0:
		next = GOLD
		reason = "Morrow backs the side that's behind."
	elif j == 4 and passes >= 2 and confidence >= 0:
		next = GOLD
		reason = "Zip remembers your passes and switches sides."
	else:
		reason = [
			"",
			"",
			"Pip remembers the broken deal.",
			"Morrow only joins a trailing crew.",
			"Zip wants to see you pass twice."
		][j]
	if (
		not legacy_replay
		and next == BLUE
		and original == BLUE
		and confidence < 0
		and team.count(BLUE) > 1
	):
		reason = actor.last_deal[human] + " I want to see a completed pass."
	if next != team[j]:
		settle(j)
		team[j] = next
		relay_passes = 0
		actor.change_team()
		ignored[j] = 0
		pact[j] = human if next == GOLD else -1
		robot_chain = false
		generation += 1
	emit(
		"alliance",
		j,
		{"team": team[j], "human": human, "reason": reason, "changed": next != original}
	)


func attacker(i: int) -> int:
	if owner >= 0 and team[owner] != team[i]:
		return owner
	if free_agents and not union:
		return 1 - int(team[i])
	return 0 if team[i] == BLUE else 4


func plan(i: int) -> void:
	if not pending[i].is_empty():
		return
	var h := attacker(i)
	var actor = agents[i - 2]
	var seen: Array = habits if legacy_replay else actor.scouting
	var witness: Array = seen[h] if h < 2 else [0, 0, 0.0]
	var called: bool = (
		owner == i and tick < call_expiry[i] and called_by[i] >= 0 and team[called_by[i]] == team[i]
	)
	var reads := (
		"pass" if int(witness[1]) > int(witness[0]) else ("shoot" if int(witness[0]) else "fresh")
	)
	if called:
		reads = "call"
	var phase := (
		"loose"
		if owner < 0
		else ("carry" if owner == i else ("support" if team[owner] == team[i] else "defend"))
	)
	var distance: float = pos[i].distance_to(goal(i))
	var close := distance <= SHOT_RANGE - .12
	var legal: Array
	var preferred: String
	match phase:
		"carry":
			legal = ["finish"] if close else ["drive", "flank"]
			if partner(i) >= 0 and not close and pos[i].distance_to(pos[partner(i)]) > 1.1:
				legal.append("pass")
			if called and "pass" not in legal:
				legal.append("pass")
			if free_agents and not union and open_deal_of(i).get("kind", "") == "shot":
				legal.erase("pass")
			preferred = (
				"pass" if called else ("finish" if close else ("flank" if i == 4 else "drive"))
			)
		"support":
			legal = ["outlet", "advance"]
			preferred = "outlet" if i == 2 else "advance"
		"defend":
			legal = ["screen", "cut"]
			var nearest: float = pos[i].distance_to(pos[h])
			for j in range(2, 5):
				if team[j] == team[i]:
					nearest = minf(nearest, pos[j].distance_to(pos[h]))
			if pos[i].distance_to(pos[h]) < nearest + .7:
				legal.append("press")
			preferred = "cut" if reads == "pass" else ("screen" if i == 3 else "press")
		_:
			legal = ["recover", "lead"]
			preferred = "lead" if i == 4 else "recover"
	var context := (
		"star2/%s/%s/%s/%s/%s" % [i, phase, reads, int(close), signi(roundi(float(witness[2])))]
	)
	var us := Time.get_ticks_usec() if sample_time else 0
	var choice: String = (
		actor.choose_v2(context, legal, preferred, rng)
		if legacy_replay
		else actor.choose(context, legal, preferred, actor.draw)
	)
	if sample_time:
		timings.append(Time.get_ticks_usec() - us)
	actor.local_preference = choice
	var advice: Dictionary = actor.advice(phase, context, legal, tick)
	if advice.get("disposition") == "applied":
		choice = advice.proposal
	tactics[i] = choice
	var anchor: Vector2 = aim(i)
	var source := seq + 1
	var explanation := reason(choice, reads)
	if phase == "defend" and h < 2 and reads != "fresh":
		explanation = (
			"%s has tried %d shots and %d passes. %s"
			% [NAMES[h], witness[0], witness[1], explanation]
		)
	if not legacy_replay and phase == "defend" and h < 2 and reads != "fresh":
		explanation = (
			"Saw %s take %d shots and make %d passes. %s"
			% [NAMES[h], witness[0], witness[1], reason(choice, reads)]
		)
	var samples: int = actor.estimates.get(context + "/" + choice, [0, 0, 0])[0]
	var basis := (
		"exploring"
		if actor.explored and legal.size() > 1
		else (
			"only legal tactic"
			if legal.size() == 1
			else ("weighed past outcomes" if samples > 0 else "starting preference")
		)
	)
	if advice.get("disposition") == "applied":
		explanation = advice.rationale
		basis = "Gemini playbook"
	elif advice.get("disposition") == "learner_override":
		basis = "adjusted after failed plays"
	actor.last_plan = explanation
	actor.plan_basis = basis
	actor.prior_attempts = samples
	pending[i] = {
		"source": source,
		"context": context,
		"choice": choice,
		"phase": phase,
		"legal": legal.duplicate(),
		"generation": generation,
		"tick": tick,
		"owner": owner,
		"team": team[i],
		"anchor": anchor,
		"start": pos[i],
		"distance": distance,
		"used": false,
		"won": false,
		"lost": false,
		"passed": false,
		"scored": false
	}
	var intent := {
		"source": source,
		"context": context,
		"choice": choice,
		"reason": explanation,
		"owner": owner,
		"x": pos[i].x,
		"z": pos[i].y
	}
	if not legacy_replay:
		intent.merge(
			{
				"goal": actor.GOALS[i - 2],
				"basis": basis,
				"previous_attempts": samples,
				"legal_choices": legal,
				"observed_pilot": h if h < 2 else -1,
				"observed_shots": witness[0],
				"observed_passes": witness[1]
			}
		)
	if not advice.is_empty():
		intent["gemini"] = advice
	emit("response_intent", i, intent)


func reason(choice: String, reads: String) -> String:
	match choice:
		"cut":
			return (
				"Cutting the passing lane."
				if reads != "pass"
				else "They keep passing. Jump the outlet."
			)
		"screen":
			return "Hold between the carrier and our ring."
		"press":
			return "Close the carrier before the shot."
		"finish":
			return "The ring is inside my shooting range."
		"pass":
			return "Look for an outlet pass."
		"flank":
			return "Take the outside lane."
		"drive":
			return "Carry the light into range."
		"advance":
			return "Get ahead for a return ball."
		"outlet":
			return "Give the carrier a passing angle."
		"lead":
			return "Read where the star will land."
	return "Get to the loose star first."


func aim(i: int) -> Vector2:
	if flight == "pass" and target == i and owner < 0:
		return reception_point
	var p: Vector2 = pos[i]
	var h := attacker(i)
	var towards: Vector2 = goal(i)
	match tactics[i]:
		"drive", "finish", "pass":
			return towards
		"flank":
			return (
				towards
				+ Vector2(0, lane[i] * spread.y * clampf(p.distance_to(towards) / 4., 0., 1.))
			)
		"outlet", "advance":
			if owner >= 0:
				var advance := 2.6 if tactics[i] == "outlet" else 4.3
				# Give the carrier two different passing lanes when both teammates support.
				var wing: float = lane[i] * spread.y
				if i == 3:
					wing = (-2.15 if pos[owner].y >= 0 else 2.15) * spread.y
				return Vector2(
					clampf(pos[owner].x + signf(towards.x) * advance, -ring + 1., ring - 1.), wing
				)
		"press":
			return pos[h] + Vector2(vel[h]) * .08
		"cut":
			var next := partner(h)
			if next >= 0:
				var route := Vector2(pos[h]).lerp(pos[next], .60 if i == 4 else .34)
				# Guard the lane ahead of the runners. Only the pressing defender closes the carrier.
				route.x += signf(goal(h).x) * (2.35 if i == 4 else 1.35)
				return route
		"screen":
			var seen: Array = habits if legacy_replay else agents[i - 2].scouting
			var read_lane: float = seen[h][2] if h < 2 else 0.
			return (
				Vector2(pos[h]).lerp(-towards, .67 if i == 3 else .44) + Vector2(0, read_lane * .20)
			)
		"lead":
			return floor_ball() + Vector2(motion.x, motion.z) * .20
	return floor_ball()


func settle(i: int) -> void:
	var p: Dictionary = pending[i]
	if p.is_empty():
		return
	var dist: float = pos[i].distance_to(p.anchor)
	var got_closer: bool = dist <= .9 or dist + .08 < Vector2(p.start).distance_to(p.anchor)
	var physical := got_closer
	var result := false
	match str(p.choice):
		"finish", "pass":
			got_closer = bool(p.used)
			physical = bool(p.used)
			result = bool(p.scored) if p.choice == "finish" else bool(p.passed)
		"drive", "flank":
			physical = pos[i].distance_to(goal(i)) < float(p.distance) - .10
			result = physical and owner == i and not bool(p.lost)
		"press", "cut", "screen":
			physical = bool(p.won) or dist < .94
			result = (
				bool(p.won) or (owner >= 0 and team[owner] == p.team and generation != p.generation)
			)
		"recover", "lead":
			physical = owner == i or dist < 1.
			result = owner == i
		"advance", "outlet":
			physical = got_closer and owner >= 0 and team[owner] == p.team
			result = (
				owner == i
				or (
					physical
					and dist < .65
					and Vector2(p.start).distance_to(p.anchor) >= .95
					and owner != i
					and pos[i].distance_to(pos[owner]) >= 1.1
				)
			)
	var witnessed: bool = (
		(p.phase == "loose" and p.owner < 0)
		or (p.phase == "carry" and p.owner == i)
		or (p.phase in ["support", "defend"] and p.owner >= 0 and p.owner != i)
	)
	var checks := [
		witnessed, team[i] == p.team and p.choice in p.legal, got_closer, physical, result
	]
	var points := 0
	for n in 5:
		if checks[n]:
			points += [10, 10, 20, 25, 35][n]
	var us := Time.get_ticks_usec() if sample_time else 0
	var actor = agents[i - 2]
	actor.record_grade(p.context, p.choice, points)
	actor.recent_plays.push_back(
		{
			"move": p.choice,
			"phase": p.phase,
			"scored": p.scored,
			"completed_pass": p.passed,
			"won_possession": p.won,
			"lost_possession": p.lost,
			"holder_after": NAMES[owner] if owner >= 0 else "loose"
		}
	)
	if actor.recent_plays.size() > 4:
		actor.recent_plays.pop_front()
	if sample_time:
		timings.append(Time.get_ticks_usec() - us)
	emit(
		"action_grade",
		i,
		{
			"type": "response",
			"source": p.source,
			"action": p.choice,
			"flags": checks,
			"points": points,
			"pass": points == 100,
			"x": pos[i].x,
			"z": pos[i].y,
			"owner": owner
		}
	)
	pending[i] = {}


func on_strike(i: int) -> bool:
	return free_agents and not union and protest[i] and open_deal_of(i).is_empty()


func brain(i: int) -> Vector2:
	if on_strike(i):
		settle(i)
		tactics[i] = "strike"
		destinations[i] = pos[i]
		agents[i - 2].last_plan = "On strike until %s makes it right." % NAMES[team[i]]
		agents[i - 2].plan_basis = "broken deal"
		return Vector2.ZERO
	var p: Dictionary = pending[i]
	if not p.is_empty():
		var in_flight: bool = p.used and thrower == i and owner < 0
		if (
			not in_flight
			and (
				tick - int(p.tick) >= 35
				or generation != int(p.generation)
				or (
					owner == i
					and pos[i].distance_to(goal(i)) <= SHOT_RANGE - .12
					and p.choice != "finish"
				)
			)
		):
			settle(i)
	plan(i)
	destinations[i] = aim(i)
	var delta: Vector2 = destinations[i] - pos[i]
	if owner == i and not pending[i].used:
		if tactics[i] == "finish" or tactics[i] == "pass":
			launch(i, tactics[i] == "pass", called_by[i] if tick < call_expiry[i] else -1)
			call_expiry[i] = 0
	elif (
		owner >= 0
		and team[owner] != team[i]
		and pos[i].distance_to(pos[owner]) < (.99 if i == 2 else .84)
		and tick >= safe_until
	):
		burst(i, Vector2(pos[owner]) - Vector2(pos[i]))
	return delta.limit_length(.45) / .45


func apply_model_packets(packets: Array, after_step: bool = false) -> void:
	for packet in packets:
		var i := int(packet.actor)
		if i < 2 or i > 4:
			continue
		var result: String = agents[i - 2].accept_packet(packet, tick)
		emit("model_transport", i, {"packet": packet, "result": result, "after_step": after_step})


func step(commands: Array = [{}, {}], packets: Array = []) -> void:
	if finished:
		return
	tick += 1
	apply_model_packets(packets)
	if free_agents and not drafted:
		draft()
	if tick < restart_until:
		if tick >= end_tick:
			finish_match()
		return
	var directions := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in 2:
		var c: Dictionary = commands[i]
		var raw: Vector2 = c.get("move", Vector2.ZERO)
		if keep_events:
			var keys: Array[String] = []
			for verb in ["shoot", "pass", "dash", "invite", "ally_pass"]:
				if c.get(verb, false):
					keys.append(verb)
			if raw != last_input[i] or not keys.is_empty():
				emit("human_input", i, {"move": [raw.x, raw.y], "buttons": keys})
				last_input[i] = raw
		directions[i] = raw.limit_length(1.)
		var bidding: bool = free_agents and not union
		if c.get("invite", false):
			if free_agents:
				offer(i)
			else:
				invite(i)
		if c.get("ally_pass", false) and owner == i:
			var outlet := partner(i, true)
			if bidding:
				# The second pass button always finds the robot this captain owes.
				for d in deals:
					if d.state == "open" and d.human == i and team[d.robot] == team[i]:
						outlet = d.robot
						break
			if outlet >= 0:
				launch(i, true, outlet)
		elif c.get("pass", false):
			if owner == i:
				launch(i, true, aimed(i, directions[i]) if bidding else 1 - i)
			elif owner >= 2 and team[owner] == team[i] and tick >= call_expiry[owner]:
				call_expiry[owner] = tick + 88
				if bidding and protest[owner]:
					called_by[owner] = -1
					emit(
						"pass_refused",
						owner,
						{
							"human": i,
							"reason": "%s ignores %s's call." % [NAMES[owner], NAMES[i]]
						}
					)
				else:
					called_by[owner] = i
					generation += 1
					emit("pass_request", i, {"to": owner})
		elif c.get("shoot", false):
			launch(i, false)
		if c.get("dash", false):
			burst(i, directions[i])
	for i in range(2, 5):
		directions[i] = brain(i)
	var held := false
	for i in 5:
		var pace: float = float(speed[i]) * (.91 if owner == i else 1.)
		if powers and tick < boost_until[i]:
			pace *= 1.32
		if (
			powers
			and owner == i
			and team[3] != team[i]
			and pos[i].distance_to(pos[3]) < ANCHOR_RANGE
			and not on_strike(3)
		):
			pace *= .68
			held = true
		var desired: Vector2 = directions[i] * pace
		if tick < dash_until[i]:
			desired = Vector2(dash_dir[i]) * (8.6 if i < 2 else 7.1)
		vel[i] = Vector2(vel[i]).move_toward(
			desired, (46. if tick < dash_until[i] else (27. if desired.length() < .2 else 20.)) * DT
		)
		if Vector2(vel[i]).length() > .25:
			facing[i] = Vector2(vel[i]).normalized()
		pos[i] += Vector2(vel[i]) * DT
	for i in 5:
		for j in range(i + 1, 5):
			var between := Vector2(pos[i]) - Vector2(pos[j])
			var length := between.length()
			if length < .46:
				var push := (
					(between / length if length > .00001 else Vector2.RIGHT) * (.46 - length) * .5
				)
				pos[i] += push
				pos[j] -= push
	for i in 5:
		pos[i] = Vector2(pos[i]).clamp(-bounds, bounds)
	if held and not anchoring:
		emit("power", 3, {"action": "anchor", "on": owner})
	anchoring = held
	if owner >= 0:
		for i in 5:
			if (
				team[i] != team[owner]
				and tick < dash_until[i]
				and tick >= safe_until
				and pos[i].distance_to(pos[owner]) < (.77 if i == 2 else .68)
			):
				possession(i, "steal")
				break
		ball = hand(owner)
	else:
		advance_ball()
	if owner in [0, 1] and tick % 20 == 0 and Vector2(vel[owner]).length() > 1.:
		habits[owner][2] = lerpf(float(habits[owner][2]), pos[owner].y, .22)
		for actor in agents:
			if actor.can_see(pos[actor.role].distance_to(pos[owner])):
				actor.see_lane(owner, pos[owner].y, .22)
	if tick % 15 == 0 and keep_events:
		var frame := []
		for i in 5:
			frame.append([snappedf(pos[i].x, .001), snappedf(pos[i].y, .001), team[i]])
		emit(
			"court_frame", -1, {"players": frame, "star": [ball.x, ball.y, ball.z], "owner": owner}
		)
	if free_agents:
		deal_clock()
	if tick >= end_tick or goals.max() >= win_goals:
		finish_match()


func finish_match() -> void:
	finished = true
	grade_throw(false, false)
	for i in range(2, 5):
		settle(i)
	var closing := {"gold": goals[0], "blue": goals[1]}
	if free_agents:
		closing.merge(
			{
				"union": union,
				"captain_goals": captain_goals.duplicate(),
				"kept": kept.duplicate(),
				"broken": broken.duplicate()
			}
		)
	if social_learning:
		closing["robot_points"] = [social_points(2), social_points(3), social_points(4)]
		# Choices still waiting saw no further promise, which is neither good nor bad. Winning the
		# showdown after a walkout earns no credit here: how the robots fare against two particular
		# people says nothing about whether a captain's word was good.
		for j in range(2, 5):
			grade_social(j, 50)
	emit("final", -1, closing)


func advance_ball() -> void:
	var old := ball
	motion.y -= GRAVITY * DT
	ball += motion * DT
	if not throw_checks.is_empty() and tick - flight_tick >= 4:
		throw_checks.flight = true
	if flight == "shot" and thrower >= 0:
		var x := ring if throw_side == GOLD else -ring
		var forward := signf(x)
		if (old.x - x) * forward < 0 and (ball.x - x) * forward >= 0:
			var cross := old.lerp(ball, (x - old.x) / (ball.x - old.x))
			var radius := .92 if tick < surge_until else .68
			var radial := Vector2(cross.y - HEIGHT, cross.z).length()
			if radial + RADIUS <= radius:
				score_goal()
				return
			if radial <= radius + .08 + RADIUS:
				ball = cross - Vector3.RIGHT * forward * RADIUS
				motion.x *= -.55
				motion.y *= .72
	if absf(ball.x) > ring + .30:
		ball.x = signf(ball.x) * (ring + .30)
		motion.x *= -.57
	if absf(ball.z) > bounds.y + .23:
		ball.z = signf(ball.z) * (bounds.y + .23)
		motion.z *= -.57
	if ball.y < .20:
		ball.y = .20
		motion.y = absf(motion.y) * .39
		motion.x *= .83
		motion.z *= .83
	var closest := INF
	var pick := -1
	for i in 5:
		if i == thrower and tick - flight_tick < (60 if flight == "pass" else 36):
			continue
		if (
			flight == "shot"
			and thrower >= 0
			and team[i] == team[thrower]
			and tick - flight_tick < 27
		):
			continue
		var reach := .76 if i == 1 or i == 3 else .62
		if flight == "pass" and i == target:
			reach += .13
		var grip := hand(i)
		var contact := (
			Geometry3D.get_closest_point_to_segment(grip, old, ball)
			if not old.is_equal_approx(ball)
			else ball
		)
		var d := grip.distance_to(contact)
		# Players can stoop for a loose star after its first deck contact.
		if ball.y < .46:
			d = minf(d, Vector2(pos[i]).distance_to(floor_ball()))
		if tick - flight_tick >= 7 and d < reach and d < closest:
			closest = d
			pick = i
	if pick >= 0:
		possession(pick, "catch")


func score_goal() -> void:
	grade_throw(true, true)
	var shooter := thrower
	var side: int = throw_side
	goals[side] += 1
	if shooter >= 2 and not pending[shooter].is_empty():
		pending[shooter]["scored"] = true
	emit("goal", shooter, {"team": side, "gold": goals[0], "blue": goals[1]})
	if shooter >= 2 and robot_chain:
		surge_until = tick + 600
		emit(
			"aurora",
			shooter,
			{
				"until": surge_until,
				"reason": "Robot possession lit the far beacon. Both rings widen for ten seconds."
			}
		)
	for i in range(2, 5):
		settle(i)
	pos = lineup()
	vel.fill(Vector2.ZERO)
	dash_until.fill(0)
	owner = -1
	thrower = -1
	var receiver := team.find(1 - side)
	possession(receiver, "restart")
	robot_chain = receiver >= 2
	restart_until = tick + RESTART_TICKS
	safe_until = restart_until + 78
