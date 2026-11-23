extends Node3D
const Sim = preload("res://game/flight_sim.gd")
const Room = preload("res://game/room_art.gd")
const Crew = preload("res://game/crew_visual.gd")
const UI = preload("res://game/hud.gd")
const Audio = preload("res://game/radio.gd")
const Recorder = preload("res://game/flight_recorder.gd")
const Front = preload("res://game/front_end.gd")
const MODES = ["Idle", "Alarm", "Commit", "Relief", "Walk"]
const JOBS = ["cover", "vote", "fetch"]
var state
var room
var ui
var front
var story_stage := -1
var shot_clock := 0.
var story_base := Vector3.ZERO
var lesson_message := ""
const OPENING = [
	[
		"SATURN NURSERY DOCK",
		"Nell has the towline. Rafi has the kickplate. Outside, a mother is waiting for her calf.",
		"",
		4.0
	],
	[
		"PIP  /  RESCUE HAND",
		"That’s a calf in there, Nell. Hold the line. I’ll take the catch.",
		"pip_story",
		5.7
	],
	[
		"MORROW  /  ARCHIVIST",
		"There are three voices on this reel. Hers is the only one still singing.",
		"morrow_story",
		5.8
	],
	[
		"ZIP  /  COURIER",
		"One pass, Rafi. When that hatch lines up, I’ll be on the rail.",
		"zip_story",
		5.0
	]
]
var radio
var camera: Camera3D
var pawns: Array = []
var gallery_node: Node3D
var cast: Array = []
var gallery_index := 0
var expression := 0
var orbit := .15
var pitch := .14
var zoom := 0
var spin := false
var dragging := false
var in_gallery := false
var started := false
var help_open := false
var selected := [2, 3]
var duties := ["cover", "vote"]
var event_cursor := 0
var elapsed := 0.
var run_seed := 17
var difficulty := 0
var capture := ""
var film := ""
var benchmark := ""
var frame_times: Array[float] = []
var cpu_physics: Array[float] = []
var draw_counts: Array[int] = []
var frame_previous := 0
var frame_count := 0
var trigger_down: Dictionary = {}
const Partners = preload("res://learning/train.gd")
var recorder
var log_path := ""
var initial_checkpoint: Dictionary = {}
var local_play := false
var pinned_seed := false
var shift_seeds := RandomNumberGenerator.new()
var reduced_motion := false
var sync_display := false


func _ready() -> void:
	shift_seeds.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
		if a.begins_with("--film="):
			film = a.trim_prefix("--film=")
		if a.begins_with("--bench="):
			benchmark = a.trim_prefix("--bench=")
		if a == "--ring-storm":
			difficulty = 1
		if a.begins_with("--seed="):
			pinned_seed = true
			run_seed = int(a.trim_prefix("--seed="))
	room = Room.new()
	add_child(room)
	room.build()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 43
	camera.near = .07
	camera.far = 130
	for i in 5:
		var p = Crew.new()
		add_child(p)
		p.setup(i)
		pawns.append(p)
	gallery_node = Node3D.new()
	add_child(gallery_node)
	gallery_node.position = Vector3(135, 0, 0)
	room.box(
		gallery_node,
		Vector3(0, -.22, 0),
		Vector3(30, .35, 30),
		room.metal("studio floor", "#45595e", .56, .3)
	)
	room.torus(gallery_node, Vector3(0, -.01, 0), 1.38, 1.415, room.mats.brass)
	var key := OmniLight3D.new()
	gallery_node.add_child(key)
	key.position = Vector3(-2, 3, 2.3)
	key.light_energy = 2.
	key.omni_range = 6
	key.light_color = Color("#ffe1c5")
	var rim := OmniLight3D.new()
	gallery_node.add_child(rim)
	rim.position = Vector3(1.8, 2, -1.9)
	rim.light_energy = 2.1
	rim.omni_range = 5
	rim.light_color = Color("#9bbde9")
	for i in 5:
		var sample = Crew.new()
		gallery_node.add_child(sample)
		sample.setup(i, false)
		sample.hide()
		cast.append(sample)
	gallery_node.hide()
	ui = UI.new()
	add_child(ui)
	ui.menu_action.connect(menu_command)
	front = Front.new()
	add_child(front)
	front.chosen.connect(menu_command)
	radio = Audio.new()
	radio.muted = (DisplayServer.get_name() == "headless" or capture != "" or film != "")
	add_child(radio)
	var settings := ConfigFile.new()
	if settings.load("user://deck.cfg") == OK:
		reduced_motion = bool(settings.get_value("scene", "reduced_motion", false))
		sync_display = bool(settings.get_value("scene", "sync_display", false))
	apply_display_settings()
	new_flight(false)
	if capture != "" or film != "":
		radio.muted = true
		call_deferred("camera_test")
	elif benchmark != "":
		new_flight(true)


