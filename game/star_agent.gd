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
var plan_basis := ""
var prior_attempts := 0


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
	observe(context, choice, points)


func social_snapshot() -> Dictionary:
	return {"reputation": reputation.duplicate(), "last_deal": last_deal.duplicate()}


func restore_social(data: Dictionary) -> void:
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
