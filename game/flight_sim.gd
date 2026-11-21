extends RefCounted
## Deterministic 60 Hz authority. Lengths are in centimetres and all deadlines are ticks.
const Policy = preload("res://learning/response_policy.gd")
const Contracts = preload("res://game/contracts.gd")
const Cargo = preload("res://game/cargo_body.gd")
const NAMES = ["Nell", "Rafi", "Pip", "Morrow", "Zip"]
const ZONES = ["DECK", "CEILING", "HATCH"]
const PADS = [Vector2i(-430, 30), Vector2i(0, -155), Vector2i(430, 30)]
const STARTS = [
	Vector2i(-311, 135),
	Vector2i(315, 135),
	Vector2i(-218, -104),
	Vector2i(5, -98),
	Vector2i(212, -90)
]
const LIMIT = 5400
const CATCH_WEIGHTS = [10, 15, 20, 20, 20, 15]
const RESPONSE_WEIGHTS = [15, 15, 20, 25, 25]
var seed_value: int
var tick := 0
var phase := 0
var gravity := 0
var hull := 3
var reel := -2  # pinned -2, loose -1, carrier 0..4, stowed 5
var egg_zone := 0
var hatch_at: int
var difficulty := 0
var deadline := LIMIT
var ending := ""
var seats: Array = []
var rngs: Array = []
var social = Contracts.new()
var policy = Policy.new()
var flight: Dictionary = {}
var dwell: Dictionary = {}
var quorum_axis := -1
var quorum_start := -1
var retry_at := 0
var seq := 0
var events: Array = []
var trace := true
var public_lines: Array = []
var locked_reactions: Dictionary = {}
var response_jobs: Dictionary = {}
var grades: Array = []
var causal_flips: Array = []
var human_acted := false
const RULESET := "nursery-1"
var causes: Dictionary = {}
var cargo_leg := 0
var last_catch := {}
var forecast_until := 0
var next_trade := 205


func _init(world_seed: int = 17, collect: bool = true, storm: int = 0) -> void:
	seed_value = world_seed
	difficulty = clampi(storm, 0, 1)
	if difficulty == 1:
		deadline = 3100
		hull = 2
	trace = collect
	hatch_at = (1280 if difficulty == 1 else 1770) + posmod(world_seed, 251)
	for i in 5:
		var rand := RandomNumberGenerator.new()
		rand.seed = 7907 * world_seed + 8017 * (i + 1)
		rngs.append(rand)
		seats.append(
			{
				"pos": STARTS[i],
				"vel": Vector2i.ZERO,
				"motion": Vector2i.ZERO,
				"vote": -1,
				"vote_id": 0,
				"target": 1,
				"plan": "idle",
				"next": 30 + i * 11,
				"cover": -1,
				"cover_until": 0,
				"ready": 0,
				"boost": 0,
				"pose": "Idle",
				"pose_until": 0,
				"voice": "",
				"voice_tick": -1000,
				"decision": 0,
				"status": "On station"
			}
		)

	say(-1, "The mother is alongside. Three ceiling votes will free the egg.")


func emit(kind: String, actor: int, fields: Dictionary = {}) -> int:
	seq += 1
	if kind in ["flight", "pact_broken"]:
		causes[seq] = {
			"kind": kind, "actor": actor, "phase": phase, "tick": tick, "to": fields.get("to", -1)
		}
	if trace:
		var msg := {"seq": seq, "tick": tick, "kind": kind, "seat": actor, "seed": seed_value}
		msg.merge(fields)
		events.append(msg)
	return seq


func say(seat: int, words: String, cue: String = "") -> void:
	public_lines.append({"tick": tick, "actor": seat, "text": words})
	if public_lines.size() > 9:
		public_lines.pop_front()
	if seat >= 0:
		seats[seat].status = words
		if cue != "" and tick - int(seats[seat].voice_tick) > 90:
			seats[seat].voice = cue
			seats[seat].voice_tick = tick
	emit("ledger", seat, {"text": words, "cue": cue})