func new_flight(play: bool) -> void:
	close_log()
	radio.reset_shift()
	local_play = (
		play
		and film == ""
		and capture == ""
		and benchmark == ""
		and DisplayServer.get_name() != "headless"
	)
	if local_play and not pinned_seed:
		run_seed = shift_seeds.randi_range(1, 99999999)
	state = Sim.new(run_seed, true, difficulty)
	state.policy.load_checkpoint("res://learning/checkpoint.json")
	if local_play:
		state.policy.add_local_examples("user://verified-responses.json")
	initial_checkpoint = state.policy.estimates.duplicate(true)
	event_cursor = 0
	started = play
	help_open = false
	in_gallery = false
	story_stage = -1
	room.practice = false
	room.location(difficulty)
	front.leave()
	ui.visible = play
	gallery_node.hide()
	room.show()
	for i in 5:
		pawns[i].show()
		pawns[i].position = flat(state.seats[i].pos)
		pawns[i].rotation = Vector3.ZERO
	wide_camera()
	ui.sync(state, selected, duties)
	room.sync(state)
	if play:
		ui.dismiss()
		open_log()
		radio.fx("call")
	else:
		ui.dismiss()
		front.home()
		set_deck_visible(false)
	refresh_cast(0.)


func flat(v: Vector2i) -> Vector3:
	return Vector3(v.x * .01, .065, v.y * .01)


func set_deck_visible(visible_: bool) -> void:
	room.visible = visible_
	for pawn in pawns:
		pawn.visible = visible_


func wide_camera() -> void:
	camera.fov = 43
	camera.position = Vector3(0, 3.77, 10.9)
	camera.look_at(Vector3(0, 1.26, -.60))


func menu_command(cmd: String) -> void:
	match cmd:
		"story":
			begin_story()
		"title":
			new_flight(false)
		"start":
			difficulty = 0
			new_flight(true)
		"storm":
			difficulty = 1
			new_flight(true)
		"gallery":
			set_gallery(true)
		"help":
			set_deck_visible(true)
			front.leave()
			ui.show()
			show_help()
		"recorder":
			show_recorder()
		"display_sync":
			sync_display = not sync_display
			apply_display_settings(true)
			show_help()
		"motion":
			reduced_motion = not reduced_motion
			apply_display_settings(true)
			show_help()
		"back":
			help_open = false
			if state.ending != "":
				end_menu()
			elif started:
				ui.dismiss()
			else:
				new_flight(false)
		"again":
			run_seed += 1
			new_flight(true)


func show_help() -> void:
	help_open = true
	var instructions := PackedStringArray(
		[
			"NELL   WASD move · E latch · Space cover · F towline · R fetch/stow\nTab partner · Q offer / accept · T counter · X break · Z duty",
			"RAFI   Arrows move · Enter latch · / cover · . kickplate · , fetch/stow\n] partner · P offer / accept · O counter · I break · [ duty",
			"CONTROLLERS   Left stick moves · A latch · RT cover · RB tool · X reel · Y deal · LB partner · B break. One pad pilots Rafi. Two pads pilot Nell and Rafi.",
			"Stand in a lit pad to latch it. Get three CEILING votes, catch the pod, then bring three votes and a catcher to HATCH. M mutes audio and B reduces background motion."
		]
	)
	var options := {
		"motion": "Dock motion · reduced" if reduced_motion else "Dock motion · full",
		"display_sync": "VSync · on" if sync_display else "VSync · off",
		"back": "Back"
	}
	ui.show_menu("Flight controls", "\n\n".join(instructions), options)


func apply_display_settings(save_choice: bool = false) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if sync_display else DisplayServer.VSYNC_DISABLED
		)
	room.life.reduced = reduced_motion
	front.title_paint.set_shader_parameter("strength", 0.0 if reduced_motion else 1.0)
	if save_choice:
		var settings := ConfigFile.new()
		settings.set_value("scene", "reduced_motion", reduced_motion)
		settings.set_value("scene", "sync_display", sync_display)
		settings.save("user://deck.cfg")


