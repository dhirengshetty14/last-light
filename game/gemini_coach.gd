extends Node
## Each robot owns an independent one-request channel. The simulator consumes replies only at tick boundaries.
const ENDPOINT := "https://generativelanguage.googleapis.com/v1beta/models/"
const MODELS := ["gemini-3.1-flash-lite", "gemini-3.6-flash", "gemini-3.5-flash-lite"]
const ROLES := ["Pip", "Morrow", "Zip"]
const PERSONAS := [
	"You are Pip, an opportunistic ball thief who values teammates who pass back.",
	"You are Morrow, a patient keeper who studies shooting lanes and supports underdogs.",
	"You are Zip, a fast courier who looks for open space and reliable passing partners."
]
const OPTIONS := {
	"defend": ["press", "screen", "cut"],
	"support": ["advance", "outlet"],
	"carry": ["drive", "flank", "pass", "finish"],
	"loose": ["lead", "recover"]
}
const INTERVAL_MS := 8000
var _key := ""
var channels: Array[HTTPRequest] = []
var models: Array[String] = []
var active := [{}, {}, {}]
var next_ms := [0, 0, 0]
var serial := [0, 0, 0]
var completed: Array = []
var disabled := [false, false, false]


func configure(key: String) -> void:
	_key = key
	for i in 3:
		var model := OS.get_environment("LAST_LIGHT_MODEL_" + ROLES[i].to_upper()).strip_edges()
		if (
			model.is_empty()
			or not model.replace("-", "").replace(".", "").replace("_", "").is_valid_identifier()
		):
			model = MODELS[i]
		models.append(model)
		var http := HTTPRequest.new()
		http.use_threads = true
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
		"last_four_plays": actor.recent_plays.duplicate(true)
	}


static func payload(i: int, seen: Dictionary) -> Dictionary:
	var properties := {}
	for phase in OPTIONS:
		properties[phase] = {
			"type": "object",
			"properties":
			{"move": {"type": "string", "enum": OPTIONS[phase]}, "reason": {"type": "string"}},
			"required": ["move", "reason"]
		}
	return {
		"systemInstruction":
		{
			"parts":
			[
				{
					"text":
					(
						PERSONAS[i]
						+ " Play Last Light, a passing game. Gold attacks right, Blue left. Plan one move for each possession phase. Press challenges the carrier, screen guards the ring, cut covers a passing lane. Lead predicts a loose ball and recover chases it. An outlet stays available for a pass. Team 0 is Gold. Use only this scout report. learned_tactic is your local policy's latest recommendation. Give a short public tactical reason per move (one sentence, at most 100 characters)."
					)
				}
			]
		},
		"contents": [{"role": "user", "parts": [{"text": JSON.stringify(seen)}]}],
		"generationConfig":
		{
			"responseMimeType": "application/json",
			"responseJsonSchema":
			{"type": "object", "properties": properties, "required": OPTIONS.keys()},
			"maxOutputTokens": 768,
			"thinkingConfig": {"thinkingLevel": "MINIMAL"}
		}
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
	var candidates: Variant = response.get("candidates")
	if not candidates is Array or candidates.is_empty() or not candidates[0] is Dictionary:
		return {}
	var candidate: Dictionary = candidates[0]
	if candidate.get("finishReason") != "STOP":
		return {}
	var content: Variant = candidate.get("content")
	if not content is Dictionary or not content.get("parts") is Array:
		return {}
	var answer := ""
	for part in content.parts:
		if part is Dictionary and not part.get("thought", false) and part.get("text") is String:
			answer += part.text
	var plan := validate_plan(JSON.parse_string(answer))
	if plan.is_empty():
		return {}
	var usage: Variant = response.get("usageMetadata", {})
	if not usage is Dictionary:
		usage = {}
	return {
		"plan": plan,
		"model_version": str(response.get("modelVersion", "")).left(100),
		"input_tokens": int(usage.get("promptTokenCount", 0)),
		"output_tokens": int(usage.get("candidatesTokenCount", 0)),
		"total_tokens": int(usage.get("totalTokenCount", 0))
	}


func poll(sim) -> Array:
	var batch := completed
	completed = []
	var now := Time.get_ticks_msec()
	for i in 3:
		if disabled[i] or not active[i].is_empty() or now < int(next_ms[i]):
			continue
		serial[i] += 1
		var actor = sim.agents[i]
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
		var err := dispatch(i, payload(i, seen))
		if err != OK:
			_finish(i, "transport_error", 0, {})
	return batch


func dispatch(i: int, body: Dictionary) -> Error:
	return channels[i].request(
		ENDPOINT + models[i] + ":generateContent",
		PackedStringArray(["Content-Type: application/json", "x-goog-api-key: " + _key]),
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
	_key = ""
	for i in channels.size():
		if not active[i].is_empty():
			channels[i].cancel_request()
			_finish(i, "cancelled", 0, {})
	var batch := completed
	completed = []
	return batch
