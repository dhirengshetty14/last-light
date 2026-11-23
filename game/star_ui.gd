extends "res://game/front_end.gd"
const GOLD_INK = Color("#ffe29e")
const PALE = Color("#faf1df")
const AQUA = Color("#90e6e6")
var match_hud := Control.new()
var scores: Array[Label] = []
var crews_on_board: Array[Label] = []
var match_clock: Label
var final_card := PanelContainer.new()
var objective: Label
var feed: Label
var controls_line: Label
var ledger := RichTextLabel.new()
var history: Array[String] = []
var dash_labels: Array[Label] = []
var dash_meters: Array[ProgressBar] = []
var limit_label: Label
var radio := RichTextLabel.new()
var promises := RichTextLabel.new()
var spoken: Array[String] = []
## Each seat's two buttons, always on screen, with what a press will do right now.
var button_rows: Array = []


func _ready() -> void:
	super._ready()
	hero.hide()
	full(match_hud, self)
	match_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade(match_hud, "match")
	var board := Panel.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_hud.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	board.offset_left = -242
	board.offset_right = 242
	board.offset_top = 15
	board.offset_bottom = 83
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(.025, .059, .078, .92)
	dark.border_width_bottom = 2
	dark.border_color = GOLD_INK
	dark.set_corner_radius_all(3)
	board.add_theme_stylebox_override("panel", dark)
	for side in 2:
		var tint: Color = [GOLD_INK, AQUA][side]
		var x := 18 if side == 0 else 349
		var nameplate := place(board, x, 15, 21, tint, true)
		nameplate.custom_minimum_size.x = 111
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crews_on_board.append(nameplate)
		var tally := place(board, 143 if side == 0 else 303, 4, 42, tint, true)
		scores.append(tally)
	match_clock = place(board, 193, 3, 30, PALE)
	match_clock.custom_minimum_size.x = 99
	match_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_label = place(board, 177, 37, 14, PALE)
	limit_label.text = "MOST GOALS WINS"
	limit_label.custom_minimum_size.x = 132
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dash_panel := PanelContainer.new()
	match_hud.add_child(dash_panel)
	dash_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dash_panel.offset_left = -218
	dash_panel.offset_right = -15
	dash_panel.offset_top = 17
	var panel_style := dark.duplicate() as StyleBoxFlat
	panel_style.border_width_left = 0
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 7
	panel_style.content_margin_bottom = 7
	dash_panel.add_theme_stylebox_override("panel", panel_style)
	var rows := VBoxContainer.new()
	dash_panel.add_child(rows)
	for seat in 2:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := ink_label("", 15, PALE)
		label.custom_minimum_size.x = 95
		row.add_child(label)
		dash_labels.append(label)
		var meter := ProgressBar.new()
		meter.show_percentage = false
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.custom_minimum_size = Vector2(73, 5)
		meter.max_value = 1.
		meter.step = .01
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD_INK if seat == 0 else AQUA
		var track := StyleBoxFlat.new()
		track.bg_color = Color("#405155")
		meter.add_theme_stylebox_override("fill", fill)
		meter.add_theme_stylebox_override("background", track)
		row.add_child(meter)
		dash_meters.append(meter)
	objective = place(match_hud, 25, -128, 24, GOLD_INK, true)
	feed = place(match_hud, 26, -94, 21, PALE, true)
	controls_line = place(match_hud, 26, -22, 13, Color("#9fb4b3"))
	controls_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	controls_line.offset_top = -24
	controls_line.offset_left = -160
	controls_line.offset_right = 160
	controls_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for seat in 2:
		var bar := HBoxContainer.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_constant_override("separation", 9)
		match_hud.add_child(bar)
		bar.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_LEFT if seat == 0 else Control.PRESET_BOTTOM_RIGHT
		)
		bar.grow_horizontal = Control.GROW_DIRECTION_END if seat == 0 else Control.GROW_DIRECTION_BEGIN
		bar.offset_left = 26 if seat == 0 else -26
		bar.offset_right = bar.offset_left
		bar.offset_top = -66
		bar.offset_bottom = -30
		var who := ink_label("", 20, PALE, true)
		who.add_theme_constant_override("outline_size", 5)
		who.add_theme_color_override("font_outline_color", Color("#18242b"))
		bar.add_child(who)
		var row := {"who": who, "caps": [], "words": []}
		for n in 2:
			var cap := PanelContainer.new()
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var keycap := StyleBoxFlat.new()
			keycap.bg_color = Color("#f4ead2")
			keycap.border_color = Color("#10191d")
			keycap.set_border_width_all(2)
			keycap.border_width_bottom = 4
			keycap.set_corner_radius_all(6)
			keycap.content_margin_left = 9
			keycap.content_margin_right = 9
			keycap.content_margin_top = 1
			keycap.content_margin_bottom = 1
			cap.add_theme_stylebox_override("panel", keycap)
			var letter := ink_label("", 17, Color("#10191d"), true)
			cap.add_child(letter)
			bar.add_child(cap)
			var word := ink_label("", 22, PALE, true)
			word.add_theme_constant_override("outline_size", 6)
			word.add_theme_color_override("font_outline_color", Color("#18242b"))
			word.custom_minimum_size.x = 132
			bar.add_child(word)
			row.caps.append([cap, letter])
			row.words.append(word)
		button_rows.append(row)
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
	# The decision log stays on screen for the whole match. Tab still opens the full notebooks.
	for sheet in [radio, promises]:
		match_hud.add_child(sheet)
		sheet.bbcode_enabled = true
		sheet.scroll_active = false
		sheet.fit_content = true
		sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.focus_mode = Control.FOCUS_NONE
		sheet.add_theme_font_override("normal_font", BODY_FACE)
		sheet.add_theme_font_override("bold_font", DISPLAY_FACE)
		sheet.add_theme_font_size_override("normal_font_size", 15)
		sheet.add_theme_font_size_override("bold_font_size", 17)
		sheet.add_theme_color_override("default_color", PALE)
		var slip := paper.duplicate() as StyleBoxFlat
		slip.bg_color = Color(.023, .049, .064, .62)
		sheet.add_theme_stylebox_override("normal", slip)
		sheet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radio.offset_left = -372
	radio.offset_right = -15
	radio.offset_top = 96
	promises.position = Vector2(24, 17)
	promises.size.x = 348
	promises.hide()
	root.add_child(final_card)
	final_card.position = Vector2(49, 185)
	var card_style := dark.duplicate() as StyleBoxFlat
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		card_style.set_content_margin(side, 18)
	final_card.add_theme_stylebox_override("panel", card_style)
	final_card.hide()
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
	final_card.hide()
	active = true
	root.show()
	story_root.hide()
	hero.hide()
	page = "title"
	where_label.text = "SATURN   /   LAMPLIGHT HARBOR"
	heading.text = "Last Light"
	copy.text = "Every night the harbor goes dark, and the whales follow one light home. Tonight five dockhands play for who lights it."
	set_controls({"next": "Begin", "skip": "Choose mode"})