func begin_story() -> void:
	difficulty = 0
	new_flight(false)
	set_deck_visible(true)
	front.leave()
	ui.hide()
	radio.fx("call")
	enter_shot(0)


func enter_shot(index: int) -> void:
	story_stage = index
	shot_clock = 0
	if index >= OPENING.size():
		start_lesson()
		return
	var entry: Array = OPENING[index]
	front.dialogue(
		entry[0],
		entry[1],
		"Space  next shot     ·     Enter  deck induction     ·     Esc  start the rescue"
	)
	if entry[2] != "":
		radio.story_voice(entry[2])
	var aim: Vector3
	match index:
		0:
			wide_camera()
			story_base = camera.position
			return
		1:
			aim = flat(state.seats[2].pos) + Vector3(0, .90, 0)
			story_base = aim + Vector3(.71, .35, 2.28)
		2:
			aim = flat(state.seats[3].pos) + Vector3(0, 1.49, 0)
			story_base = aim + Vector3(-.65, .20, 2.28)
		_:
			aim = flat(state.seats[4].pos) + Vector3(0, 1.34, 0)
			story_base = aim + Vector3(.90, .23, 2.42)
	camera.fov = 39
	camera.position = story_base
	camera.look_at(aim)


func start_lesson() -> void:
	story_stage = 4
	shot_clock = 0
	lesson_message = ""
	state = Sim.new(run_seed, false)
	state.phase = 1
	state.gravity = 2
	state.hatch_at = 0
	state.seats[0].pos = Sim.PADS[0] + Vector2i(38, 45)
	state.seats[1].pos = Sim.PADS[2] + Vector2i(-38, 45)
	state.start_leg(2)
	state.flight.assigned = 1
	state.flight.end = 510
	wide_camera()
	room.practice = true
	room.sync(state)
	refresh_cast(0.)
	update_lesson_copy()


func update_lesson_copy() -> void:
	var line: String
	if not state.dwell.is_empty():
		line = "The buoy is in Rafi’s cradle. Keep the plate planted."
	elif state.flight.is_empty():
		line = "Resetting the buoy for another pass."
	elif not state.flight.slow:
		line = "Nell, pay out the towline. Press F near the left pad."
	elif not state.flight.banked:
		line = "Rafi, raise the kickplate. Press period (.) at the right pad."
	else:
		line = "Follow the line. The kickplate will receive the buoy."
	if line != lesson_message:
		lesson_message = line
		front.dialogue(
			"DECK INDUCTION  /  PRACTICE BUOY",
			line,
			"Use each player’s right bumper on controllers.     ·     Enter  launch the rescue"
		)


func story_controls(e: InputEvent) -> void:
	if (
		e is InputEventJoypadButton
		and e.pressed
		and e.button_index == JOY_BUTTON_A
		and story_stage < 4
	):
		enter_shot(story_stage + 1)
		return
	if e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_START:
		if story_stage < 4:
			start_lesson()
		else:
			new_flight(true)
		return
	if (
		e is InputEventJoypadButton
		and e.pressed
		and story_stage == 4
		and e.button_index == JOY_BUTTON_RIGHT_SHOULDER
	):
		var pilot := pad_seat(e.device)
		if pilot >= 0:
			state.human_action(pilot, "power")
			update_lesson_copy()
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.physical_keycode:
		KEY_ESCAPE:
			new_flight(true)
		KEY_ENTER, KEY_KP_ENTER:
			if story_stage < 4:
				start_lesson()
			else:
				new_flight(true)
		KEY_SPACE:
			if story_stage < 4:
				enter_shot(story_stage + 1)
		KEY_F:
			if story_stage == 4:
				state.human_action(0, "power")
				update_lesson_copy()
		KEY_PERIOD:
			if story_stage == 4:
				state.human_action(1, "power")
				update_lesson_copy()


