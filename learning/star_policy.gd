extends "res://learning/response_policy.gd"
## Historical evidence supplies a bounded prior. A robot can change its preference
## within a match even after thousands of previously verified encounters.
var recent: Dictionary = {}
var explored := false


func choose(context: String, legal: Array, preferred: String, rng: RandomNumberGenerator) -> String:
	explored = rng.randf() < exploration
	if explored:
		return str(legal[rng.randi_range(0, legal.size() - 1)])
	# Untried moves inherit the local difficulty of this situation. Otherwise a
	# never-attempted move can outrank every tested move in a difficult state.
	var total := 0.
	var quality_sum := 0.
	for move in legal:
		var row: Array = estimates.get(context + "/" + str(move), [0, 0, 0])
		total += float(row[0])
		quality_sum += .75 * float(row[1]) + .0025 * float(row[2])
	var common: float = (quality_sum + 1.) / (total + 2.)
	var best := -INF
	var pick := str(legal[0])
	for move in legal:
		var key := context + "/" + str(move)
		var past: Array = estimates.get(key, [0, 0, 0])
		var count := float(past[0])
		var weight := minf(6., sqrt(count))
		var quality: float = (.75 * float(past[1]) + .0025 * float(past[2])) / maxf(1., count)
		var live: Array = recent.get(key, [0., 0.])
		var value: float = (
			(3. * common + weight * quality + float(live[1])) / (3. + weight + float(live[0]))
		)
		if move == preferred:
			value += .075
		if value > best:
			best = value
			pick = move
	return pick


## Court version 12. How much chance decides between moves, and how far a proposal from someone
## else (a Gemini playbook) lifts its move. A move that has done 0.1 worse than the best is picked
## about a tenth as often, so a habit that keeps failing fades fast but nothing is fully predictable.
const WARMTH := .042
const NUDGE := .06
## Each move's value at the last sampled choice, before chance, so a caller can see why it was made.
var last_values: Dictionary = {}


## Court version 12. Weighs every legal move exactly as `choose` does, then samples one in
## proportion to how well it has done instead of always taking the top one (the Gumbel-max trick,
## drawn from this robot's own seeded generator, so a replay makes the same draws). `nudge` is a
## move someone else proposed; it gets a small lift, never a guarantee. `lifts` adds or takes a
## little from named moves, for what crewmates have said.
func choose_sampled(
	context: String,
	legal: Array,
	preferred: String,
	rng: RandomNumberGenerator,
	nudge := "",
	lifts: Dictionary = {}
) -> String:
	last_values = {}
	explored = rng.randf() < exploration
	if explored:
		return str(legal[rng.randi_range(0, legal.size() - 1)])
	var total := 0.
	var quality_sum := 0.
	for move in legal:
		var row: Array = estimates.get(context + "/" + str(move), [0, 0, 0])
		total += float(row[0])
		quality_sum += .75 * float(row[1]) + .0025 * float(row[2])
	var common: float = (quality_sum + 1.) / (total + 2.)
	var best := -INF
	var pick := str(legal[0])
	for move in legal:
		var key := context + "/" + str(move)
		var past: Array = estimates.get(key, [0, 0, 0])
		var count := float(past[0])
		var weight := minf(6., sqrt(count))
		var quality: float = (.75 * float(past[1]) + .0025 * float(past[2])) / maxf(1., count)
		var live: Array = recent.get(key, [0., 0.])
		var value: float = (
			(3. * common + weight * quality + float(live[1])) / (3. + weight + float(live[0]))
		)
		if move == preferred:
			value += .075
		if move == nudge:
			value += NUDGE
		# What a crewmate said about this situation: a small lift or a small weight, never an order.
		value += float(lifts.get(move, 0.))
		last_values[str(move)] = value
		var noisy: float = value - WARMTH * log(-log(clampf(rng.randf(), 1e-6, 1. - 1e-6)))
		if noisy > best:
			best = noisy
			pick = str(move)
	return pick


## Version-two recordings replay their original action ordering and priors.
func choose_v2(
	context: String, legal: Array, preferred: String, rng: RandomNumberGenerator
) -> String:
	explored = rng.randf() < exploration
	if explored:
		return str(legal[rng.randi_range(0, legal.size() - 1)])
	var best := -INF
	var result := str(legal[0])
	for move in legal:
		var id: String = context + "/" + str(move)
		var historic: Array = estimates.get(id, [0, 0, 0])
		var count := float(historic[0])
		var prior := .60 if move == preferred else .40
		var weight := minf(6., sqrt(count))
		var quality := (float(historic[1]) * .75 + float(historic[2]) * .0025) / maxf(1., count)
		var live: Array = recent.get(id, [0., 0.])
		var value := (
			(2.5 * prior + weight * quality + float(live[1])) / (2.5 + weight + float(live[0]))
		)
		if value > best:
			best = value
			result = move
	return result


func observe(context: String, action: String, points: int) -> void:
	if not adaptive:
		return
	super.observe(context, action, points)
	var id := context + "/" + action
	var live: Array = recent.get(id, [0., 0.])
	recent[id] = [
		float(live[0]) * .73 + 1.,
		float(live[1]) * .73 + .75 * int(points == 100) + .25 * points / 100.
	]