func nearest(seat: int) -> int:
	var result := 0
	var best := 1 << 30
	for z in 3:
		var d: int = seats[seat].pos.distance_squared_to(PADS[z])
		if d < best:
			best = d
			result = z
	return result


func near(seat: int, z: int, radius: int = 118) -> bool:
	return z >= 0 and z < 3 and seats[seat].pos.distance_squared_to(PADS[z]) <= radius * radius


func hatch_open(at: int) -> bool:
	return at >= hatch_at and (difficulty == 0 or (at - hatch_at) % 710 < 360)


func arrival_point(c: Dictionary) -> Vector2i:
	return Vector2i(PADS[c.to]) + Vector2i(c.get("drift", Vector2i.ZERO))


func can_intercept(i: int, c: Dictionary) -> bool:
	var radius := 96 if difficulty == 0 else (80 if i == 2 else 65)
	return seats[i].pos.distance_squared_to(arrival_point(c)) <= radius * radius


func visible_approach() -> bool:
	return not flight.is_empty() and (forecast_until > tick or flight.end - tick < 97)


func input_move(seat: int, dir: Vector2i) -> void:
	if seat < 0 or seat > 1 or ending != "":
		return
	var v := Vector2i(clampi(dir.x, -1, 1), clampi(dir.y, -1, 1))
	if seats[seat].vel != v:
		emit("human_move", seat, {"x": v.x, "z": v.y})
	seats[seat].vel = v
	if v != Vector2i.ZERO:
		human_acted = true


func human_action(seat: int, verb: String, target: int = -1, job: String = "cover") -> void:
	if seat < 0 or seat > 1 or ending != "":
		return
	human_acted = true
	emit("human_action", seat, {"verb": verb, "target": target, "job": job})
	var z := nearest(seat)
	if verb == "cover" and visible_approach() and can_intercept(seat, flight):
		z = flight.to
	if (
		verb in ["vote", "cover"]
		and not near(seat, z)
		and not (verb == "cover" and not flight.is_empty() and can_intercept(seat, flight))
	):
		say(seat, "Move into the " + ZONES[z] + " pad to " + verb + ".")
		return
	match verb:
		"vote":
			latch(seat, z, true)
		"cover":
			cover(seat, z)
		"reel":
			handle_reel(seat)
		"power":
			power(seat, z)
		"offer":
			offer_job(seat, target, job, 1 if phase == 0 else 2)
		"agree", "counter", "break":
			respond_pact(seat, verb)


func action_pose(i: int, p: String, duration: int) -> void:
	seats[i].pose = p
	seats[i].pose_until = tick + duration


func latch(i: int, z: int, toggle: bool = false) -> void:
	if not near(i, z):
		return
	var s: Dictionary = seats[i]
	if s.vote == z and not toggle:
		return
	s.vote = -1 if s.vote == z else z
	s.vote_id = emit(
		"latch", i, {"zone": s.vote, "at_x": s.pos.x, "at_z": s.pos.y, "decision": s.decision}
	)
	action_pose(i, "Commit", 36)
	say(i, "Withdrew a vote." if s.vote < 0 else "Latched " + ZONES[z] + ".")
	if s.vote == z:
		physical(i, "vote", z)


func cover(i: int, z: int) -> void:
	if not near(i, z) and (flight.is_empty() or not can_intercept(i, flight)):
		return
	if tick < int(seats[i].ready):
		return
	seats[i].cover = z
	seats[i].cover_until = tick + (225 if i == 2 else 148)
	seats[i].ready = tick + 52
	action_pose(i, "Commit", 65)
	emit("cover", i, {"zone": z, "until": seats[i].cover_until})
	say(i, "Covering " + ZONES[z] + ".", "cover")
	physical(i, "cover", z)