func show_recorder() -> void:
	help_open = true
	var lines := PackedStringArray()
	for n in range(maxi(0, state.grades.size() - 6), state.grades.size()):
		var g: Dictionary = state.grades[n]
		lines.append(
			(
				"%05d   %s · %s    %.2f   %s"
				% [
					g.tick,
					Sim.NAMES[g.actor],
					g.get("action", "catch"),
					g.points / 100.,
					"PASS" if g["pass"] else "FAILED"
				]
			)
		)
	if lines.is_empty():
		lines.append("The first eligible action is still open.")
	for flip in state.causal_flips:
		if flip.released_reel:
			var who := PackedStringArray()
			for i in flip.voters:
				who.append(Sim.NAMES[i])
			lines.append(
				(
					"\nReel released by "
					+ ", ".join(who)
					+ ". Latch events "
					+ str(flip.causes)
					+ (". Human inputs idle." if flip.hands_off else ".")
				)
			)
	var model_summary := "Bruin · waiting for a checked local flight prefix."
	var path := "user://verified-responses.json"
	if FileAccess.file_exists(path):
		var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if report is Dictionary and report.get("history") is Dictionary:
			var history: Dictionary = report.history
			model_summary = (
				"Bruin · %d / %d local reactions passed in full."
				% [int(history.get("full", 0)), int(history.get("resolved", 0))]
			)
	lines.append("\n" + model_summary)
	ui.show_menu("Flight recorder", "\n".join(lines), {"back": "Return"})


func set_gallery(on: bool) -> void:
	in_gallery = on
	dragging = false
	gallery_node.visible = on
	room.visible = not on
	for p in pawns:
		p.visible = not on
	if on:
		front.leave()
		ui.show()
		ui.dismiss()
		show_cast()
	else:
		wide_camera()
		ui.sync(state, selected, duties)
		if not started:
			new_flight(false)
		elif state.ending != "":
			end_menu()
		else:
			ui.dismiss()


func show_cast() -> void:
	for i in 5:
		cast[i].visible = (i == gallery_index)
	var actor_height: float = [1.61, 1.69, .91, 1.69, 1.49][gallery_index]
	var focus := Vector3(135, actor_height if zoom == 1 else 1.0, 0)
	var distance: float = (1.1 if gallery_index < 2 else 1.36) if zoom == 1 else 3.65
	if zoom == 2:
		distance = 5.0
	camera.fov = 39
	camera.position = (
		focus + distance * Vector3(sin(orbit) * cos(pitch), sin(pitch), cos(orbit) * cos(pitch))
	)
	camera.look_at(focus)
	ui.gallery(Sim.NAMES[gallery_index], MODES[expression], orbit)


func _unhandled_input(event: InputEvent) -> void:
	if capture != "" or film != "" or benchmark != "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			reduced_motion = not reduced_motion
			apply_display_settings(true)
			if help_open:
				show_help()
			return
		if event.physical_keycode == KEY_M:
			radio.toggle()
			return
	if story_stage >= 0:
		story_controls(event)
		return
	if front.active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				front.home()
			elif event.physical_keycode == KEY_SPACE and front.page == "title":
				begin_story()
		return
	if event is InputEventMouseButton and in_gallery:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = posmod(zoom + 1, 3)
			show_cast()
	elif event is InputEventMouseMotion and in_gallery and dragging:
		orbit -= event.relative.x * .009
		pitch = clampf(pitch + event.relative.y * .006, -.22, 1.17)
		show_cast()
	if (
		event is InputEventJoypadButton
		and event.pressed
		and started
		and not ui.menu.visible
		and not in_gallery
	):
		var who := pad_seat(event.device)
		if who < 0:
			return
		match event.button_index:
			JOY_BUTTON_A:
				state.human_action(who, "vote")
			JOY_BUTTON_X:
				state.human_action(who, "reel")
			JOY_BUTTON_Y:
				deal(who)
			JOY_BUTTON_B:
				state.human_action(who, "break")
			JOY_BUTTON_RIGHT_SHOULDER:
				state.human_action(who, "power")
			JOY_BUTTON_LEFT_SHOULDER:
				cycle(who)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	if in_gallery:
		match k:
			KEY_G, KEY_ESCAPE:
				set_gallery(false)
				return
			KEY_LEFT:
				gallery_index = posmod(gallery_index - 1, 5)
			KEY_RIGHT:
				gallery_index = posmod(gallery_index + 1, 5)
			KEY_UP:
				expression = posmod(expression + 1, MODES.size())
			KEY_DOWN:
				expression = posmod(expression - 1, MODES.size())
			KEY_C:
				zoom = posmod(zoom + 1, 3)
			KEY_V:
				spin = not spin
		show_cast()
		return
	if k == KEY_G:
		set_gallery(true)
		return
	if k == KEY_F2:
		if help_open:
			menu_command("back")
		else:
			show_recorder()
		return
	if k == KEY_F1:
		if help_open:
			menu_command("back")
		else:
			show_help()
		return
	if ui.menu.visible:
		if k == KEY_ESCAPE and help_open:
			menu_command("back")
		elif k in [KEY_SPACE, KEY_ENTER] and not help_open:
			menu_command("again" if state.ending != "" else "start")
		return
	match k:
		KEY_E:
			state.human_action(0, "vote")
		KEY_ENTER, KEY_KP_ENTER:
			state.human_action(1, "vote")
		KEY_SPACE:
			state.human_action(0, "cover")
		KEY_SLASH:
			state.human_action(1, "cover")
		KEY_F:
			state.human_action(0, "power")
		KEY_PERIOD:
			state.human_action(1, "power")
		KEY_R:
			state.human_action(0, "reel")
		KEY_COMMA:
			state.human_action(1, "reel")
		KEY_TAB:
			cycle(0)
		KEY_BRACKETRIGHT:
			cycle(1)
		KEY_Q:
			deal(0)
		KEY_P:
			deal(1)
		KEY_T:
			state.human_action(0, "counter")
		KEY_O:
			state.human_action(1, "counter")
		KEY_X:
			state.human_action(0, "break")
		KEY_I:
			state.human_action(1, "break")
		KEY_Z:
			duties[0] = JOBS[(JOBS.find(duties[0]) + 1) % 3]
		KEY_BRACKETLEFT:
			duties[1] = JOBS[(JOBS.find(duties[1]) + 1) % 3]
		KEY_L:
			ui.ledger_on = not ui.ledger_on
		KEY_ESCAPE:
			show_help()


