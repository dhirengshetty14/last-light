extends SceneTree

const Game = preload("res://game/flight.tscn")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func keyboard(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func _initialize() -> void:
	call_deferred("exercise")


func exercise() -> void:
	var game = Game.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	check(
		game.front.active and game.front.page == "title", "launch must open the illustrated title"
	)
	game.front.pick("modes")
	check(game.front.page == "modes", "mode selection unavailable")
	game.front.pick("storm")
	check(game.started and game.state.difficulty == 1, "storm did not launch")
	game.menu_command("title")
	game.front.pick("gallery")
	for i in 5:
		game.gallery_index = i
		game.show_cast()
		check(game.cast[i].visible, "cast selection missing")
		if i < 2:
			check(
				game.cast[i].shapes.size() > 8 and game.cast[i].anim.has_animation("Walk"),
				"human face or rig missing"
			)
		else:
			check(game.cast[i].controls.size() >= 5, "machine articulation missing")
	check(
		(
			game.cast[2].optics.size() > 20
			and game.cast[3].iris_lenses.size() == 2
			and game.cast[4].optics.size() == 2
		),
		"agents missing expressive optics"
	)
	game.set_gallery(false)
	game.front.first.pressed.emit()
	check(game.story_stage == 0, "Begin story button did not open the introduction")
	for i in range(1, 4):
		game.story_controls(keyboard(KEY_SPACE))
		check(game.story_stage == i and game.front.story_root.visible, "story shot missing")
		check(game.radio.cache.has(game.OPENING[i][2]), "missing recorded character voice")
	game.story_controls(keyboard(KEY_ENTER))
	check(game.room.practice and not game.started, "intro did not hand off to deck induction")
	game.story_controls(keyboard(KEY_F))
	check(game.state.flight.slow, "Nell's tutorial power did not engage")
	game.story_controls(keyboard(KEY_PERIOD))
	check(game.state.flight.banked, "Rafi's tutorial power did not engage")
	for tick in 610:
		game._physics_process(1.0 / 60)
		if game.started:
			break
	check(
		game.started and game.story_stage == -1 and not game.room.practice,
		"successful induction did not start a new flight"
	)
	check(
		not game.state.human_acted and game.state.tick == 0,
		"tutorial contaminated mission attribution"
	)
	var sim = game.state
	var dock = game.room.life
	var before: String = sim.digest()
	dock.reduced = false
	dock.update(0.0, sim, false)
	var original: Vector3 = dock.trolley.position
	var tender_origin: Vector3 = dock.tugs[0].position
	for frame in 300:
		game.room.animate_dock(1.0 / 60, sim)
	check(
		(
			original.distance_to(dock.trolley.position) > 1.0
			and tender_origin.distance_to(dock.tugs[0].position) > 0.5
		),
		"distant cargo or orbital traffic stayed static"
	)
	check(sim.digest() == before, "presentation modified authoritative physics")
	dock.reduced = true
	original = dock.trolley.position
	for frame in 90:
		game.room.animate_dock(1.0 / 60, sim)
	check(
		original.is_equal_approx(dock.trolley.position),
		"reduced motion failed to freeze decoration"
	)
	while sim.tick < sim.hatch_at:
		sim.step()
	for frame in 90:
		game.room.animate_dock(1.0 / 60, sim)
	check(dock.hatch_fraction >= 0.99, "functional hatch failed to open with reduced motion")
	check(
		not sim.causal_flips.is_empty() and sim.causal_flips[0].hands_off,
		"idle players lost agent-only event"
	)
	game.close_log()
	var log_path := str(game.log_path)
	game.queue_free()
	await process_frame
	await process_frame
	print(
		"Entry and dock checks failed: ",
		failures,
		"  |  recorded flight: ",
		ProjectSettings.globalize_path(log_path)
	)
	quit(1 if failures else 0)
