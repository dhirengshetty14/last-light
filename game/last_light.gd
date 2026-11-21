extends Node3D
const Game = preload("res://game/star_match.gd")
const Room = preload("res://game/room_art.gd")
const Performer = preload("res://game/crew_visual.gd")
const Front = preload("res://game/star_ui.gd")
const Coach = preload("res://game/gemini_coach.gd")
var coach: Coach
var session_key := ""
const Recorder = preload("res://game/flight_recorder.gd")
const AMBER := Color("#ffce76")
const BLUE := Color("#78e2ed")
const LINEUP = [
	Vector2(-3.4, .08),
	Vector2(3.3, .16),
	Vector2(-1.70, .30),
	Vector2(.04, -.2),
	Vector2(1.61, .20)
]
const CAST = [
	[
		"NELL   /   GOLD PILOT",
		"When the sun goes down, this little star keeps the harbor lit. Let's get it home."
	],
	["RAFI   /   GOLD RECEIVER", "Look for my purple jacket. If you get boxed in, pass it here."],
	["PIP   /   BALL THIEF", "Blue gave me a jersey. Gold could always use a good pair of hands."],
	["MORROW   /   KEEPER", "Everyone has a favorite route. Give me time. I'll find yours."],
	["ZIP   /   SPRINTER", "See the blue ring? Bet I can get there before you turn around."]
]
var room := Room.new()
var front := Front.new()
var camera := Camera3D.new()
var sim = Game.new()
var cast: Array = []
var badges: Array = []
var hoops: Array = []
var star := Node3D.new()
var shade_disc: MeshInstance3D
var beacon: Node3D
var music := AudioStreamPlayer.new()
var voice := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var clips: Dictionary = {}
var phase := "title"
var clock := 0.
var chapter := -1
var chapter_time := 0.
var duration := 2.9
var crews := false
var pilot_for_seat: Array[int] = [0, 1]
var positions: Array = Game.START.duplicate()
var scoring_team := -1
var goal_pose: Array = []
var goal_spot := Vector3.ZERO
var old_ball := Vector3.ZERO
var stride := [0., 0., 0., 0., 0.]
var aim_dots: Array = []
var message := ""
var message_until := 0
var last_voice := -150
var last_ledger := [-1, -1, -99, -99, -99]
var command_edges := [{}, {}]
var pad_edges := [{}, {}]
var muted := false
var random := RandomNumberGenerator.new()
var recorder = Recorder.new()
var training: Dictionary = {}
var social_memory: Dictionary = {}
const SAVE_PATH := "user://last-light-policy.json"
var capture_path := ""
var frame_samples: Array[float] = []
var slow_frames: Array = []
var wall_frame := 0
var capture_step := 0
var capture_timer := 0.
var captured_once := false
var forced_seed := -1
var capture_session := false
var benchmark_only := false
var test_session := false


