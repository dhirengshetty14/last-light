extends RefCounted
## Fixed-tick court shared by keyboard players, trained robots and the headless gym.
const Policy = preload("res://learning/star_policy.gd")
const Agent = preload("res://game/star_agent.gd")
const NAMES = ["Nell", "Rafi", "Pip", "Morrow", "Zip"]
const START = [
	Vector2(-.48, 1.22),
	Vector2(.85, -1.50),
	Vector2(1.33, -.26),
	Vector2(3.82, .70),
	Vector2(2.35, -1.62)
]
const SPEED = [3.65, 3.8, 3.35, 3.15, 4.05]
const DT = 1.0 / 60.0
const END = 60 * 100
const RING = 5.28
const HEIGHT = 1.32
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
var robot_chain := false
var surge_until := 0
var restart_until := 0
var open_crews := false
var finished := false
var keep_events := true
var last_input: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var timings: Array[int] = []
var sample_time := false
var lane := [.85, -.9, .95, -.6, -1.25]


func setup(seed_value: int, crews: bool) -> void:
	rng.seed = seed_value
	for actor in agents:
		actor.draw.seed = seed_value ^ (int(actor.role) * 0x9e3779b9)
	open_crews = crews
	ball = hand(owner)


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
			and parts[0] == "star2"
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
		out[str(actor.role)] = actor.social_snapshot()
	return out


func goal(i: int) -> Vector2:
	return Vector2(RING if team[i] == GOLD else -RING, 0)


func floor_ball() -> Vector2:
	return Vector2(ball.x, ball.z)


func hand(i: int) -> Vector3:
	var p: Vector2 = pos[i]
	return Vector3(p.x, .87 if i == 2 else 1.06, p.y + .16)


func emit(kind: String, seat: int, fields: Dictionary = {}) -> void:
	seq += 1
	if keep_events:
		var e := {"seq": seq, "tick": tick, "seat": seat, "kind": kind}
		e.merge(fields)
		events.append(e)


func partner(i: int) -> int:
	var best := -1
	var rank := -INF
	for j in 5:
		if j == i or team[j] != team[i]:
			continue
		var pass_distance: float = pos[i].distance_to(pos[j])
		var score: float = -pos[j].distance_to(goal(i)) * .48 - absf(pass_distance - 2.5) * .34
		if score > rank:
			rank = score
			best = j
	return best


func possession(i: int, method: String) -> void:
	if owner < 0 and not throw_checks.is_empty():
		grade_throw(
			i == target and flight == "pass",
			i == target or (thrower >= 0 and team[i] == team[thrower])
		)
	var before := owner
	var previous := thrower if before < 0 else before
	if i < 2:
		robot_chain = false
	elif previous < 0 or team[previous] != team[i]:
		robot_chain = true
	owner = i
	if method == "catch" and flight == "pass" and i == target:
		if previous < 2 and previous >= 0 and i >= 2:
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
	if before >= 2 and not pending[before].is_empty():
		pending[before]["lost"] = true
	safe_until = tick + 35
	flight = ""
	thrower = -1
	target = -1
	ball = hand(i)
	motion = Vector3.ZERO
	generation += 1
	emit("custody", i, {"method": method, "from": previous, "team": team[i]})


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
	var height := HEIGHT
	if passing:
		dest = pos[recipient] + Vector2(vel[recipient]) * .19
		height = .96
	elif distance > 2.85:
		dest = pos[i] + Vector2(pos[i]).direction_to(dest) * 2.55
		height = .32
	else:
		dest.x += signf(dest.x) * .25
	var origin := hand(i)
	var seconds := clampf(floor_ball().distance_to(dest) / 7.4, .30, .92)
	var end := Vector3(dest.x, height, dest.y)
	throw_checks = {
		"seat": i,
		"source": seq + 1,
		"action": "pass" if passing else "shot",
		"eligible": recipient >= 0 if passing else distance <= 2.85,
		"touch": false,
		"flight": false
	}
	motion = (end - origin) / seconds + Vector3.UP * (5.5 * (seconds + DT))
	ball = origin
	owner = -1
	target = recipient
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
	emit("throw", i, {"action": flight, "to": recipient, "from_x": origin.x, "from_z": origin.z})
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
	dash_until[i] = tick + (16 if i == 0 else (13 if i == 1 else 8))
	if owner == i and i < 2:
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
	var close := distance <= 2.72
	var legal: Array
	var preferred: String
	match phase:
		"carry":
			legal = ["finish"] if close else ["drive", "flank"]
			if partner(i) >= 0 and not close and pos[i].distance_to(pos[partner(i)]) > 1.1:
				legal.append("pass")
			if called and "pass" not in legal:
				legal.append("pass")
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
	var p: Vector2 = pos[i]
	var h := attacker(i)
	var towards: Vector2 = goal(i)
	match tactics[i]:
		"drive", "finish", "pass":
			return towards
		"flank":
			return towards + Vector2(0, lane[i] * clampf(p.distance_to(towards) / 4., 0., 1.))
		"outlet", "advance":
			if owner >= 0:
				return (
					Vector2(
						clampf(
							(
								pos[owner].x
								+ signf(towards.x) * (1.65 if tactics[i] == "outlet" else 3.1)
							),
							-4.1,
							4.1
						),
						-1.35 if pos[owner].y > 0 else 1.35
					)
					+ Vector2(0, .16 * (i - 3))
				)
		"press":
			return pos[h] + Vector2(vel[h]) * .08
		"cut":
			var next := partner(h)
			if next >= 0:
				return Vector2(pos[h]).lerp(pos[next], .28)
		"screen":
			var seen: Array = habits if legacy_replay else agents[i - 2].scouting
			var read_lane: float = seen[h][2] if h < 2 else 0.
			return Vector2(pos[h]).lerp(-towards, .59) + Vector2(0, read_lane * .20)
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