func pad_seat(id: int) -> int:
	var devices := Input.get_connected_joypads()
	if devices.size() == 1:
		return 1 if devices[0] == id else -1
	var rank := devices.find(id)
	return rank if rank < 2 else -1


func cycle(i: int) -> void:
	selected[i] = (selected[i] + 1) % 5
	if selected[i] == i:
		selected[i] = (selected[i] + 1) % 5


func deal(i: int) -> void:
	var accept := false
	for o in state.social.offers.values():
		if (o.provider == i and o.status == "offered") or (o.buyer == i and o.status == "counter"):
			accept = true
	if accept:
		state.human_action(i, "agree")
	else:
		state.human_action(i, "offer", selected[i], duties[i])


func axis(a: Key, b: Key) -> int:
	return int(Input.is_physical_key_pressed(b)) - int(Input.is_physical_key_pressed(a))


func _physics_process(_dt: float) -> void:
	if story_stage == 4 and film == "" and capture == "":
		state.input_move(0, Vector2i(axis(KEY_A, KEY_D), axis(KEY_W, KEY_S)))
		state.input_move(1, Vector2i(axis(KEY_LEFT, KEY_RIGHT), axis(KEY_UP, KEY_DOWN)))
		state.step(false)
		update_lesson_copy()
		if state.ending != "" and state.last_catch.get("pass", false):
			new_flight(true)
		elif state.flight.is_empty() and state.dwell.is_empty():
			start_lesson()
		return
	if not started or in_gallery or help_open or state.ending != "" or capture != "" or film != "":
		return
	var movement := [
		Vector2i(axis(KEY_A, KEY_D), axis(KEY_W, KEY_S)),
		Vector2i(axis(KEY_LEFT, KEY_RIGHT), axis(KEY_UP, KEY_DOWN))
	]
	for pad in Input.get_connected_joypads():
		var seat := pad_seat(pad)
		if seat < 0:
			continue
		var dx := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var dy := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		if absf(dx) > .25:
			movement[seat].x = signi(roundi(dx * 8.))
		if absf(dy) > .25:
			movement[seat].y = signi(roundi(dy * 8.))
		var pressed := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > .65
		if pressed and not trigger_down.get(pad, false):
			state.human_action(seat, "cover")
		trigger_down[pad] = pressed
	if benchmark != "":
		for i in 2:
			Partners.drive_partner(state, i, 2 + i)
	else:
		for i in 2:
			state.input_move(i, movement[i])
	state.step()
	for n in range(event_cursor, state.events.size()):
		var ev: Dictionary = state.events[n]
		if ev.kind in ["latch", "gravity", "contact", "end"]:
			radio.fx("herd" if ev.kind == "end" and state.reel == 5 else ev.kind)
	if state.tick % 60 == 0 or state.ending != "":
		flush_log()
	else:
		event_cursor = state.events.size()
	if state.ending != "":
		end_menu()
		close_log()


