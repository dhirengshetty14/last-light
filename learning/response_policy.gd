extends RefCounted
## Only the learner sees outcomes. The player reads a state-indexed action preference.

const CHOICES := ["guard", "covenant", "relay", "vote"]
var estimates: Dictionary = {}
var adaptive := true
var exploration := 0.08


func key(role: int, phase: int, distrust: bool, urgent: bool) -> String:
	return "%d/%d/%d/%d" % [role, phase, int(distrust), int(urgent)]


func choose(context: String, legal: Array, preferred: String, rng: RandomNumberGenerator) -> String:
	if legal.is_empty():
		return "guard"
	if rng.randf() < exploration:
		return str(legal[rng.randi_range(0, legal.size() - 1)])
	var best := -1000.0
	var result := str(legal[0])
	for candidate in legal:
		var row: Array = estimates.get(context + "/" + candidate, [0, 0, 0])
		var prior := 0.58 if candidate == preferred else 0.42
		var p := (float(row[1]) + 2.0 * prior) / (float(row[0]) + 2.0)
		var quality := float(row[2]) / (100.0 * maxf(1.0, float(row[0])))
		# Quantized pass estimates permit quality to break ties without overriding a higher bucket.
		var rank := roundf(p * 100.0) + quality * 0.48 + rng.randf() * 0.02
		if rank > best:
			best = rank
			result = str(candidate)
	return result


func observe(context: String, action: String, points: int) -> void:
	if not adaptive:
		return
	var id := context + "/" + action
	var row: Array = estimates.get(id, [0, 0, 0])
	estimates[id] = [int(row[0]) + 1, int(row[1]) + int(points == 100), int(row[2]) + points]


func load_checkpoint(path: String) -> void:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("schema") == "response-policy-v1":
			estimates = data.get("estimates", {}).duplicate(true)


func add_local_examples(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary or saved.get("schema") != "verified-local-responses-v1":
		return
	var observations: Variant = saved.get("estimates")
	if not observations is Dictionary:
		return
	for id in observations:
		var value: Variant = observations[id]
		if not value is Array or value.size() != 3:
			continue
		var total := int(value[0])
		var successes := int(value[1])
		var points := int(value[2])
		if (
			total < 0
			or successes < 0
			or successes > total
			or points < 100 * successes
			or points > 100 * total
		):
			continue
		var prior: Array = estimates.get(id, [0, 0, 0])
		estimates[id] = [int(prior[0]) + total, int(prior[1]) + successes, int(prior[2]) + points]