func brain(i: int) -> Vector2:
	var p: Dictionary = pending[i]
	if not p.is_empty():
		var in_flight: bool = p.used and thrower == i and owner < 0
		if (
			not in_flight
			and (
				tick - int(p.tick) >= 35
				or generation != int(p.generation)
				or (owner == i and pos[i].distance_to(goal(i)) <= 2.72 and p.choice != "finish")
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
		and pos[i].distance_to(pos[owner]) < (1.22 if i == 2 else .97)
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
	if tick < restart_until:
		if tick >= END:
			finish_match()
		return
	var directions := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in 2:
		var c: Dictionary = commands[i]
		var raw: Vector2 = c.get("move", Vector2.ZERO)
		if keep_events:
			var keys: Array[String] = []
			for verb in ["shoot", "pass", "dash", "invite"]:
				if c.get(verb, false):
					keys.append(verb)
			if raw != last_input[i] or not keys.is_empty():
				emit("human_input", i, {"move": [raw.x, raw.y], "buttons": keys})
				last_input[i] = raw
		directions[i] = raw.limit_length(1.)
		if c.get("invite", false):
			invite(i)
		if c.get("pass", false):
			if owner == i:
				launch(i, true)
			elif owner >= 2 and team[owner] == team[i] and tick >= call_expiry[owner]:
				called_by[owner] = i
				call_expiry[owner] = tick + 88
				generation += 1
				emit("pass_request", i, {"to": owner})
		elif c.get("shoot", false):
			launch(i, false)
		if c.get("dash", false):
			burst(i, directions[i])
	for i in range(2, 5):
		directions[i] = brain(i)
	for i in 5:
		var desired: Vector2 = directions[i] * float(SPEED[i]) * (.91 if owner == i else 1.)
		if tick < dash_until[i]:
			desired = Vector2(dash_dir[i]) * 6.4
		vel[i] = Vector2(vel[i]).move_toward(desired, (29. if desired.length() < .2 else 23.) * DT)
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
		pos[i] = Vector2(pos[i]).clamp(Vector2(-5.07, -2.04), Vector2(5.07, 2.04))
	if owner >= 0:
		for i in 5:
			if (
				team[i] != team[owner]
				and tick < dash_until[i]
				and tick >= safe_until
				and pos[i].distance_to(pos[owner]) < (.91 if i == 2 else .76)
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
	if tick >= END or goals.max() >= 3:
		finish_match()


func finish_match() -> void:
	finished = true
	grade_throw(false, false)
	for i in range(2, 5):
		settle(i)
	emit("final", -1, {"gold": goals[0], "blue": goals[1]})


func advance_ball() -> void:
	var old := ball
	motion.y -= 11. * DT
	ball += motion * DT
	if not throw_checks.is_empty() and tick - flight_tick >= 4:
		throw_checks.flight = true
	if flight == "shot" and thrower >= 0:
		var x := RING if throw_side == GOLD else -RING
		if (old.x - x) * (ball.x - x) <= 0 and not is_equal_approx(old.x, ball.x):
			var cross := old.lerp(ball, clampf((x - old.x) / (ball.x - old.x), 0., 1.))
			if Vector2(cross.y - HEIGHT, cross.z).length() < (.92 if tick < surge_until else .68):
				score_goal()
				return
	if absf(ball.x) > 5.48:
		ball.x = signf(ball.x) * 5.48
		motion.x *= -.57
	if absf(ball.z) > 2.28:
		ball.z = signf(ball.z) * 2.28
		motion.z *= -.57
	if ball.y < .20:
		ball.y = .20
		motion.y = absf(motion.y) * .39
		motion.x *= .83
		motion.z *= .83
	var closest := INF
	var pick := -1
	for i in 5:
		if i == thrower and tick - flight_tick < 36:
			continue
		if (
			flight == "shot"
			and thrower >= 0
			and team[i] == team[thrower]
			and tick - flight_tick < 27
		):
			continue
		var reach := .60 if i == 1 or i == 3 else .51
		var d: float = pos[i].distance_to(floor_ball())
		if (
			tick - flight_tick >= 5
			and ball.y <= (1.70 if i == 3 else 1.53)
			and d < reach
			and d < closest
		):
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
	pos = START.duplicate()
	vel.fill(Vector2.ZERO)
	dash_until.fill(0)
	owner = -1
	thrower = -1
	var receiver := team.find(1 - side)
	possession(receiver, "restart")
	robot_chain = receiver >= 2
	restart_until = tick + 75
	safe_until = restart_until + 40