func power(i: int, z: int) -> void:
	if tick < int(seats[i].ready):
		return
	var s: Dictionary = seats[i]
	match i:
		0:
			if (
				not flight.is_empty()
				and not flight.slow
				and (near(i, flight.to, 218) or near(i, flight.from, 218))
			):
				Cargo.slow(flight, tick, 45)
				say(i, "Towline taut. Buying the catcher time.")
			else:
				cover(i, z)
		1:
			if not flight.is_empty() and near(i, flight.to, 185):
				flight.banked = true
				flight.bank_u = flight.u
				s.cover = flight.to
				s.cover_until = flight.end + 30
				say(i, "Kickplate set. Banking into the padded cradle.")
			else:
				cover(i, z)
		2:
			if (
				not near(i, z)
				and (flight.is_empty() or z != flight.to or not can_intercept(i, flight))
			):
				return
			cover(i, z)
			s.cover_until = tick + 300
			say(i, "Net planted. I have this landing.", "cover")
		3:
			forecast_until = tick + 370
			say(i, "Tracing the next landing through the hull.", "echo")
		4:
			s.boost = tick + 90
			say(i, "Taking the express rail.", "rush")
	s.ready = tick + 150
	action_pose(i, "Commit", 72)
	emit("tool", i, {"tool": NAMES[i], "zone": z})


func handle_reel(i: int) -> void:
	if reel == -1 and near(i, 1):
		reel = i
		emit("reel_pickup", i)
		say(i, "I have the herd recording.", "reel")
		action_pose(i, "Commit", 45)
	elif reel == i and near(i, 2):
		reel = 5
		emit("reel_stowed", i)
		say(i, "The herd recording is aboard.", "reel")
		physical(i, "fetch", 2)


func offer_job(buyer: int, target: int, duty: String, z: int) -> void:
	if target < 0 or target > 4 or duty not in ["cover", "vote", "fetch"]:
		return
	if duty == "fetch" and reel != -1:
		return
	var id: int = social.propose(buyer, target, duty, z, tick)
	if id < 0:
		return
	emit("offer", buyer, {"offer": id, "to": target, "duty": duty, "zone": z})
	say(buyer, "%s, one chip for %s." % [NAMES[target], duty], "deal")


func respond_pact(i: int, verb: String) -> void:
	var id: int = social.incoming(i)
	if verb == "agree":
		for k in social.offers:
			var offer: Dictionary = social.offers[k]
			if offer.buyer == i and offer.status == "counter":
				id = k
				break
	if id < 0:
		return
	var o: Dictionary = social.offers[id]
	if verb == "agree" and social.accept(id, i, tick):
		say(i, "Deal. " + NAMES[o.provider] + " takes " + o.duty + ".", "deal")
		emit("pact_accepted", i, {"offer": id, "provider": o.provider, "duty": o.duty})
		if o.provider >= 2:
			seats[o.provider].next = tick + 1
	elif verb == "counter" and social.counter(id, i):
		say(i, "Two chips. I remember our last shift.", "deal")
		emit("counter", i, {"offer": id})
	elif verb == "break":
		close_pact(id, "broken" if o.status == "accepted" else "declined")


func close_pact(id: int, outcome: String) -> void:
	var o: Dictionary = social.close(id, outcome, tick)
	if o.is_empty():
		return
	var original: int = emit(
		"pact_" + outcome,
		o.provider,
		{"offer": id, "buyer": o.buyer, "amount": o.price, "job": o.duty}
	)
	say(
		o.provider,
		(
			(
				"Kept the deal with "
				if outcome == "kept"
				else "Broke the deal with " if outcome == "broken" else "Released the offer from "
			)
			+ NAMES[o.buyer]
			+ "."
		),
		"deal"
	)
	if outcome == "broken":
		for i in range(2, 5):
			if i != o.provider:
				start_response(i, "breach", original, o.provider)


func physical(i: int, verb: String, z: int) -> void:
	var id: int = social.incoming(i)
	if id >= 0:
		var o: Dictionary = social.offers[id]
		if o.status == "accepted" and o.duty == verb and (verb == "fetch" or o.zone == z):
			if verb != "cover":
				close_pact(id, "kept")
	if response_jobs.has(i):
		var j: Dictionary = response_jobs[i]
		if (
			(j.action == "vote" and verb == "vote" and z == j.zone)
			or (j.action == "relay" and verb == "fetch")
		):
			j.executed = tick
			j.in_lane = true