func _ready() -> void:
	get_window().title = "Last Light"
	random.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg == "--court-playtest":
			test_session = true
		if arg.begins_with("--seed="):
			forced_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--court-benchmark="):
			benchmark_only = true
			arg = "--court-capture=" + arg.trim_prefix("--court-benchmark=")
		if arg.begins_with("--court-capture="):
			capture_path = arg.trim_prefix("--court-capture=")
			DirAccess.make_dir_recursive_absolute(capture_path)
			capture_session = true
	add_child(room)
	room.build(true)
	court()
	add_child(camera)
	camera.current = true
	for i in 5:
		var doll := Performer.new()
		add_child(doll)
		doll.setup(i, false)
		cast.append(doll)
		var gold = room.metal("jersey gold", "#ffbd5d", .45, .25, 1.0)
		var blue = room.metal("jersey blue", "#5bdbe8", .45, .25, 1.0)
		var badge = room.torus(self, Vector3.ZERO, .277, .305, gold if i < 2 else blue)
		badges.append([badge, gold, blue])
	add_child(music)
	add_child(voice)
	add_child(effects)
	effects.max_polyphony = 4
	for key in [
		"nell_intro",
		"rafi_intro",
		"pip_intro",
		"morrow_intro",
		"zip_intro",
		"pip_join",
		"morrow_join",
		"zip_join",
		"pip_steal",
		"morrow_steal",
		"zip_steal",
		"toss",
		"turnover",
		"goal",
		"accord"
	]:
		clips[key] = load("res://assets/last_light/" + key + ".wav")
	var theme: AudioStreamOggVorbis = load("res://assets/last_light/last_light.ogg")
	theme.loop = true
	music.stream = theme
	music.volume_db = -9
	if DisplayServer.get_name() != "headless":
		music.play()
	voice.volume_db = -1
	effects.volume_db = -10
	add_child(front)
	front.key_changed.connect(set_session_key)
	if not test_session and not capture_session:
		var key := OS.get_environment("GEMINI_API_KEY")
		if key.is_empty():
			key = OS.get_environment("GOOGLE_API_KEY")
		set_session_key(key)
	front.chosen.connect(handle)
	var pretrained = Game.Policy.new()
	pretrained.load_checkpoint("res://learning/star_checkpoint.json")
	if not test_session and not capture_session:
		pretrained.add_local_examples("user://verified-responses.json")
	var saved = Game.Policy.new()
	if not test_session and not capture_session:
		saved.load_checkpoint(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
			if data is Dictionary and data.get("relationships") is Dictionary:
				social_memory = data.relationships
	for key in saved.estimates:
		var current: Array = pretrained.estimates.get(key, [0, 0, 0])
		if key.begins_with("star2/") and saved.estimates[key][0] > current[0]:
			pretrained.estimates[key] = saved.estimates[key]
	training = pretrained.estimates
	intro()


func court() -> void:
	var enamel = room.metal("ivory chalk", "#ada18b", .68, .14)
	var colored = [
		room.metal("gold beacon", "#ffba47", .32, .23, 2.),
		room.metal("blue beacon", "#4bdcfa", .31, .27, 1.8)
	]
	var brass = room.metal("copper housing", "#a3774e", .35, .68)
	for z in [-2.17, 2.17]:
		room.box(self, Vector3(0, .028, z), Vector3(11.45, .021, .023), enamel)
	for n in 11:
		room.box(self, Vector3(0, .031, -2.03 + n * .40), Vector3(.027, .018, .16), enamel)
	room.torus(self, Vector3(0, .038, 0), .81, .833, enamel)
	for side in 2:
		var x := Game.RING if side == 0 else -Game.RING
		var center := Vector3(x, Game.HEIGHT, 0)
		var ring := Node3D.new()
		add_child(ring)
		ring.position = center
		hoops.append(ring)
		for sign_side in [-1, 1]:
			room.tube(
				self,
				Vector3(x + signf(x) * .13, .05, sign_side * .72),
				center + Vector3(0, -.46, sign_side * .65),
				.062,
				brass
			)
			room.box(self, Vector3(x, .071, sign_side * .72), Vector3(.38, .11, .42), brass)
		room.torus(ring, Vector3.ZERO, .68, .76, colored[side]).rotation.z = PI * .5
		room.torus(ring, Vector3(signf(x) * .10, 0, 0), .71, .80, brass).rotation.z = PI * .5
		for k in 8:
			var a := TAU * k / 8.
			room.ball(
				ring, Vector3(0, cos(a) * .78, sin(a) * .78), Vector3.ONE * .048, colored[side]
			)
		room.placard(
			self,
			"GOLD" if side == 0 else "BLUE",
			center + Vector3(0, 1.05, 0),
			AMBER if side == 0 else BLUE,
			34
		)
		for k in 9:
			var a := -.5 * PI + PI * k / 8.
			room.box(
				self,
				Vector3(x - signf(x) * cos(a) * 2.5, .034, sin(a) * 1.91),
				Vector3(.08, .025, .08),
				colored[side]
			)
	add_child(star)
	var light = room.metal("stellar core", "#ffdc85", .22, .46, 3.1)
	room.ball(star, Vector3.ZERO, Vector3.ONE * .177, light)
	for k in 3:
		var orbit = room.torus(star, Vector3.ZERO, .201, .223, brass)
		orbit.rotation = Vector3(k * .92, 0, k * .8)
	for axis in [
		Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK
	]:
		var cone := CylinderMesh.new()
		cone.radial_segments = 5
		cone.top_radius = 0
		cone.bottom_radius = .068
		cone.height = .21
		var tip = room.draw(star, cone, axis * .213, light)
		tip.quaternion = Quaternion(Vector3.UP, axis)
	var glint = room.metal("arc guide", "#ffdd89", .35, .14, 1.20)
	for n in 7:
		var dot = room.ball(self, Vector3.ZERO, Vector3.ONE * .027, glint)
		dot.hide()
		aim_dots.append(dot)
	shade_disc = room.torus(self, Vector3.ZERO, .18, .204, colored[0])
	beacon = room.make_whale(self, 3.8)
	beacon.hide()


func intro() -> void:
	phase = "title"
	chapter = -1
	chapter_time = 0
	duration = 3.7
	front.match_hud.hide()
	front.home()
	voice.stop()
	star.show()
	for dot in aim_dots:
		dot.hide()
	beacon.scale = Vector3.ONE * .58
	beacon.position = Vector3(3.15, 3.93, -4.65)
	beacon.show()
	for hoop in hoops:
		hoop.scale = Vector3.ONE
	for i in 5:
		var p: Vector2 = LINEUP[i]
		cast[i].show()
		cast[i].position = Vector3(p.x, 0, p.y)
		cast[i].rotation.y = -.11 if i < 3 else .12
		cast[i].tag.hide()
		badges[i][0].hide()
	shade_disc.hide()
	wide(true)


func next_card() -> void:
	if chapter >= 4:
		select_mode()
		return
	phase = "story"
	chapter += 1
	chapter_time = 0
	var key := str(Performer.FILES[chapter]) + "_intro"
	say(key)
	duration = maxf(3.3, clips[key].get_length() + .72)
	front.dialogue(
		CAST[chapter][0], CAST[chapter][1], "SPACE   Next character       ESC   Choose mode"
	)
	portrait(0.)


func portrait(t: float) -> void:
	var p: Vector3 = cast[chapter].position
	var y: float = [1.34, 1.40, .67, 1.25, 1.14][chapter]
	var aim := p + Vector3(.12, y, 0)
	var dir := Vector3(.50 + sin(t * .30) * .19, .15, 2.76)
	camera.position = aim + dir
	camera.fov = 37.4
	camera.look_at(aim)


func wide(lineup := false) -> void:
	camera.fov = 43. if lineup else 44.
	camera.position = Vector3(0, 3.77, 10.9) if lineup else Vector3(0, 4.6, 10.85)
	camera.look_at(Vector3(0, 1.26, -.60) if lineup else Vector3(0, .93, -.26))


func select_mode() -> void:
	end_log()
	intro()
	phase = "select"
	front.modes()


func pilot_names() -> Array:
	return [Game.NAMES[pilot_for_seat[0]], Game.NAMES[pilot_for_seat[1]]]


func select_pilots() -> void:
	phase = "pilots"
	star.hide()
	for i in 5:
		cast[i].visible = i < 2
		if i < 2:
			cast[i].position = Vector3(-.90 if i == 0 else .90, 0, 0)
			cast[i].rotation.y = .10 if i == 0 else -.10
			cast[i].tag.text = Game.NAMES[i]
			cast[i].tag.font_size = 24
			cast[i].tag.position.y = 1.98
			cast[i].tag.show()
	camera.position = Vector3(0, 1.72, 4.70)
	camera.fov = 36.
	camera.look_at(Vector3(0, 1.30, 0))
	front.pilots(crews)


func handle(cmd: String) -> void:
	match cmd:
		"next":
			next_card()
		"skip", "select":
			select_mode()
		"replay":
			intro()
		"rivals", "crews":
			crews = cmd == "crews"
			select_pilots()
		"pilots":
			select_pilots()
		"nell", "rafi":
			pilot_for_seat.assign([0, 1] if cmd == "nell" else [1, 0])
			phase = "brief"
			for seat in 2:
				cast[pilot_for_seat[seat]].tag.text = (
					"P%d  %s" % [seat + 1, Game.NAMES[pilot_for_seat[seat]]]
				)
			front.briefing(crews, pilot_names())
		"again", "play":
			start()
		"resume":
			phase = "play"
			command_edges = [{}, {}]
			front.match_view()


func set_session_key(value: String) -> void:
	session_key = value.strip_edges()
	if session_key != session_key.strip_escapes() or session_key.contains(" "):
		session_key = ""
	front.key_set = not session_key.is_empty()


func start() -> void:
	end_log()
	goal_pose.clear()
	scoring_team = -1
	sim = Game.new()
	sim.configure_agents(training, social_memory)
	var seed_value := forced_seed if forced_seed >= 0 else int(random.randi())
	sim.setup(seed_value, crews)
	if not session_key.is_empty() and not test_session and not capture_session:
		coach = Coach.new()
		add_child(coach)
		coach.configure(session_key)
	phase = "play"
	beacon.scale = Vector3.ONE
	beacon.hide()
	chapter_time = 0.
	command_edges = [{}, {}]
	pad_edges = [{}, {}]
	star.show()
	last_voice = -200
	last_ledger = [-1, -1, -99, -99, -99]
	message_until = 230
	message = "Nell has the light. Gold attacks right."
	positions = sim.pos.duplicate()
	old_ball = sim.ball
	front.history.clear()
	front.ledger.text = ""
	front.ledger.hide()
	front.match_view()
	wide()
	room.location(int(crews))
	voice.stop()
	shade_disc.show()
	for i in 5:
		cast[i].show()
		cast[i].tag.font_size = 36
		cast[i].tag.show()
		badges[i][0].show()
		cast[i].rotation.y = PI * .48 if i < 2 else -PI * .48
	render_game(0., 1.)
	var run := "%d-%d" % [Time.get_unix_time_from_system() * 1000000, seed_value]
	var directory := "user://flights"
	if test_session or capture_session:
		directory = "user://court-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	recorder = Recorder.new()
	recorder.begin(
		directory + "/" + run + ".jsonl",
		{
			"kind": "header",
			"run": run,
			"seed": seed_value,
			"game": "last-light-v4",
			"origin": "capture" if test_session or capture_session else "local_play",
			"open_crews": crews,
			"input_schema": 1,
			"starting_policy": sim.learned_weights().duplicate(true),
			"starting_relationships": sim.relationships(),
			"seat_pilots": pilot_names(),
			"gemini_models": coach.models.duplicate() if coach else []
		}
	)
	update_hud()


func end_log() -> void:
	if coach:
		sim.apply_model_packets(coach.close(), true)
		recorder.append(sim.events)
		sim.events = []
		coach.queue_free()
		coach = null
	if recorder.opened:
		training = sim.learned_weights()
		social_memory = sim.relationships()
		if not capture_session and not test_session:
			var path := SAVE_PATH
			var staged := path + ".next." + str(OS.get_process_id())
			var f := FileAccess.open(staged, FileAccess.WRITE)
			if f:
				f.store_string(
					JSON.stringify(
						{
							"schema": "response-policy-v1",
							"estimates": training,
							"relationships": social_memory
						}
					)
				)
				f.close()
				DirAccess.rename_absolute(
					ProjectSettings.globalize_path(staged), ProjectSettings.globalize_path(path)
				)
		recorder.finish(
			{
				"kind": "footer",
				"tick": sim.tick,
				"gold": sim.goals[0],
				"blue": sim.goals[1],
				"completed": sim.finished
			}
		)


func _exit_tree() -> void:
	end_log()
	for player in [music, voice, effects]:
		player.stop()
		player.stream = null


func say(key: String) -> void:
	voice.stream = clips[key]
	if DisplayServer.get_name() != "headless":
		voice.play()


func sound(key: String) -> void:
	effects.stream = clips[key]
	if DisplayServer.get_name() != "headless":
		effects.play()


func _input(ev: InputEvent) -> void:
	if front.key_dialog and front.key_dialog.visible:
		return
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: int = ev.physical_keycode
	if k == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
		return
	if k == KEY_B:
		room.life.reduced = not room.life.reduced
		return
	if k == KEY_ESCAPE:
		match phase:
			"brief":
				select_pilots()
			"title", "story", "pilots", "end":
				select_mode()
			"pause":
				handle("resume")
			"play":
				phase = "pause"
				front.pause_menu()
		get_viewport().set_input_as_handled()
		return
	if phase == "story" and (k == KEY_SPACE or k == KEY_ENTER):
		next_card()
		get_viewport().set_input_as_handled()
		return
	if phase != "play":
		return
	if k == KEY_TAB:
		front.ledger.visible = not front.ledger.visible
	var keys := [[KEY_E, KEY_F, KEY_SHIFT, KEY_Q], [KEY_ENTER, KEY_SLASH, KEY_PERIOD, KEY_P]]
	for i in 2:
		var n: int = keys[i].find(k)
		if n >= 0:
			command_edges[pilot_for_seat[i]][["shoot", "pass", "dash", "invite"][n]] = true
	get_viewport().set_input_as_handled()


func _physics_process(_dt: float) -> void:
	if phase != "play":
		return
	var keys := [[KEY_A, KEY_D, KEY_W, KEY_S], [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]]
	for i in 2:
		command_edges[pilot_for_seat[i]]["move"] = Vector2(
			(
				int(Input.is_physical_key_pressed(keys[i][1]))
				- int(Input.is_physical_key_pressed(keys[i][0]))
			),
			(
				int(Input.is_physical_key_pressed(keys[i][3]))
				- int(Input.is_physical_key_pressed(keys[i][2]))
			)
		)
	var pads := Input.get_connected_joypads()
	for n in mini(pads.size(), 2):
		var seat := 1 if pads.size() == 1 else n
		var stick := Vector2(
			Input.get_joy_axis(pads[n], JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pads[n], JOY_AXIS_LEFT_Y)
		)
		if stick.length() > .20:
			command_edges[pilot_for_seat[seat]]["move"] = stick.limit_length(1.)
		for binding in [
			["shoot", JOY_BUTTON_A],
			["pass", JOY_BUTTON_X],
			["dash", JOY_BUTTON_RIGHT_SHOULDER],
			["invite", JOY_BUTTON_Y]
		]:
			var down := Input.is_joy_button_pressed(pads[n], binding[1])
			if down and not pad_edges[seat].get(binding[0], false):
				command_edges[pilot_for_seat[seat]][binding[0]] = true
			pad_edges[seat][binding[0]] = down
	positions = sim.pos.duplicate()
	old_ball = sim.ball
	sim.step(command_edges, coach.poll(sim) if coach else [])
	command_edges = [{}, {}]
	for e in sim.events:
		present(e)
	recorder.append(sim.events)
	sim.events = []
	if sim.finished:
		end_log()
		phase = "end"
		front.results(sim.goals[0], sim.goals[1])
	else:
		update_hud()


func present(e: Dictionary) -> void:
	var i: int = e.seat
	match str(e.kind):
		"throw":
			sound("toss")
		"response_intent":
			if sim.tick - last_ledger[i] > 100:
				front.record(Game.NAMES[i] + "  ·  " + e.reason)
				last_ledger[i] = sim.tick
		"custody":
			if e.method == "restart":
				return
			if e.method == "steal":
				sound("turnover")
				if i >= 2 and sim.tick - last_voice > 170:
					say(Performer.FILES[i] + "_steal")
					last_voice = sim.tick
			if sim.tick >= message_until or e.method == "steal":
				message = (
					Game.NAMES[i]
					+ (" steals the light!" if e.method == "steal" else " catches the light.")
				)
				message_until = sim.tick + 67
		"goal":
			goal_pose = positions.duplicate()
			scoring_team = e.team
			goal_spot = Vector3(Game.RING if scoring_team == 0 else -Game.RING, Game.HEIGHT, 0)
			sound("goal")
			message = (
				Game.NAMES[i] + " lights the " + ("gold" if e.team == 0 else "blue") + " ring!"
			)
			message_until = sim.tick + 128
			front.record(message)
		"aurora":
			message = Game.NAMES[i] + " lit the far beacon. Both rings widen!"
			message_until = sim.tick + 138
			front.record(message)
		"pass_request":
			message = Game.NAMES[i] + " calls to " + Game.NAMES[e.to] + " for the ball."
			message_until = sim.tick + 90
		"alliance":
			message = e.reason
			message_until = sim.tick + 145
			front.record(message)
			if e.changed:
				sound("accord")
				if e.team == 0:
					say(Performer.FILES[i] + "_join")
		"out_of_reach":
			message = "Move beside a robot to offer a jersey."
			message_until = sim.tick + 100


func update_hud() -> void:
	if front.ledger.visible and (sim.tick % 8 == 0 or front.ledger.text.is_empty()):
		front.show_plans(sim)
	var left := ceili((Game.END - sim.tick) / 60.)
	front.score.text = (
		"GOLD  %d    /    %d  BLUE    ·    %d:%02d"
		% [sim.goals[0], sim.goals[1], left / 60, left % 60]
	)
	var prompt := "Loose star   ·   Run to catch it"
	if sim.owner >= 0:
		var who: String = Game.NAMES[sim.owner]
		if sim.owner < 2:
			var key: String = "E" if sim.owner == pilot_for_seat[0] else "Enter"
			prompt = (
				who
				+ "  ·  "
				+ (
					"In range!   " + key + " to shoot  →"
					if sim.pos[sim.owner].distance_to(sim.goal(sim.owner)) <= 2.85
					else "Carry right to the GOLD ring  →"
				)
			)
		else:
			prompt = (
				who
				+ (
					" is on your side   ·   F or / to call for a pass"
					if sim.team[sim.owner] == 0
					else " has the star   ·   Dash close to steal"
				)
			)
	if sim.tick < sim.restart_until:
		prompt = "GOAL  ·  " + ("Gold" if scoring_team == 0 else "Blue") + " lights the ring"
	if sim.tick < sim.surge_until:
		prompt += "     ◇   Beacon active"
	front.objective.text = prompt
	front.feed.text = message if sim.tick < message_until else ""
	front.controls_line.text = (
		(
			"%s   WASD / E shoot / F pass / Shift dash        %s   Arrows / Enter shoot / Slash pass / Period dash       "
			% pilot_names()
		)
		+ ("Q / P ally       " if crews else "")
		+ "Tab ledger   ·   Esc pause"
	)


func _process(dt: float) -> void:
	clock += dt
	chapter_time += dt
	room.life.animate(
		dt, phase == "play" and sim.owner < 0, phase != "play", sim.tick < sim.surge_until, false
	)
	music.volume_db = move_toward(
		music.volume_db, -18. if voice.playing else (-12. if phase == "play" else -8.5), dt * 22.
	)
	if phase in ["play", "end", "pause"]:
		render_game(dt, Engine.get_physics_interpolation_fraction() if phase == "play" else 1.)
	else:
		beacon.position.x = 3.15 + sin(clock * .10) * 1.18
		beacon.position.y = 3.93 + sin(clock * .46) * .10
		beacon.get_node("FlukeLeft").rotation.z = .14 * sin(clock * 1.5)
		beacon.get_node("FlukeRight").rotation.z = .14 * sin(clock * 1.5)
		star.position = Vector3(-2.94, 1.01 + .09 * sin(clock * 1.6), .31)
		for i in 5:
			cast[i].express(
				"Relief" if i == chapter and phase == "story" else "Idle", clock + .42 * i
			)
		if benchmark_only and phase == "title" and chapter_time > .75:
			start()
		elif phase == "title" and chapter_time > duration:
			next_card()
		elif phase == "story":
			portrait(chapter_time)
			if chapter_time > duration:
				next_card()
	star.rotation.y = clock * 1.4
	star.rotation.z = .22 * sin(clock * 1.7)
	if capture_session:
		capture(dt)


func render_game(dt: float, alpha: float) -> void:
	var celebration: bool = (
		not goal_pose.is_empty()
		and (sim.tick < sim.restart_until - 12 or (phase == "end" and sim.goals.max() >= 3))
	)
	var action := phase == "play" and not celebration
	for i in 5:
		var p: Vector2 = Vector2(positions[i]).lerp(sim.pos[i], alpha)
		var doll = cast[i]
		if celebration:
			p = goal_pose[i]
		doll.position = Vector3(p.x, 0, p.y)
		var speed: float = sim.vel[i].length() if action else 0.
		if speed > .14:
			doll.rotation.y = lerp_angle(
				doll.rotation.y, atan2(sim.vel[i].x, sim.vel[i].y), 1. - exp(-dt * 13.)
			)
			stride[i] += dt * speed / .99
		else:
			stride[i] += dt * .57
		if doll.anim:
			doll.anim.speed_scale = clampf(speed / 1.8, .65, 1.90) if speed > .15 else 1.
		var state := (
			"Idle"
			if action or phase == "pause"
			else ("Relief" if sim.goals[sim.team[i]] == sim.goals.max() else "Alarm")
		)
		if celebration:
			state = "Relief" if sim.team[i] == scoring_team else "Alarm"
		doll.express(state, stride[i], speed > .15)
		doll.tag.text = (
			(("P1  " if i == pilot_for_seat[0] else "P2  ") if i < 2 else "") + Game.NAMES[i]
		)
		doll.tag.modulate = AMBER if sim.team[i] == 0 else BLUE
		doll.tag.position.y = [1.98, 2.02, 1.26, 2.02, 1.72][i]
		badges[i][0].position = doll.position + Vector3.UP * .046
		badges[i][0].material_override = badges[i][1 + int(sim.team[i])]
	star.position = goal_spot if celebration else old_ball.lerp(sim.ball, alpha)
	var guided: bool = (
		sim.owner >= 0
		and sim.owner < 2
		and sim.pos[sim.owner].distance_to(sim.goal(sim.owner)) <= 2.85
		and action
	)
	for n in aim_dots.size():
		aim_dots[n].visible = guided
		if guided:
			var t: float = (n + 1.) / 8.
			var end := Vector3(Game.RING, Game.HEIGHT, 0)
			var seconds := clampf(
				Vector2(star.position.x, star.position.z).distance_to(Vector2(Game.RING, 0)) / 7.4,
				.3,
				.92
			)
			aim_dots[n].position = (
				star.position.lerp(end, t) + Vector3.UP * (5.5 * seconds * seconds * t * (1. - t))
			)
	shade_disc.position = Vector3(star.position.x, .055, star.position.z)
	shade_disc.scale = Vector3.ONE * clampf(.67 + star.position.y * .19, .66, 1.2)
	for hoop in hoops:
		hoop.scale = hoop.scale.lerp(
			Vector3.ONE * (.92 / .68 if sim.tick < sim.surge_until else 1.), 1. - exp(-dt * 4.)
		)
	beacon.visible = sim.tick < sim.surge_until
	if beacon.visible:
		var pass_time := 1. - float(sim.surge_until - sim.tick) / 600.
		beacon.position = Vector3(
			lerpf(8., -8., pass_time), 3.28 + sin(pass_time * TAU) * .37, -5.2
		)
		beacon.rotation.z = .08 * sin(clock * 1.9)
		for fin in ["FlukeLeft", "FlukeRight"]:
			beacon.get_node(fin).rotation.z = .21 * sin(clock * 2.8)


func capture(dt: float) -> void:
	var usec := Time.get_ticks_usec()
	if phase == "play" and sim.tick > 60 and wall_frame > 0 and not captured_once:
		var ms: float = (usec - wall_frame) / 1000.
		frame_samples.append(ms)
		if ms > 25 and slow_frames.size() < 24:
			slow_frames.append(
				{
					"tick": sim.tick,
					"ms": ms,
					"restart": sim.tick < sim.restart_until,
					"beacon": sim.tick < sim.surge_until
				}
			)
	wall_frame = usec
	if benchmark_only and phase != "end":
		return
	if captured_once:
		return
	capture_timer += dt
	if capture_timer < .33:
		return
	var name_out := ""
	if phase == "title" and capture_step == 0:
		name_out = "01-title"
	elif phase == "story" and capture_step == chapter + 1:
		name_out = "%02d-%s" % [chapter + 2, Performer.FILES[chapter]]
	elif phase == "select" and capture_step == 6:
		name_out = "07-modes"
	elif phase == "pilots" and capture_step == 7:
		name_out = "08-pilots"
	elif phase == "brief" and capture_step == 8:
		name_out = "09-brief"
	elif phase == "play" and capture_step == 9 and sim.tick > 22:
		name_out = "10-court"
	elif phase == "play" and capture_step == 10 and sim.surge_until > sim.tick:
		name_out = "11-beacon"
	elif phase == "end":
		name_out = "12-final"
	if name_out.is_empty():
		return
	captured_once = true
	if not benchmark_only:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path + "/" + name_out + ".png")
	capture_step += 1
	capture_timer = 0
	if phase == "select":
		handle("rivals")
	elif phase == "pilots":
		handle("nell")
	elif phase == "brief":
		start()
	elif phase == "end":
		if not frame_samples.is_empty():
			frame_samples.sort()
			var f := FileAccess.open(capture_path + "/frame-times.json", FileAccess.WRITE)
			if f:
				f.store_string(
					JSON.stringify(
						{
							"device": RenderingServer.get_video_adapter_name(),
							"pixels": [get_window().size.x, get_window().size.y],
							"frames": frame_samples.size(),
							"median_ms": frame_samples[frame_samples.size() / 2],
							"p95_ms": frame_samples[int(frame_samples.size() * .95)],
							"p99_ms": frame_samples[int(frame_samples.size() * .99)],
							"measurement":
							(
								"live frame intervals without screenshot capture"
								if benchmark_only
								else "includes screenshot readback"
							),
							"max_ms": frame_samples.back(),
							"frames_above_25_ms": slow_frames
						},
						"  "
					)
				)
				f.close()
		get_tree().quit()
	captured_once = false