func menu(title: String, kicker: String, description: String, buttons: Dictionary) -> void:
	final_card.hide()
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
		"In Free Agents, Nell and Rafi captain rival crews. Each robot signs for a promise, walks out when it is broken, and can vote with the others to play for itself. Rivals pits both pilots against three robots. In Open Crews you recruit a rival mid-match.",
		{
			"free": "Free Agents",
			"rivals": "Rivals   ·   2 vs 3",
			"crews": "Open Crews",
			"replay": "Meet the five again"
		}
	)


func pick(cmd: String) -> void:
	chosen.emit(cmd)


func pilots(mode: String) -> void:
	page = "pilots"
	menu(
		"Choose your pilots",
		mode,
		"Nell has the longest dash and nobody can steal through it. Rafi scores from farther out. Choose who takes WASD, SPACE and F. The other pilot uses the arrow keys, ENTER and slash.",
		{"nell": "P1 Nell  ·  P2 Rafi", "rafi": "P1 Rafi  ·  P2 Nell", "select": "Change mode"}
	)


func briefing(mode: String, names: Array) -> void:
	page = "brief"
	var crews := mode == "OPEN CREWS"
	if mode == "FREE AGENTS":
		menu(
			"Keep your word",
			mode,
			(
				"Nell attacks the gold ring on the right. Rafi attacks the blue ring on the left. Most goals in four minutes wins. Every robot signs for a promise: Pip wants the next shot, Zip wants passes, Morrow wants a shot that comes off a pass. A promise only runs down while your crew holds the star. Break one and that robot walks out. If both captains break one, the robots vote on playing for themselves.\nTwo buttons each. P1 %s  ·  WASD to move, SPACE to shoot or dash, F to pass, pay a promise or make an offer.     P2 %s  ·  ARROWS, ENTER and slash do the same. The bars at the bottom say what each button will do. The ring under a player is their crew's colour. The turning dashed ring is Morrow's slow zone."
				% names
			),
			{"play": "Take the court", "pilots": "Change pilots", "select": "Change mode"}
		)
		return
	menu(
		"Light the gold ring",
		mode,
		(
			(
				"Split into two lanes. Pass to your partner, dodge a tackler, then shoot inside the gold arc on the right. First to three wins.\nTwo buttons each. P1 %s  ·  WASD to move, SPACE to shoot, dash or steal, F to pass.     P2 %s  ·  ARROWS, ENTER and slash do the same."
				% names
			)
			+ (
				"\nStand beside a robot and press F or slash to offer it a jersey. Passes go where you steer. Complete two passes in a row to recharge every teammate’s dash."
				if crews
				else ""
			)
		),
		{"play": "Take the court", "pilots": "Change pilots", "select": "Change mode"}
	)


