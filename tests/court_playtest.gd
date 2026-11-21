extends SceneTree
## Play both keyboard seats through the actual scene. Also doubles as a movie-writer input track.
const Scene = preload("res://game/last_light.tscn")
var game
var visited: Dictionary = {}
var held: Dictionary = {}
var age := 0
var old_phase := ""
var rivals := false
var swap := false
var seat_input_verified := false
var saw_plans := false
var recruited := false
var did_pass := false
var touched := [false, false]
var gold_goal := false
var traces := 0
var checked_pause := false
var total_frames := 0
var next_key: Dictionary = {}


func _initialize() -> void:
	rivals = "--rivals" in OS.get_cmdline_user_args()
	swap = "--swap-pilots" in OS.get_cmdline_user_args()
	game = Scene.instantiate()
	root.add_child.call_deferred(game)
	root.title = "Last Light"


func click(n: int) -> void:
	var button: Button = game.front.nav.get_child(0).get_child(n)
	button.pressed.emit()


func key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tick_keys() -> void:
	for code in held:
		if not next_key.has(code):
			key(code, false)
	for code in next_key:
		if not held.has(code):
			key(code, true)
	Input.flush_buffered_events()
	held = next_key
	next_key = {}


func add_motion(i: int, d: Vector2) -> void:
	var binds: Array = [[KEY_A, KEY_D, KEY_W, KEY_S], [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]][i]
	if d.x < -.19:
		next_key[binds[0]] = true
	if d.x > .19:
		next_key[binds[1]] = true
	if d.y < -.19:
		next_key[binds[2]] = true
	if d.y > .19:
		next_key[binds[3]] = true


func _physics_process(_dt: float) -> bool:
	total_frames += 1
	if not is_instance_valid(game) or not game.is_node_ready():
		return false
	if total_frames > 12000:
		push_error("Playtest timed out")
		quit(1)
		return false
	if old_phase != game.phase:
		age = 0
		old_phase = game.phase
	age += 1
	match game.phase:
		"story":
			visited[game.chapter] = true
		"select":
			if age == 90:
				click(0 if rivals else 1)
		"pilots":
			if age == 12:
				click(int(swap))
		"brief":
			if age == 114:
				click(0)
		"pause":
			if age == 42:
				click(0)
				checked_pause = true
		"play":
			var s = game.sim
			if s.tick < 4:
				next_key[KEY_D] = true
				next_key[KEY_LEFT] = true
				tick_keys()
				return false
			if s.tick == 4:
				var p1 := int(swap)
				seat_input_verified = (
					s.vel[p1].x > 0
					and s.vel[1 - p1].x < 0
					and game.cast[p1].tag.text.begins_with("P1")
					and game.cast[1 - p1].tag.text.begins_with("P2")
				)
			if s.tick == 80 or s.tick == 105:
				next_key[KEY_TAB] = true
			if (
				game.front.ledger.visible
				and "Morrow" in game.front.ledger.text
				and "Zip" in game.front.ledger.text
				and "Pip" in game.front.ledger.text
			):
				saw_plans = true
			if s.tick > 20:
				touched[0] = touched[0] or Vector2(s.pos[0]).distance_to(s.START[0]) > .23
				touched[1] = touched[1] or Vector2(s.pos[1]).distance_to(s.START[1]) > .23
			if s.team[2] == 0:
				recruited = true
			if s.habits[0][1] + s.habits[1][1] > 0:
				did_pass = true
			gold_goal = gold_goal or s.goals[0] > 0
			traces = s.seq
			if s.tick == 160 and not checked_pause:
				next_key[KEY_ESCAPE] = true
			for i in 2:
				var physical_seat: int = 1 - i if swap else i
				var dest: Vector2 = s.floor_ball()
				if s.owner == i:
					dest = s.goal(i)
					if s.pos[i].distance_to(dest) <= 2.8:
						next_key[[KEY_E, KEY_ENTER][physical_seat]] = true
					elif s.tick % 90 == 72:
						next_key[[KEY_SHIFT, KEY_PERIOD][physical_seat]] = true
					if (s.tick == 55 and i == 0) or (s.tick % 145 == 53 and s.pos[i].x < 1.5):
						next_key[[KEY_F, KEY_SLASH][physical_seat]] = true
				elif s.owner >= 0 and s.team[s.owner] == 0:
					dest = Vector2(3.65, -1.35 if s.pos[s.owner].y > 0 else 1.35)
				elif s.owner >= 0 and s.pos[i].distance_to(dest) < .8 and s.tick % 3 == 0:
					next_key[[KEY_SHIFT, KEY_PERIOD][physical_seat]] = true
				if (
					i == 0
					and not recruited
					and s.pos[0].distance_to(s.pos[2]) < 1.85
					and s.tick % 12 == 0
				):
					next_key[[KEY_Q, KEY_P][physical_seat]] = true
				add_motion(physical_seat, Vector2(s.pos[i]).direction_to(dest))
		"end":
			if age >= 115:
				var ok: bool = (
					visited.size() == 5
					and touched == [true, true]
					and recruited == (not rivals)
					and seat_input_verified
					and saw_plans
					and did_pass
					and checked_pause
					and traces > 20
				)
				print(
					"SCENE PLAYTEST ",
					{
						"ok": ok,
						"cast": visited.size(),
						"seat_input": seat_input_verified,
						"notebooks": saw_plans,
						"swapped": swap,
						"rivals": rivals,
						"two_inputs": touched,
						"recruited": recruited,
						"pass": did_pass,
						"pause": checked_pause,
						"gold_goal": gold_goal,
						"goals": game.sim.goals,
						"events": traces
					}
				)
				quit(0 if ok else 1)
	tick_keys()
	return false
