extends "res://game/front_end.gd"
const GOLD_INK = Color("#ffe29e")
const PALE = Color("#faf1df")
const AQUA = Color("#90e6e6")
var match_hud := Control.new()
var score: Label
var objective: Label
var feed: Label
var controls_line: Label
var ledger: Label
var history: Array[String] = []


func _ready() -> void:
	super._ready()
	hero.hide()
	full(match_hud, self)
	match_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade(match_hud, "story")
	var board := Panel.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.position = Vector2(14, 17)
	board.size = Vector2(415, 47)
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(.025, .059, .078, .92)
	dark.border_width_left = 4
	dark.border_color = GOLD_INK
	dark.set_corner_radius_all(3)
	board.add_theme_stylebox_override("panel", dark)
	match_hud.add_child(board)
	score = place(match_hud, 29, 24, 24, PALE)
	objective = place(match_hud, 23, 69, 18, GOLD_INK)
	feed = place(match_hud, 26, -94, 21, PALE, true)
	controls_line = place(match_hud, 26, -45, 15, Color("#d3e7e5"))
	ledger = place(match_hud, 24, 110, 16, AQUA)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(.023, .049, .064, .95)
	paper.set_corner_radius_all(4)
	paper.content_margin_left = 15
	paper.content_margin_right = 15
	paper.content_margin_top = 10
	paper.content_margin_bottom = 10
	ledger.add_theme_stylebox_override("normal", paper)
	ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.size.x = 550
	ledger.hide()
	match_hud.hide()


func place(
	parent: Control, x: float, y: float, size_px: int, color: Color, serif: bool = false
) -> Label:
	var l := ink_label("", size_px, color, serif)
	parent.add_child(l)
	if y < 0:
		l.anchor_top = 1
		l.anchor_bottom = 1
	l.position.x = x
	l.offset_top = y
	l.offset_bottom = y + 34
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color("#18242b"))
	return l


func home() -> void:
	active = true
	root.show()
	story_root.hide()
	hero.hide()
	page = "title"
	where_label.text = "SATURN   /   LAMPLIGHT HARBOR"
	heading.text = "Last Light"
	copy.text = "Every night the dock goes dark. Two crews play for the right to light the harbor."
	set_controls({"next": "Meet the five", "skip": "Choose mode"})


func menu(title: String, kicker: String, description: String, buttons: Dictionary) -> void:
	active = true
	root.show()
	story_root.hide()
	match_hud.hide()
	heading.text = title
	where_label.text = kicker
	copy.text = description
	set_controls(buttons)


func modes() -> void:
	page = "modes"
	menu(
		"Choose a game mode",
		"LAST LIGHT   /   NIGHT SHIFT",
		"Rivals keeps all three robots on Blue. In Open Crews, ask a robot to join Gold or take on all three together. Both modes play to three goals.",
		{"rivals": "Rivals   ·   2 vs 3", "crews": "Open Crews", "replay": "Meet the five again"}
	)


func pick(cmd: String) -> void:
	chosen.emit(cmd)


func pilots(crews: bool) -> void:
	page = "pilots"
	menu(
		"Choose your pilots",
		"OPEN CREWS" if crews else "RIVALS",
		"Nell has the longest dash. Rafi runs faster and catches passes from farther away. Choose who takes the WASD controls. The other pilot uses the arrow keys.",
		{"nell": "P1 Nell  ·  P2 Rafi", "rafi": "P1 Rafi  ·  P2 Nell", "select": "Change mode"}
	)


func briefing(crews: bool, names: Array) -> void:
	page = "brief"
	menu(
		"Light the gold ring",
		"OPEN CREWS" if crews else "RIVALS",
		(
			(
				"Carry the star toward the GOLD ring on the right. Shoot when it lights up. First to three wins.\nP1 %s  ·  WASD move, E shoot, F pass, Shift dash.     P2 %s  ·  Arrows move, Enter shoot, Slash pass, Period dash."
				% names
			)
			+ (
				"\nQ (P1) or P (P2) offers a nearby robot a jersey. Ask your ally again to break the deal."
				if crews
				else ""
			)
		),
		{"play": "Take the court", "pilots": "Change pilots", "select": "Change mode"}
	)


func match_view() -> void:
	leave()
	match_hud.show()


func record(words: String) -> void:
	history.push_front(words)
	if history.size() > 6:
		history.pop_back()


func show_plans(sim) -> void:
	var lines: Array[String] = ["ROBOT NOTEBOOKS"]
	for actor in sim.agents:
		var a: Array = actor.scouting[0]
		var b: Array = actor.scouting[1]
		lines.append("\n%s   ·   %s" % [sim.NAMES[actor.role], actor.GOALS[actor.role - 2]])
		lines.append(actor.last_plan if actor.last_plan != "" else "Watching the opening play.")
		if actor.plan_basis != "":
			lines.append(
				(
					"%s   ·   %d earlier attempts"
					% [actor.plan_basis.capitalize(), actor.prior_attempts]
				)
			)
		lines.append(
			(
				"Passes seen   Nell %d / Rafi %d     ·     %d decisions graded"
				% [a[1], b[1], actor.decisions_graded]
			)
		)
		for note in actor.last_deal:
			if note != "":
				lines.append(note)
	if not history.is_empty():
		lines.append("\nON THE COURT")
		lines.append_array(history.slice(0, 2))
	ledger.text = "\n".join(lines)


func results(gold: int, blue: int) -> void:
	var title := (
		"Gold lights the harbor"
		if gold > blue
		else ("Blue lights the harbor" if blue > gold else "Shared light")
	)
	menu(
		title,
		"FINAL WHISTLE   /   %d GOLD    %d BLUE" % [gold, blue],
		"Both crews carry what they learned into the next shift.",
		{"again": "Rematch", "select": "Change mode", "replay": "Replay opening"}
	)


func pause_menu() -> void:
	menu(
		"Time out",
		"LAST LIGHT",
		"Pick up where you left off, or take a new crew onto the court.",
		{"resume": "Resume match", "select": "Change mode"}
	)
