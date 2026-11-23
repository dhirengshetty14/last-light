extends Node
## Each robot owns an independent one-request channel. The simulator consumes replies only at tick boundaries.
const MODEL = "gemini-3.1-flash-lite"
const ROLES := ["Pip", "Morrow", "Zip"]
const OPTIONS := {
	"defend": ["press", "screen", "cut"],
	"support": ["advance", "outlet"],
	"carry": ["drive", "flank", "pass", "finish", "evade"],
	"loose": ["lead", "recover"]
}
const INTERVAL_MS := 8000
## Each robot gets one playbook at kickoff. After that it only asks when it is struggling (see
## `wants_advice` in star_agent.gd), and never more often than every eight seconds. Before, every
## robot asked every eight seconds whatever was happening: about 22 calls a minute.
var thrifty := true
var endpoint := ""
var channels: Array[HTTPRequest] = []
var models: Array[String] = []
var active := [{}, {}, {}]
var next_ms := [0, 0, 0]
var serial := [0, 0, 0]
var completed: Array = []
var disabled := [false, false, false]


func configure(url: String) -> void:
	endpoint = url
	for i in 3:
		models.append(MODEL)
		var http := HTTPRequest.new()
		# HTTPRequest polls nonblocking sockets. A pending radio call can be cancelled at the whistle immediately.
		http.use_threads = false
		http.timeout = 6.
		http.max_redirects = 0
		http.body_size_limit = 65536
		add_child(http)
		channels.append(http)
		http.request_completed.connect(_reply.bind(i))
		next_ms[i] = Time.get_ticks_msec() + i * 550


static func observation(sim, i: int) -> Dictionary:
	var actor = sim.agents[i]
	var who: int = actor.role
	var seen_players := []
	for j in 5:
		if j == who or not actor.can_see(sim.pos[who].distance_to(sim.pos[j])):
			continue
		seen_players.append(
			{
				"name": sim.NAMES[j],
				"team": sim.team[j],
				"position": [snappedf(sim.pos[j].x, .1), snappedf(sim.pos[j].y, .1)]
			}
		)
	return {
		"name": ROLES[i],
		"goal": actor.GOALS[i],
		"team": sim.team[who],
		"blue_goals": sim.goals[1],
		"gold_goals": sim.goals[0],
		"star_holder": sim.NAMES[sim.owner] if sim.owner >= 0 else "loose",
		"position": [sim.pos[who].x, sim.pos[who].y],
		"nearby": seen_players,
		"pilots": ["Nell", "Rafi"],
		"scouting_shots_passes_lane": actor.scouting.duplicate(true),
		"relationships": actor.social_snapshot(),
		"last_move": sim.tactics[who],
		"last_public_reason": actor.last_plan.left(120),
		"learned_tactic": actor.local_preference,
		"last_four_plays": actor.recent_plays.duplicate(true),
		"robbed_by": [actor.times_robbed(0), actor.times_robbed(1)]
	}


static func validate_plan(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != OPTIONS.size():
		return {}
	var clean := {}
	for phase in OPTIONS:
		var entry: Variant = value.get(phase)
		if (
			not entry is Dictionary
			or entry.get("move") not in OPTIONS[phase]
			or not entry.get("reason") is String
		):
			return {}
		var reason: String = (
			entry.reason.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
		)
		if reason.is_empty() or reason.length() > 160:
			return {}
		clean[phase] = {"move": entry.move, "reason": reason}
	return clean


static func decode(body: PackedByteArray) -> Dictionary:
	var response: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not response is Dictionary:
		return {}
	var plan := validate_plan(response.get("plan"))
	if plan.is_empty():
		return {}
	return {
		"plan": plan,
		"model_version": str(response.get("model_version", "")).left(100),
		"input_tokens": int(response.get("input_tokens", 0)),
		"output_tokens": int(response.get("output_tokens", 0)),
		"total_tokens": int(response.get("total_tokens", 0))
	}


func poll(sim) -> Array:
	var batch := completed
	completed = []
	var now := Time.get_ticks_msec()
	for i in 3:
		if disabled[i] or not active[i].is_empty() or now < int(next_ms[i]):
			continue
		var actor = sim.agents[i]
		if thrifty and serial[i] > 0 and not actor.wants_advice():
			continue
		actor.asked_for_advice()
		serial[i] += 1
		var seen := observation(sim, i)
		var ticket := {
			"actor": i + 2,
			"id": int(serial[i]),
			"model": models[i],
			"team_epoch": actor.team_epoch,
			"asked_tick": sim.tick
		}
		var sent := ticket.duplicate()
		sent.merge({"state": "request", "observation": seen})
		batch.append(sent)
		active[i] = ticket
		next_ms[i] = now + INTERVAL_MS
		active[i]["start_ms"] = now
		var err := dispatch(i, seen)
		if err != OK:
			_finish(i, "transport_error", 0, {})
	return batch


func dispatch(i: int, body: Dictionary) -> Error:
	return channels[i].request(
		endpoint,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)


func _reply(
	result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, i: int
) -> void:
	if active[i].is_empty():
		return
	var state := "ready"
	var checked := {}
	if result != HTTPRequest.RESULT_SUCCESS:
		state = "timeout" if result == HTTPRequest.RESULT_TIMEOUT else "transport_error"
	elif status != 200:
		state = "http_error"
	else:
		checked = decode(body)
		if checked.is_empty():
			state = "invalid_reply"
	if status in [400, 401, 403, 404]:
		disabled[i] = true
	if state == "transport_error" or state == "timeout":
		next_ms[i] = Time.get_ticks_msec() + 15000
	if status == 429:
		next_ms[i] = Time.get_ticks_msec() + 30000
	_finish(i, state, status, checked)


func _finish(i: int, state: String, status: int, fields: Dictionary) -> void:
	var reply: Dictionary = active[i]
	active[i] = {}
	reply["latency_ms"] = Time.get_ticks_msec() - int(reply.start_ms)
	reply.erase("start_ms")
	reply.merge({"state": state, "http_status": status})
	reply.merge(fields)
	completed.append(reply)


func close() -> Array:
	endpoint = ""
	for i in channels.size():
		if not active[i].is_empty():
			channels[i].cancel_request()
			_finish(i, "cancelled", 0, {})
	var batch := completed
	completed = []
	return batch