func set_score(goals: Array, sides: Array, timer: String, target: String) -> void:
	crews_on_board[0].text = sides[0]
	crews_on_board[1].text = sides[1]
	scores[0].text = str(goals[0])
	scores[1].text = str(goals[1])
	match_clock.text = timer
	limit_label.text = target


## One seat's two buttons: the key on a cap, and beside it what pressing it will do now.
func show_buttons(seat: int, who: String, tint: Color, keys: Array, words: Array) -> void:
	var row: Dictionary = button_rows[seat]
	row.who.text = who.to_upper()
	row.who.add_theme_color_override("font_color", tint)
	for n in 2:
		row.caps[n][1].text = keys[n]
		var idle: bool = str(words[n]) == ""
		row.caps[n][0].modulate = Color(1, 1, 1, .38 if idle else 1.)
		row.words[n].text = str(words[n]).to_upper()
		row.words[n].add_theme_color_override(
			"font_color", GOLD_INK if str(words[n]) == "Shoot!" else PALE
		)


func show_dashes(sim, pilots: Array[int]) -> void:
	for seat in 2:
		var pilot := pilots[seat]
		dash_labels[seat].text = "%s   DASH" % sim.NAMES[pilot]
		dash_meters[seat].value = 1. - clampf(float(sim.cooldown[pilot] - sim.tick) / 86., 0., 1.)


func match_view() -> void:
	leave()
	match_hud.show()


func record(words: String, speaker: String = "", tint: Color = PALE) -> void:
	history.push_front(words)
	if history.size() > 6:
		history.pop_back()
	var line := words.replace("[", "(").replace("]", ")")
	if speaker != "" and line.begins_with(speaker + " "):
		# The speaker label already says who. Keep the log line short.
		line = line.trim_prefix(speaker + " ")
		line = line[0].to_upper() + line.substr(1)
	if speaker != "":
		line = "[b][color=#%s]%s[/color][/b]   %s" % [tint.to_html(false), speaker.to_upper(), line]
	spoken.push_front(line)
	if spoken.size() > 5:
		spoken.pop_back()
	radio.text = "[b][color=#b7cbc9]HARBOR RADIO[/color][/b]\n" + "\n".join(spoken)


