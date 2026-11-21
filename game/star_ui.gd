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
		"Choose your crew",
		"LAST LIGHT   /   NIGHT SHIFT",
		"Rivals pits both pilots against all three machines. In Open Crews, a machine can change jerseys during play.",
		{"rivals": "Rivals   ·   2 vs 3", "crews": "Open Crews", "replay": "Meet the five again"}
	)


func pick(cmd: String) -> void:
	chosen.emit(cmd)


func briefing(crews: bool) -> void:
	page = "brief"
	menu(
		"Light the gold ring",
		"OPEN CREWS" if crews else "RIVALS",
		(
			"Carry the star toward the GOLD ring on the right. Shoot when it lights up. First to three wins.\nNell  ·  WASD move, E shoot, F pass, Shift dash/steal.     Rafi  ·  Arrows move, Enter shoot, Slash pass, Period dash/steal."
			+ (
				"\nQ (Nell) or P (Rafi) offers a nearby robot a jersey. Ask your ally again to break the deal."
				if crews
				else ""
			)
		),
		{"play": "Take the court", "select": "Change mode"}
	)


func match_view() -> void:
	leave()
	match_hud.show()


func record(words: String) -> void:
	history.push_front(words)
	if history.size() > 6:
		history.pop_back()
	ledger.text = "CREW LEDGER\n" + "\n".join(history)


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