func draw_plan(i: int, verb: String, z: int, reason: String) -> void:
	var s: Dictionary = seats[i]
	if s.plan == verb and s.target == z:
		return
	s.plan = verb
	s.target = z
	s.decision = emit(
		"decision",
		i,
		{
			"action": verb,
			"zone": z,
			"reason": reason,
			"reel": reel,
			"phase": phase,
			"votes": [seats[0].vote, seats[1].vote, seats[2].vote, seats[3].vote, seats[4].vote]
		}
	)
	say(
		i,
		reason,
		"rush" if i == 4 and verb == "vote" else "echo" if i == 3 and verb == "fetch" else ""
	)


func start_response(i: int, trigger: String, source: int, partner: int = -1) -> void:
	if i < 2 or i >= seats.size() or not causes.has(source):
		return
	var cause: Dictionary = causes[source]
	var witnessed: bool = (
		cause.tick == tick
		and cause.phase == phase
		and (
			(trigger == "breach" and cause.kind == "pact_broken" and cause.actor == partner)
			or (trigger == "loose" and cause.kind == "flight" and cause.to == 1)
			or (trigger == "handoff" and cause.kind == "flight" and cause.to == 2)
		)
	)
	if not witnessed:
		return
	var unique := "%d/%d/%s/%d" % [phase, i, trigger, partner]
	if locked_reactions.has(unique) or response_jobs.has(i):
		return
	locked_reactions[unique] = true
	var distrust: bool = partner >= 0 and (social.trust[i][partner] < 0 or trigger == "breach")
	var urgent := tick > hatch_at - 250
	var ctx: String = policy.key(i, phase, distrust, urgent) + ("/storm" if difficulty == 1 else "")
	if not flight.is_empty() and i == flight.assigned:
		ctx += "/assigned"
	var z: int = 1 if phase == 0 else 2
	if not flight.is_empty():
		z = flight.to
	var legal: Array = ["guard", "covenant"]
	if seats[i].vote != z:
		legal.append("vote")
	if reel == -1 or reel == i:
		legal.append("relay")
	var pref: String = ["guard", "relay", "vote"][i - 2]
	if distrust and i == 3:
		pref = "covenant"
	var choice: String = policy.choose(ctx, legal, pref, rngs[i])
	response_jobs[i] = {
		"action": choice,
		"context": ctx,
		"zone": z,
		"src": source,
		"trigger": trigger,
		"in_lane": false,
		"executed": -1,
		"issued": tick,
		"expires": tick + 440,
		"secured": false,
		"partner": partner,
		"eligible": legal.has(choice),
		"witnessed": witnessed
	}
	seats[i].next = tick + 1
	emit(
		"response_intent",
		i,
		{"source": source, "context": ctx, "choice": choice, "legal": legal, "zone": z}
	)


func set_job_plan(i: int, j: Dictionary) -> void:
	match j.action:
		"guard":
			draw_plan(i, "cover", j.zone, "Taking cover at " + ZONES[j.zone] + ".")
		"vote":
			draw_plan(
				i, "vote", j.zone, "Voting " + ZONES[j.zone] + " while the landing is reachable."
			)
		"relay":
			draw_plan(
				i,
				"fetch",
				2 if reel == i else 1,
				"Moving the family recording before the window closes."
			)
		"covenant":
			draw_plan(i, "cover", j.zone, "Requesting paid cover and staying near the landing.")
			if not j.has("solicited"):
				j.solicited = true
				var target := preferred_partner(i, int(j.partner))
				var before: int = social.next_id
				offer_job(i, target, "cover", j.zone)
				if social.next_id > before:
					j.contract = social.next_id


