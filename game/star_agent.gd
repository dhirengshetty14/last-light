extends "res://learning/star_policy.gd"
## One robot's policy parameters, current observations, and relationships with the two pilots.
const SCOUT_RANGE := [3.2, 5.1, 4.0]
const GOALS := ["Win the ball back", "Protect our ring", "Get ahead of the carrier"]
var role: int
var draw := RandomNumberGenerator.new()
var scouting := [[0, 0, 0.0], [0, 0, 0.0]]
var reputation := [0, 0]
var last_deal := ["", ""]
var last_plan := ""
var decisions_graded := 0
var team_epoch := 0
var requested_plan := 0
var answered_plan := 0
var recent_plays: Array = []
var model_plan: Dictionary = {}
var model_status := "Local policy"
var local_preference := ""
const MAX_PLAN_TICKS := 720
## Promises each captain has kept and broken with this robot, carried from match to match.
var ledger := [[0, 0], [0, 0]]
## How often a social choice is made at random. Practice matches raise it. Live play keeps it at
## zero: nobody wants a robot that walks out on a coin flip.
var social_exploration := 0.0
const SOCIAL_TRIES := 8


func change_team() -> void:
	team_epoch += 1
	model_plan = {}


func accept_packet(packet: Dictionary, tick: int) -> String:
	if packet.actor != role:
		return "wrong_robot"
	if packet.state == "request":
		if int(packet.id) <= requested_plan:
			return "superseded"
		requested_plan = int(packet.id)
		model_status = "Waiting for " + str(packet.model)
		return "requested"
	if int(packet.id) != requested_plan or answered_plan >= requested_plan:
		return "superseded"
	answered_plan = requested_plan
	if packet.state != "ready":
		model_status = (
			"%s · %s"
			% [
				packet.model,
				packet.state if packet.state != "http_error" else "HTTP " + str(packet.http_status)
			]
		)
		return packet.state
	if int(packet.team_epoch) != team_epoch or tick - int(packet.asked_tick) > MAX_PLAN_TICKS:
		model_status = "Situation changed"
		return "stale"
	model_plan = packet
	model_status = packet.model
	return "available"


func advice(phase: String, context: String, legal: Array, tick: int) -> Dictionary:
	if model_plan.is_empty():
		return {}
	if tick - int(model_plan.asked_tick) > MAX_PLAN_TICKS:
		model_plan = {}
		model_status = "Plan expired"
		return {}
	var entry: Dictionary = model_plan.plan[phase]
	var move: String = entry.move
	var live: Array = recent.get(context + "/" + move, [0., 0.])
	var outcome := "applied"
	if move not in legal:
		outcome = "illegal_here"
	elif (
		move != local_preference
		and float(live[0]) >= 1.55
		and float(live[1]) / float(live[0]) < .40
	):
		outcome = "learner_override"
	return {
		"model": model_plan.model,
		"request_id": model_plan.id,
		"proposal": move,
		"rationale": entry.reason,
		"disposition": outcome
	}


## Court version 12. The proposal in the current Gemini playbook for this phase, or "" when there is
## no fresh playbook. The robot weighs it with its own record instead of simply obeying it.
func proposal(phase: String, tick: int) -> String:
	if model_plan.is_empty():
		return ""
	if tick - int(model_plan.asked_tick) > MAX_PLAN_TICKS:
		model_plan = {}
		model_status = "Plan expired"
		return ""
	return str(model_plan.plan[phase].move)


## Court version 12. What became of the playbook's proposal once the robot had weighed it: used,
## outweighed by the robot's own record (and chance), or not a legal move here.
func weighed_advice(phase: String, legal: Array, choice: String) -> Dictionary:
	if model_plan.is_empty():
		return {}
	var entry: Dictionary = model_plan.plan[phase]
	var move: String = entry.move
	return {
		"model": model_plan.model,
		"request_id": model_plan.id,
		"proposal": move,
		"rationale": entry.reason,
		"disposition":
		"illegal_here" if move not in legal else ("applied" if move == choice else "learner_override")
	}


var plan_basis := ""
var prior_attempts := 0
## Court version 12. Steals each player has made from this robot this match, and the count it
## carried in from earlier matches (halved at each final whistle, so old lessons fade).
var robbed := [0, 0, 0, 0, 0]
var robbed_before := [0., 0., 0., 0., 0.]
## The move this robot was making when it was last robbed, by situation, and who robbed it.
var burned: Dictionary = {}
var burned_by: Dictionary = {}
## Situations in which this robot has already said what it learned, this match.
var lessons_told: Dictionary = {}


## Notes from Coach Bruin: the Bruin Cloud agent that reads the robots' failure tables between
## matches. For a phase (defend, loose, support, carry): the move to try, the move it fails with,
## and the advice in words. Given at kickoff and recorded in the match header, so replays hold.
var bruin_coach: Dictionary = {}


## Court version 14: what crewmates have told this robot this match. Warnings about a player who
## keeps robbing them (a count per player), tips for a situation (the move a crewmate dropped there
## and the one it uses now, and who said so), and the tips this robot has already said it used.
var heard_warnings := [0, 0, 0, 0, 0]
var tips: Dictionary = {}
var tips_used: Dictionary = {}


