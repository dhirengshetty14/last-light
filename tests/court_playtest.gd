extends SceneTree
## Play both keyboard seats through the actual scene. Also doubles as a movie-writer input track.
const Scene = preload("res://game/last_light.tscn")
const Pilots = preload("res://learning/captains.gd")
var free := false
var honest := [true, true]
var saw_promises := false
var saw_radio := false
var went_dark := false
var shots := ""
var taken: Dictionary = {}
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
var last_pass_tick := -100
var next_key: Dictionary = {}


func _initialize() -> void:
	rivals = "--rivals" in OS.get_cmdline_user_args()
	swap = "--swap-pilots" in OS.get_cmdline_user_args()
	free = "--free" in OS.get_cmdline_user_args()
	if "--liars" in OS.get_cmdline_user_args():
		honest = [false, false]
	for arg in OS.get_cmdline_user_args():
		# Run with a window and --shots=<folder> to save stills of each stage for review.
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots)
	game = Scene.instantiate()
	root.add_child.call_deferred(game)
	root.title = "Last Light"


func click(n: int) -> void:
	var button: Button = game.front.nav.get_child(0).get_child(n)
	button.pressed.emit()


func snap(label: String) -> void:
	if shots == "" or taken.has(label):
		return
	taken[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [shots, taken.size(), label])


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
	if total_frames > 16000:
		push_error("Playtest timed out")
		quit(1)
		return false
	if old_phase != game.phase:
		age = 0
		old_phase = game.phase
	age += 1
	match game.phase:
		"prologue":
			if game.chapter_time > 1.2:
				snap("tale-%d" % game.tale)
		"story":
			visited[game.chapter] = true
			if game.chapter_time > 1.2:
				snap("card-%d" % game.chapter)
		"select":
			if age == 60:
				snap("modes")
			if age == 90:
				click(0 if free else (1 if rivals else 2))
		"pilots":
			if age == 12:
				click(int(swap))
		"brief":
			if age == 80:
				snap("brief")
			if age == 114:
				click(0)
		"pause":
			if age == 42:
				click(0)
				checked_pause = true
		"play":
			var s = game.sim
			if free:
				saw_promises = saw_promises or "owes" in game.front.promises.text
				saw_radio = saw_radio or "owes me" in game.front.radio.text
				went_dark = went_dark or game.dusk > .9
				traces = s.seq
				if s.tick == 150:
					snap("promises")
				if s.kept[0] + s.kept[1] > 0:
					snap("kept")
				if s.broken[0] + s.broken[1] > 0:
					snap("broken")
				if s.vote_at > 0 and s.tick > s.vote_at - 60:
					snap("vote-called")
				if game.dusk > .97:
					snap("union")
				if s.union and s.tick > s.restart_until + 150:
					snap("union-play")
				var orders: Array = Pilots.inputs(s, honest)
				for i in 2:
					var seat := 1 - i if swap else i
					var c: Dictionary = orders[i]
					add_motion(seat, c.get("move", Vector2.ZERO))
					for verb in [
						["shoot", KEY_E, KEY_ENTER],
						["pass", KEY_F, KEY_SLASH],
						["ally_pass", KEY_R, KEY_COMMA],
						["dash", KEY_SHIFT, KEY_PERIOD],
						["invite", KEY_Q, KEY_P]
					]:
						# Tap rather than hold: a held key only registers once in the game.
						if c.get(verb[0], false) and total_frames % 2 == 0:
							next_key[verb[1 + seat]] = true
				tick_keys()
				return false
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
				var seat := 1 - i if swap else i
				var p: Vector2 = s.pos[i]
				var dest: Vector2 = s.floor_ball()
				var wing := 2.35 if i == 0 else -2.35
				if s.owner == i:
					dest = s.goal(i)
					if p.x < s.RING - s.SHOT_RANGE - .5:
						dest.y = wing
					if p.distance_to(s.goal(i)) < s.SHOT_RANGE - .16:
						next_key[[KEY_E, KEY_ENTER][seat]] = true
					else:
						var marker := INF
						for bot in range(2, 5):
							if s.team[bot] != 0:
								marker = minf(marker, p.distance_to(s.pos[bot]))
						if (
							(s.tick == 18 or (marker < 1.35 and s.pos[1 - i].x > p.x + 1.8))
							and s.tick > last_pass_tick + 98
						):
							next_key[[KEY_F, KEY_SLASH][seat]] = true
							last_pass_tick = s.tick
						elif marker < 2.35 and s.tick >= s.cooldown[i]:
							next_key[[KEY_SHIFT, KEY_PERIOD][seat]] = true
				elif s.owner < 0 and s.flight == "pass" and s.throw_side == 0:
					dest = s.reception_point if s.target == i else Vector2(s.RING - 1.6, wing)
				elif s.owner >= 0 and s.team[s.owner] == 0:
					dest = Vector2(s.RING - 1.6, wing)
				elif s.owner >= 0:
					dest = s.pos[s.owner] + Vector2(s.vel[s.owner]) * .19
					if p.distance_to(s.pos[s.owner]) < 1.15 and s.tick >= s.cooldown[i]:
						next_key[[KEY_SHIFT, KEY_PERIOD][seat]] = true
				if (
					not rivals
					and i == 0
					and not recruited
					and p.distance_to(s.pos[2]) < 1.85
					and s.tick % 8 == 0
				):
					next_key[[KEY_Q, KEY_P][seat]] = true
				if p.distance_to(dest) > .16:
					add_motion(seat, p.direction_to(dest))
		"end":
			if age == 70:
				snap("final")
			if age >= 115 and free:
				var s = game.sim
				var fine: bool = (
					s.free_agents
					and saw_promises
					and saw_radio
					and game.front.final_card.visible
					and s.kept[0] + s.kept[1] + s.broken[0] + s.broken[1] > 0
					and went_dark == s.union
					# Written rules always walk out on two cheats. Robots that learned may not.
					and (s.union if honest == [false, false] and game.written_rules else true)
				)
				print(
					"FREE AGENTS PLAYTEST ",
					{
						"ok": fine,
						"honest": honest,
						"learned": s.social_learning,
						"union": s.union,
						"went_dark": went_dark,
						"kept": s.kept,
						"broken": s.broken,
						"goals": s.goals,
						"captain_goals": s.captain_goals,
						"seconds": s.tick / 60,
						"events": traces,
						"headline": game.front.heading.text
					}
				)
				quit(0 if fine else 1)
			elif age >= 115:
				var ok: bool = (
					visited.size() == 5
					and touched == [true, true]
					and recruited == (not rivals)
					and seat_input_verified
					and saw_plans
					and did_pass
					and gold_goal
					and game.box_score.passes[0] > 0
					and game.front.final_card.visible
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