func clear_log() -> void:
	history.clear()
	spoken.clear()
	radio.text = "[b][color=#b7cbc9]HARBOR RADIO[/color][/b]\nWaiting for the first call."
	promises.text = ""
	promises.hide()


## Open promises with who owes whom, the progress and the possession time left.
func show_promises(sim) -> void:
	promises.visible = sim.free_agents and not ledger.visible
	if not sim.free_agents:
		return
	var lines: Array[String] = []
	if sim.union:
		lines.append("[b][color=#b7cbc9]THE UNION[/color][/b]")
		lines.append("Pip, Morrow and Zip play for themselves.")
		lines.append("Nell and Rafi share the gold ring.")
	else:
		lines.append("[b][color=#b7cbc9]PROMISES[/color][/b]")
		var active := [false, false]
		for d in sim.deals:
			if d.state != "open":
				continue
			var tint: String = (GOLD_INK if d.human == 0 else AQUA).to_html(false)
			var pips := ""
			if d.kind == "feed":
				pips = "   " + "●".repeat(int(d.done)) + "○".repeat(int(d.need) - int(d.done))
			var clock := "%ds" % ceili(float(d.left) / 60.)
			if active[d.human]:
				clock = "next"
			active[d.human] = true
			lines.append(
				(
					"[b][color=#%s]%s[/color][/b]  owes  [b]%s[/b]\n%s%s   ·   %s"
					% [
						tint,
						sim.NAMES[d.human].to_upper(),
						sim.NAMES[d.robot].to_upper(),
						sim.words(d).capitalize(),
						pips,
						clock
					]
				)
			)
		if lines.size() == 1:
			lines.append("No open promises. Stand by a robot to offer terms.")
		lines.append(
			(
				"[color=#b7cbc9]Kept  Nell %d · Rafi %d      Broken  Nell %d · Rafi %d[/color]"
				% [sim.kept[0], sim.kept[1], sim.broken[0], sim.broken[1]]
			)
		)
	var words := "\n".join(lines)
	if promises.text != words:
		promises.text = words


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


func results(
	gold: int,
	blue: int,
	stats: Dictionary,
	crews: bool,
	sides: Array = [],
	headline: String = "",
	footnote: String = ""
) -> void:
	var title := (
		"Gold lights the harbor"
		if gold > blue
		else ("Blue lights the harbor" if blue > gold else "Shared light")
	)
	if headline != "":
		title = headline
	if sides.is_empty():
		sides = ["GOLD CREW" if crews else "HUMANS", "BLUE CREW" if crews else "ROBOTS"]
	menu(
		title,
		"FINAL WHISTLE",
		(
			footnote
			if footnote != ""
			else (
				"%d machine-lit beacons" % stats.beacons
				+ ("     ·     %d charged relays" % stats.relays if crews else "")
			)
		),
		{"again": "Rematch", "select": "Change mode", "replay": "Replay opening"}
	)
	for child in final_card.get_children():
		final_card.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 4)
	final_card.add_child(grid)
	for row in [
		["MATCH CARD", sides[0], sides[1]],
		["Goals", gold, blue],
		["Shots", stats.shots[0], stats.shots[1]],
		["Passes completed", stats.passes[0], stats.passes[1]],
		["Steals + interceptions", stats.steals[0], stats.steals[1]]
	]:
		for col in 3:
			var label := ink_label(str(row[col]), 22, [PALE, GOLD_INK, AQUA][col], true)
			if col > 0:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(label)
	final_card.show()


func pause_menu(sound_on := true, music_on := true, keep := "") -> void:
	focus_on = keep
	menu(
		"Time out",
		"LAST LIGHT",
		"Pick up where you left off, or take a new crew onto the court. M switches all audio off and on.",
		{
			"resume": "Resume match",
			"sound": "Sound   ON" if sound_on else "Sound   OFF",
			"music": "Music   ON" if music_on else "Music   OFF",
			"select": "Change mode"
		}
	)
	focus_on = ""