## Extra room this robot gives a player who has robbed it: 0.3 m a steal, plus 0.15 m for each
## warning a crewmate has given about that player, at most 1.2 m. A robot that is not learning (a
## frozen comparison) gives none.
func wariness(j: int) -> float:
	if not adaptive:
		return 0.
	return minf(
		1.2,
		.3 * (float(robbed[j]) + float(robbed_before[j])) + .15 * float(heard_warnings[j])
	)


func times_robbed(j: int) -> int:
	return int(robbed[j]) + roundi(float(robbed_before[j]))


func note_robbed(j: int, context: String, move: String) -> int:
	robbed[j] += 1
	if context != "":
		burned[context] = move
		burned_by[context] = j
	robbed_since_ask += 1
	return int(robbed[j])


func _init(actor: int) -> void:
	role = actor
	if role == 2:
		reputation = [1, 1]


func can_see(distance: float) -> bool:
	return distance <= SCOUT_RANGE[role - 2]


func see_throw(pilot: int, passing: bool, lane: float) -> void:
	scouting[pilot][int(passing)] += 1
	see_lane(pilot, lane, .47)


func see_lane(pilot: int, lane: float, weight: float) -> void:
	scouting[pilot][2] = lerpf(float(scouting[pilot][2]), lane, weight)


func remember(pilot: int, change: int, note: String) -> void:
	reputation[pilot] = clampi(int(reputation[pilot]) + change, -2, 3)
	last_deal[pilot] = note


func record_grade(context: String, choice: String, points: int) -> void:
	if adaptive:
		decisions_graded += 1
	recent_grades.push_back(points)
	if recent_grades.size() > 10:
		recent_grades.pop_front()
	observe(context, choice, points)


## The grades of this robot's last ten decisions, and how often it has been robbed since it last
## asked for a playbook. The Gemini coach reads these so a robot only spends a model call when it
## is struggling. Nothing in the simulation reads them.
var recent_grades: Array = []
var robbed_since_ask := 0


## True when this robot should ask for a new playbook: it has been robbed twice since it last
## asked, or none of its last ten decisions passed every check. A robot that is doing fine makes
## no call.
func wants_advice() -> bool:
	if robbed_since_ask >= 2:
		return true
	return recent_grades.size() >= 10 and 100 not in recent_grades


func asked_for_advice() -> void:
	robbed_since_ask = 0
	recent_grades.clear()


func social_snapshot() -> Dictionary:
	return {"reputation": reputation.duplicate(), "last_deal": last_deal.duplicate()}


## Everything this robot carries into its next match. Taken at kickoff it is exactly what the robot
## started with, so a recording's header restores the same robot. Taken after the final whistle
## (`faded`), the steals of the match just played count in full and what it carried in from earlier
## matches counts half: a pilot who stops robbing is forgiven in time.
func memory(faded := false) -> Dictionary:
	var out := social_snapshot()
	out["ledger"] = ledger.duplicate(true)
	var carried := []
	for j in 5:
		var count: float = float(robbed_before[j]) * (.5 if faded else 1.) + float(robbed[j])
		carried.append(snappedf(minf(20., count), .01))
	out["robbed"] = carried
	return out


## Pick one of this robot's legal social choices. `usual` is the written rule. The robot leaves it
## only when its own record in the same situation says, beyond luck, that another choice has done
## better. With little or mixed evidence it keeps the rule, so learning cannot make it worse by chance.
func choose_social(
	context: String, legal: Array, usual: String, rng: RandomNumberGenerator
) -> String:
	explored = rng.randf() < social_exploration
	if explored:
		return str(legal[rng.randi_range(0, legal.size() - 1)])
	var habit: Array = estimates.get(context + "/" + usual, [0, 0, 0])
	if int(habit[0]) < SOCIAL_TRIES:
		return usual
	var pick := usual
	var best := float(habit[2]) / float(habit[0])
	var floor_value := best
	for move in legal:
		var row: Array = estimates.get(context + "/" + str(move), [0, 0, 0])
		if str(move) == usual or int(row[0]) < SOCIAL_TRIES:
			continue
		var value := float(row[2]) / float(row[0])
		# Grades run from 0 to 100, so 50 bounds their spread.
		var doubt := 50. * sqrt(1. / float(row[0]) + 1. / float(habit[0]))
		if value - floor_value > doubt and value > best:
			best = value
			pick = str(move)
	return pick


func restore_social(data: Dictionary) -> void:
	var thefts: Variant = data.get("robbed")
	if thefts is Array and thefts.size() == 5:
		var clean := true
		for n in thefts:
			clean = clean and (n is int or n is float) and is_finite(n)
		if clean:
			for j in 5:
				robbed_before[j] = clampf(float(thefts[j]), 0., 20.)
	var scores: Variant = data.get("reputation")
	var notes: Variant = data.get("last_deal")
	if not scores is Array or scores.size() != 2 or not notes is Array or notes.size() != 2:
		return
	for i in 2:
		if not (scores[i] is int or scores[i] is float) or not notes[i] is String:
			return
	for i in 2:
		reputation[i] = clampi(int(scores[i]), -2, 3)
		last_deal[i] = str(notes[i]).left(120)
	var book: Variant = data.get("ledger")
	if not book is Array or book.size() != 2:
		return
	for i in 2:
		var row: Variant = book[i]
		if not row is Array or row.size() != 2:
			return
		for n in row:
			if not (n is int or n is float) or not is_finite(n):
				return
	for i in 2:
		ledger[i] = [clampi(int(book[i][0]), 0, 99), clampi(int(book[i][1]), 0, 99)]