func preferred_partner(i: int, avoid: int = -1) -> int:
	var best := -100
	var who := (i + 1) % 5
	for step in range(1, 5):
		var k := (i + step) % 5
		var v: int = (
			social.trust[i][k] * 6
			+ rngs[i].randi_range(0, 4)
			- (10 if k == avoid else 0)
			- (6 if social.incoming(k) >= 0 else 0)
		)
		if v > best:
			best = v
			who = k
	return who


func plan(i: int) -> void:
	var s: Dictionary = seats[i]
	var rng: RandomNumberGenerator = rngs[i]
	s.next = tick + rng.randi_range(70, 145)
	var id: int = social.incoming(i)
	if id >= 0:
		var o: Dictionary = social.offers[id]
		if o.status == "offered":
			var damage: int = social.trust[i][o.buyer]
			var roll := rng.randf()
			if damage < 0 and roll < .52:
				respond_pact(i, "counter")
			elif roll < .87:
				respond_pact(i, "agree")
			else:
				respond_pact(i, "break")
		if social.offers.has(id) and o.status == "accepted":
			var tempted: bool = (
				(i == 3 and reel == -1 and o.duty != "fetch")
				or (i == 4 and tick > hatch_at and o.duty != "vote")
				or (i == 2 and not flight.is_empty() and o.duty == "fetch")
			)
			if tempted and tick - o.accepted > 90 and rng.randf() < .26:
				respond_pact(i, "break")
			else:
				draw_plan(
					i,
					o.duty,
					(2 if reel == i else 1) if o.duty == "fetch" else o.zone,
					"Keeping my " + o.duty + " pledge to " + NAMES[o.buyer] + "."
				)
				return
	if reel == i:
		draw_plan(i, "fetch", 2, "Carrying the recording to HATCH.")
		return
	if response_jobs.has(i):
		set_job_plan(i, response_jobs[i])
		return
	var z: int = 1 if phase == 0 else 2
	if not flight.is_empty():
		z = flight.to
	if i == 3 and reel == -1 and rng.randf() < .83:
		draw_plan(i, "fetch", 1, "The herd recording is loose. I can reach it.")
	elif s.vote != z and rng.randf() < [.74, .88, .60][i - 2]:
		draw_plan(i, "vote", z, "Need three latches on " + ZONES[z] + ".")
	else:
		draw_plan(i, "cover", z, "Expecting cargo at " + ZONES[z] + ".")


func motor(i: int) -> void:
	var s: Dictionary = seats[i]
	var pos: Vector2i = s.pos
	# A catcher braces until custody closes. The impact position can be a metre outside the pad in a gust.
	if not dwell.is_empty() and dwell.seat == i:
		s.vel = Vector2i.ZERO
		s.motion = Vector2i.ZERO
		return
	var goal: Vector2i = (
		PADS[s.target] + [Vector2i(-32, 20), Vector2i(12, -30), Vector2i(34, 18)][i - 2]
	)
	if s.plan == "cover" and visible_approach() and s.target == flight.to:
		goal = arrival_point(flight)
	var delta := goal - pos
	if i == 4 and delta.length_squared() > 260 * 260 and tick >= int(s.ready):
		power(i, s.target)
	if i == 3 and not flight.is_empty() and tick >= int(s.ready) and forecast_until < tick + 20:
		power(i, s.target)
	var speed: int = 10 if tick < int(s.boost) else 5 if i == 4 else 4
	var movement := Vector2i(clampi(delta.x, -speed, speed), clampi(delta.y, -speed, speed))
	s.vel = movement
	s.motion = movement
	s.pos = pos + movement
	if response_jobs.has(i) and near(i, response_jobs[i].zone):
		response_jobs[i].in_lane = true
	if (
		not near(i, s.target, 72)
		and not (s.plan == "cover" and not flight.is_empty() and can_intercept(i, flight))
	):
		return
	match s.plan:
		"vote":
			latch(i, s.target)
		"cover":
			if int(s.cover_until) < tick + 35:
				if i == 2 and not flight.is_empty():
					power(i, s.target)
				else:
					cover(i, s.target)
		"fetch":
			handle_reel(i)


