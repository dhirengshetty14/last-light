extends "res://game/front_end.gd"
const GOLD_INK = Color("#ffe29e")
const PALE = Color("#faf1df")
const AQUA = Color("#90e6e6")
var match_hud := Control.new()
var score: Label
var objective: Label
var feed: Label
var controls_line: Label
var ledger := RichTextLabel.new()
signal key_changed(value: String)
var key_set := false
var key_dialog := ConfirmationDialog.new()
var key_input := LineEdit.new()
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
	board.size = Vector2(530, 47)
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(.025, .059, .078, .92)
	dark.border_width_left = 4
	dark.border_color = GOLD_INK
	dark.set_corner_radius_all(3)
	board.add_theme_stylebox_override("panel", dark)
	match_hud.add_child(board)
	score = place(match_hud, 29, 24, 22, PALE)
	score.add_theme_font_override("font", INSTRUMENT_FACE)
	objective = place(match_hud, 23, 69, 18, GOLD_INK)
	feed = place(match_hud, 26, -94, 21, PALE, true)
	controls_line = place(match_hud, 26, -45, 15, Color("#d3e7e5"))
	match_hud.add_child(ledger)
	ledger.position = Vector2(24, 110)
	ledger.size.x = 550
	ledger.anchor_bottom = 1.0
	ledger.offset_bottom = -105
	ledger.add_theme_font_override("normal_font", BODY_FACE)
	ledger.add_theme_font_size_override("normal_font_size", 16)
	ledger.add_theme_color_override("default_color", AQUA)
	ledger.focus_mode = Control.FOCUS_NONE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(.023, .049, .064, .95)
	paper.set_corner_radius_all(4)
	paper.content_margin_left = 15
	paper.content_margin_right = 15
	paper.content_margin_top = 10
	paper.content_margin_bottom = 10
	ledger.add_theme_stylebox_override("normal", paper)
	ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.hide()
	match_hud.hide()
	add_child(key_dialog)
	key_dialog.title = "Court radio · Gemini"
	var radio_theme := Theme.new()
	radio_theme.default_font = BODY_FACE
	radio_theme.set_font("font", "Button", DISPLAY_FACE)
	radio_theme.set_font("title_font", "Window", DISPLAY_FACE)
	key_dialog.theme = radio_theme
	key_dialog.exclusive = true
	key_dialog.ok_button_text = "Use for this session"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	key_dialog.add_child(box)
	var hint := ink_label(
		"During matches each robot sends its own scout report to Google. Requests use your Gemini API quota. The key stays in memory until you quit.",
		18,
		PALE
	)
	hint.custom_minimum_size.x = 450
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	key_input.placeholder_text = "Gemini API key"
	key_input.secret = true
	key_input.max_length = 512
	box.add_child(key_input)
	key_dialog.get_ok_button().disabled = true
	key_input.text_changed.connect(
		func(value: String): key_dialog.get_ok_button().disabled = value.strip_edges().is_empty()
	)
	key_dialog.confirmed.connect(
		func():
			key_changed.emit(key_input.text.strip_edges())
			key_input.clear()
			modes()
	)
	key_dialog.canceled.connect(key_input.clear)
	key_dialog.add_button("Use local agents", true, "local")
	key_dialog.custom_action.connect(
		func(action: StringName):
			if action == "local":
				key_changed.emit("")
				key_input.clear()
				key_dialog.hide()
				modes()
	)


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
		{
			"rivals": "Rivals   ·   2 vs 3",
			"crews": "Open Crews",
			"replay": "Meet the five again",
			"gemini": "Gemini settings" if key_set else "Connect Gemini"
		}
	)


func pick(cmd: String) -> void:
	if cmd == "gemini":
		key_input.clear()
		key_dialog.get_ok_button().disabled = true
		key_dialog.popup_centered(Vector2i(520, 210))
		key_input.grab_focus()
		return
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
		if actor.model_status != "Local policy":
			lines.append(actor.model_status)
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
	var words := "\n".join(lines)
	if ledger.text != words:
		ledger.text = words


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