func _process(dt: float) -> void:
	elapsed += dt
	if state == null:
		return
	if film != "" or capture != "":
		return
	if front.active:
		front.title_paint.set_shader_parameter("seconds", elapsed)
		return
	if not in_gallery:
		room.animate_dock(dt, state)
	if story_stage >= 0:
		refresh_cast(dt)
		room.sync(state)
		if story_stage < 4 and film == "" and capture == "":
			shot_clock += dt
			camera.position = (
				story_base + Vector3(.07 * sin(shot_clock * .48), 0, -.028 * shot_clock)
			)
			if shot_clock >= float(OPENING[story_stage][3]):
				enter_shot(story_stage + 1)
		return
	if benchmark != "":
		var now := Time.get_ticks_usec()
		frame_count += 1
		if frame_count > 120 and frame_previous > 0:
			frame_times.append((now - frame_previous) / 1000.)
			cpu_physics.append(1000. * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
			draw_counts.append(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			)
		frame_previous = now
		if frame_count >= 1500 or (state.ending != "" and frame_count > 120):
			frame_times.sort()
			cpu_physics.sort()
			draw_counts.sort()
			var file := FileAccess.open(benchmark, FileAccess.WRITE)
			var d := {
				"frames": frame_times.size(),
				"p95_physics_ms": cpu_physics[int(cpu_physics.size() * .95)],
				"median_draw_calls": draw_counts[int(draw_counts.size() * .5)],
				"p50_ms": frame_times[int(frame_times.size() * .50)],
				"p95_ms": frame_times[int(frame_times.size() * .95)],
				"p99_ms": frame_times[int(frame_times.size() * .99)],
				"resolution": [int(get_viewport().size.x), int(get_viewport().size.y)],
				"adapter": RenderingServer.get_video_adapter_name(),
				"tick": state.tick,
				"mode": "ring_storm" if difficulty == 1 else "first_rescue",
				"seed": run_seed
			}
			file.store_string(JSON.stringify(d, "  "))
			file.close()
			benchmark = ""
			get_tree().quit()
	if in_gallery:
		if spin:
			orbit += dt * .53
			show_cast()
		cast[gallery_index].express(MODES[expression], elapsed, MODES[expression] == "Walk")
		return
	refresh_cast(dt)
	room.sync(state)
	if started:
		if state.tick % 5 == 0:
			ui.sync(state, selected, duties)
		radio.update(state)


func refresh_cast(dt: float) -> void:
	for i in 5:
		var s: Dictionary = state.seats[i]
		var p = pawns[i]
		p.position = p.position.lerp(flat(s.pos), minf(1., dt * 33.)) if dt > 0 else flat(s.pos)
		var v: Vector2i = s.motion
		var walking := v != Vector2i.ZERO and started and not help_open
		if walking:
			p.rotation.y = lerp_angle(
				p.rotation.y, atan2(float(v.x), float(v.y)), minf(1., dt * 12.)
			)
		var pose: String = s.pose if state.tick < s.pose_until else "Idle"
		p.express(pose, elapsed, walking)


var written := 0


func open_log() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://flights"))
	var id := "%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), run_seed]
	log_path = "user://flights/" + id + ".jsonl"
	recorder = Recorder.new()
	written = 0
	recorder.begin(
		log_path,
		{
			"kind": "header",
			"version": 2,
			"ruleset": Sim.RULESET,
			"run": id,
			"seed": run_seed,
			"difficulty": difficulty,
			"checkpoint": initial_checkpoint,
			"origin": "local_play" if local_play else "diagnostic",
			"physics_hz": 60
		}
	)


func flush_log() -> void:
	event_cursor = state.events.size()
	if recorder == null:
		return
	recorder.append(state.events.slice(written))
	written = state.events.size()


func close_log() -> void:
	if recorder != null:
		flush_log()
		recorder.finish(
			{
				"kind": "checkpoint",
				"tick": state.tick,
				"digest": state.digest(),
				"ending": state.ending
			}
		)
		recorder = null


func _exit_tree() -> void:
	close_log()


func end_menu() -> void:
	var full := 0
	for g in state.grades:
		if g["pass"]:
			full += 1
	(
		ui
		. show_menu(
			state.ending,
			(
				"Verified actions   %d / %d passed in full.  Shell integrity   %d / %d.\nThe flight recorder saved the decisions, promises, inputs and physical outcomes."
				% [full, state.grades.size(), state.hull, 2 if difficulty else 3]
			),
			{"again": "Next flight", "title": "Title", "recorder": "Recorder"}
		)
	)


func snap(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func camera_test() -> void:
	if capture == "":
		await film_test()
		return
	DirAccess.make_dir_recursive_absolute(capture)
	await snap(capture + "/title.png")
	front.modes()
	await snap(capture + "/modes.png")
	begin_story()
	enter_shot(1)
	await snap(capture + "/story.png")
	start_lesson()
	await snap(capture + "/induction.png")
	new_flight(true)
	room.animate_dock(0., state)
	ui.sync(state, selected, duties)
	await snap(capture + "/bay.png")
	for n in 300:
		room.animate_dock(1. / 60., state)
	await snap(capture + "/bay-later.png")
	difficulty = 1
	new_flight(true)
	room.animate_dock(1. / 60., state)
	await snap(capture + "/ring-storm.png")
	difficulty = 0
	new_flight(false)
	set_gallery(true)
	for i in 5:
		gallery_index = i
		spin = false
		for view in 4:
			expression = 0
			zoom = 0
			pitch = .11
			orbit = view * PI * .5
			show_cast()
			cast[i].express("Idle", 1.1)
			await snap(capture + "/%s-view-%d.png" % [Crew.FILES[i], view])
		for mode in 4:
			expression = mode
			zoom = 1
			orbit = .23
			pitch = .08
			show_cast()
			cast[i].express(MODES[mode], 1.1)
			if cast[i].anim:
				cast[i].anim.advance(.4)
			await snap(capture + "/%s-face-%d.png" % [Crew.FILES[i], mode])
	if film != "":
		await film_test()
	else:
		get_tree().quit()


func film_frame(n: int) -> void:
	elapsed = float(n) / 24.
	if not in_gallery:
		room.animate_dock(1. / 24., state)
		front.title_paint.set_shader_parameter("seconds", room.life.seconds)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(film + "/frame%04d.jpg" % n, .92)


func film_test() -> void:
	DirAccess.make_dir_recursive_absolute(film)
	if in_gallery:
		set_gallery(false)
	new_flight(false)
	var n := 0
	for frame in 40:
		await film_frame(n)
		n += 1
	begin_story()
	for shot in 4:
		enter_shot(shot)
		var frames: int = [53, 90, 120, 90][shot]
		for frame in frames:
			camera.position = story_base + Vector3(.05 * sin(frame / 48.), 0, -.0008 * frame)
			await film_frame(n)
			n += 1
	start_lesson()
	for j in 93:
		if j == 11:
			state.human_action(0, "power")
		if j == 32:
			state.human_action(1, "power")
		for step_ in 7:
			state.step(false)
		update_lesson_copy()
		room.sync(state)
		refresh_cast(1.)
		await film_frame(n)
		n += 1
	new_flight(true)
	ui.dismiss()
	for j in 445:
		# Ten seconds at native speed, then compress the wait for the hatch window.
		var stride: int = (2 + j % 2) if j < 240 else 9
		for k in stride:
			if state.ending != "":
				break
			if state.phase > 0:
				Partners.drive_partner(state, 0, 2)
				Partners.drive_partner(state, 1, 3)
			state.step()
		room.sync(state)
		refresh_cast(1.)
		ui.sync(state, selected, duties)
		await film_frame(n)
		n += 1
	flush_log()
	close_log()
	difficulty = 1
	new_flight(true)
	for frame in 60:
		for tick in 2 + frame % 2:
			state.step()
		room.sync(state)
		refresh_cast(1.)
		ui.sync(state, selected, duties)
		await film_frame(n)
		n += 1
	set_gallery(true)
	for i in 5:
		gallery_index = i
		spin = false
		for j in 74:
			zoom = 0 if j < 48 else 1
			orbit = TAU * j / 48. if j < 48 else .21
			pitch = .12 if j < 48 else .08
			expression = 0 if j < 48 else 1 if j < 57 else 2 if j < 65 else 3
			show_cast()
			cast[i].express(MODES[expression], j / 24.)
			await film_frame(n)
			n += 1
	get_tree().quit()