func start_leg(z: int) -> void:
	cargo_leg += 1
	var catcher := 2
	for o in social.offers.values():
		if o.status == "accepted" and o.duty == "cover" and o.zone == z:
			catcher = o.provider
			break
	flight = {
		"id": cargo_leg,
		"from": egg_zone,
		"to": z,
		"start": tick,
		"end": tick + (235 if z == 1 else 270),
		"anchor_u": 0,
		"anchor_tick": tick,
		"u": 0,
		"bank_u": 0,
		"pos": Cargo.RAILS[egg_zone],
		"velocity": Vector3i.ZERO,
		"slow": false,
		"banked": false,
		"assigned": catcher,
		"marks": [false, false, false, false, false, false]
	}
	if difficulty == 1:
		var side := 1 if posmod(seed_value * 7 + cargo_leg, 2) == 0 else -1
		flight.drift = Vector2i(
			side * (90 + posmod(seed_value * 19 + cargo_leg * 29, 52)), 35 + posmod(seed_value, 21)
		)
	var event := emit(
		"flight", catcher, {"leg": cargo_leg, "from": egg_zone, "to": z, "due": flight.end}
	)
	for i in range(2, 5):
		start_response(i, "loose" if z == 1 else "handoff", event)


func award(c: Dictionary, k: int) -> void:
	if c.marks[k]:
		return
	c.marks[k] = true
	emit("milestone", c.assigned, {"leg": c.id, "check": k, "points": CATCH_WEIGHTS[k]})


func seal_catch(c: Dictionary) -> void:
	var points := 0
	for k in CATCH_WEIGHTS.size():
		if c.marks[k]:
			points += int(CATCH_WEIGHTS[k])
	var data := {
		"type": "catch",
		"id": c.id,
		"points": points,
		"pass": points == 100,
		"flags": c.marks.duplicate(),
		"tick": tick,
		"actor": c.assigned
	}
	grades.append(data)
	emit("action_grade", c.assigned, data)
	last_catch = data


func impact() -> void:
	var c := flight
	var z: int = c.to
	var original: int = c.assigned
	var catcher := -1
	for n in [original, 0, 1, 2, 3, 4]:
		var i: int = n
		if can_intercept(i, c) and seats[i].cover == z and seats[i].cover_until >= tick:
			var v: Vector2i = seats[i].motion
			if i == original:
				award(c, 2)
			var velocity: Vector3i = c.velocity
			var relative := Vector3i(v.x - velocity.x, -velocity.y, v.y - velocity.z)
			if relative.length_squared() <= 68 or c.banked:
				catcher = i
				if i == original:
					award(c, 3)
				break
	flight = {}
	if catcher < 0:
		seal_catch(c)
		bounce(z)
		return
	dwell = {"until": tick + 18, "seat": catcher, "cargo": c}
	emit("contact", catcher, {"leg": c.id, "zone": z})


func bounce(z: int) -> void:
	hull -= 1
	egg_zone = 1 if phase > 0 else 0
	retry_at = tick + 270
	say(
		-1,
		(
			"Padded tray took the impact. Shell integrity "
			+ str(hull)
			+ ("/2." if difficulty == 1 else "/3.")
		)
	)
	emit("impact", -1, {"zone": z, "hull": hull})
	if hull <= 0:
		finish("Shell lost")


func settle() -> void:
	var c: Dictionary = dwell.cargo
	var i: int = dwell.seat
	if not can_intercept(i, c) or seats[i].cover != c.to or seats[i].cover_until < tick:
		dwell = {}
		seal_catch(c)
		bounce(c.to)
		return
	if i == c.assigned and tick >= int(dwell.until) - 12:
		award(c, 4)
	if tick < int(dwell.until):
		return
	dwell = {}
	egg_zone = c.to
	if i == c.assigned:
		award(c, 5)
	seal_catch(c)
	var id: int = social.incoming(i)
	if (
		id >= 0
		and social.offers[id].status == "accepted"
		and social.offers[id].duty == "cover"
		and social.offers[id].zone == c.to
	):
		close_pact(id, "kept")
	if response_jobs.has(i) and response_jobs[i].action == "guard":
		response_jobs[i].executed = tick - 18
		response_jobs[i].secured = true
	say(i, "Secure. The cradle is holding.", "cover")
	action_pose(i, "Relief", 100)
	if c.to == 2:
		finish("The herd answers" if reel == 5 else "The calf answers")


