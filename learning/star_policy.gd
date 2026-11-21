extends "res://learning/response_policy.gd"
## Historical evidence supplies a bounded prior. A robot can change its preference
## within a match even after thousands of previously verified encounters.
var recent: Dictionary = {}


func choose(context: String, legal: Array, preferred: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() < exploration:
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