func update_gravity() -> void:
	var counts := [0, 0, 0]
	for s in seats:
		if s.vote >= 0:
			counts[s.vote] += 1
	var axis := -1
	for z in 3:
		if counts[z] >= 3:
			axis = z
			break
	if axis < 0 or axis == gravity:
		quorum_axis = -1
	elif axis != quorum_axis:
		quorum_axis = axis
		quorum_start = tick
	elif tick - quorum_start >= 30:
		gravity = axis
		quorum_axis = -1
		var voters: Array = []
		var causes: Array = []
		for i in 5:
			if seats[i].vote == axis:
				voters.append(i)
				causes.append(seats[i].vote_id)
		var release := phase == 0 and axis == 1
		if release:
			phase = 1
			reel = -1
		var payload := {
			"axis": axis,
			"voters": voters,
			"causes": causes,
			"released_reel": release,
			"hands_off": not human_acted and voters == [2, 3, 4]
		}
		causal_flips.append(payload)
		emit("gravity", -1, payload)
		say(
			-1,
			(
				"Gravity now pulls toward "
				+ ZONES[axis]
				+ (". The herd reel is free." if release else ".")
			)
		)
		if release:
			start_leg(1)
	if (
		phase == 1
		and egg_zone == 1
		and gravity == 2
		and hatch_open(tick)
		and tick >= retry_at
		and flight.is_empty()
		and dwell.is_empty()
	):
		start_leg(2)


func grade_responses(closing: bool = false) -> void:
	for raw in response_jobs.keys():
		var i: int = raw
		var j: Dictionary = response_jobs[i]
		if j.action == "covenant" and j.has("contract"):
			for m in social.memories:
				if m.get("offer", -1) == j.contract and m.who == i and m.outcome == "kept":
					j.executed = m.tick
					j.secured = true
		if j.action == "vote" and j.executed >= 0 and gravity == j.zone:
			j.secured = true
		if j.action == "relay" and j.executed >= 0 and reel == 5:
			j.secured = true
		var flags := [j.witnessed, j.eligible, j.in_lane, j.executed >= 0, j.secured]
		var emitted: int = j.get("mask", 0)
		for k in flags.size():
			if flags[k] and (emitted & (1 << k)) == 0:
				emit(
					"response_milestone",
					i,
					{"source": j.src, "action": j.action, "check": k, "points": RESPONSE_WEIGHTS[k]}
				)
				emitted |= (1 << k)
		j.mask = emitted
		if not closing and tick < j.expires and not j.secured:
			continue
		var pts := 0
		for k in flags.size():
			if flags[k]:
				pts += int(RESPONSE_WEIGHTS[k])
		var data := {
			"type": "response",
			"id": j.src,
			"context": j.context,
			"action": j.action,
			"points": pts,
			"pass": pts == 100,
			"flags": flags,
			"trigger": j.trigger,
			"actor": i,
			"tick": tick
		}
		grades.append(data)
		emit("action_grade", i, data)
		policy.observe(j.context, j.action, pts)
		response_jobs.erase(i)
		seats[i].next = tick + 1


func finish(label: String) -> void:
	if ending != "":
		return
	ending = label
	grade_responses(true)
	for id in social.offers.keys():
		close_pact(id, "expired")
	emit("end", -1, {"ending": label, "hull": hull, "reel": reel})
	say(-1, label + ".")


func step(autonomy: bool = true) -> void:
	if ending != "":
		return
	tick += 1
	for i in 2:
		var s: Dictionary = seats[i]
		var dir: Vector2i = s.vel
		var old: Vector2i = s.pos
		s.pos = Vector2i(
			clampi(s.pos.x + dir.x * (4 if dir.y != 0 else 6), -550, 550),
			clampi(s.pos.y + dir.y * (4 if dir.x != 0 else 6), -233, 230)
		)
		s.motion = s.pos - old
	# Commit intentions from a common physical snapshot; move all motors before cargo contact.
	if autonomy:
		for i in range(2, 5):
			if tick >= int(seats[i].next):
				plan(i)
		for i in range(2, 5):
			motor(i)
	for id in social.offers.keys():
		var o: Dictionary = social.offers[id]
		if o.status == "counter" and o.buyer >= 2 and tick % 83 == 0:
			respond_pact(o.buyer, "agree")
		if not social.offers.has(id):
			continue
		if (
			o.status == "accepted"
			and o.duty == "cover"
			and not flight.is_empty()
			and flight.to == o.zone
		):
			o["had_window"] = true
		if o.status == "accepted" and o.duty == "fetch" and reel != -1 and reel != o.provider:
			close_pact(id, "excused")
		elif tick >= int(o.deadline):
			var accountable: bool = (
				o.status == "accepted" and (o.duty != "cover" or o.get("had_window", false))
			)
			close_pact(id, "broken" if accountable else "expired")
	if autonomy and tick >= next_trade:
		var i := 2 + posmod(int(next_trade / 245), 3)
		var duty := "fetch" if i == 3 and reel == -1 else "vote" if i == 4 else "cover"
		offer_job(i, preferred_partner(i), duty, 1 if phase == 0 else 2)
		next_trade += 245
	update_gravity()
	if not flight.is_empty():
		Cargo.advance(flight, tick)
		var i: int = flight.assigned
		if seats[i].cover == flight.to and seats[i].cover_until >= tick:
			award(flight, 0)
		if can_intercept(i, flight) and flight.marks[0]:
			award(flight, 1)
		if flight.u >= Cargo.ONE:
			if flight.to == 2 and not hatch_open(tick):
				seal_catch(flight)
				flight = {}
				bounce(2)
				say(-1, "The hatch slid past. Listen for the next window.")
			else:
				impact()
	if not dwell.is_empty():
		settle()
	grade_responses()
	if tick % 15 == 0:
		var positions: Array = []
		for s in seats:
			positions.append([s.pos.x, s.pos.y])
		var xyz: Vector3i = flight.get("pos", Cargo.RAILS[egg_zone])
		emit(
			"snapshot",
			-1,
			{
				"positions": positions,
				"cargo": [xyz.x, xyz.y, xyz.z],
				"gravity": gravity,
				"hull": hull,
				"reel": reel
			}
		)
	if tick >= deadline:
		finish("The mother passes")


func legacy_digest() -> String:
	var state := [
		tick,
		difficulty,
		phase,
		gravity,
		hull,
		reel,
		egg_zone,
		ending,
		social.balance,
		social.trust,
		causal_flips,
		grades,
		flight,
		dwell
	]
	for s in seats:
		state.append([s.pos.x, s.pos.y, s.vote, s.plan])
	return JSON.stringify(state).sha256_text()


func digest() -> String:
	var generators: Array = []
	for rng in rngs:
		generators.append(str(rng.state))
	var preferences: Dictionary = {}
	for key in policy.estimates:
		var row: Array = policy.estimates[key]
		preferences[key] = [int(row[0]), int(row[1]), int(row[2])]
	var complete := [
		RULESET,
		legacy_digest(),
		seq,
		hatch_at,
		deadline,
		seats,
		cargo_leg,
		forecast_until,
		next_trade,
		retry_at,
		quorum_axis,
		quorum_start,
		human_acted,
		locked_reactions,
		response_jobs,
		social.next_id,
		social.offers,
		social.memories,
		generators,
		preferences,
		policy.adaptive,
		policy.exploration
	]
	return JSON.stringify(complete).sha256_text()
