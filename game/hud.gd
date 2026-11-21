extends CanvasLayer
signal menu_action(value: String)
const INK = Color("#f3eadc")
const MINT = Color("#92e0cf")
var top: Label
var status: Label
var feed: Label
var target: Label
var hint: Label
var menu: PanelContainer
var title: Label
var body: Label
var buttons: HBoxContainer
var layout_root: Control
var ledger_on := true


func label(words: String, n: int, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", n)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func panel(fill: Color, border: Color = Color("#365052")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func block(anchor: Vector2, offset: Vector2, width: float, txt: Label) -> PanelContainer:
	var p := PanelContainer.new()
	layout_root.add_child(p)
	p.anchor_left = anchor.x
	p.anchor_top = anchor.y
	p.anchor_right = anchor.x
	p.anchor_bottom = anchor.y
	p.offset_left = offset.x
	p.offset_right = offset.x + width
	p.offset_top = offset.y
	p.offset_bottom = offset.y
	p.custom_minimum_size.x = width
	p.add_theme_stylebox_override("panel", panel(Color(.032, .067, .090, .85)))
	p.add_child(txt)
	return p


func _ready() -> void:
	layout_root = Control.new()
	add_child(layout_root)
	layout_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top = label("", 20)
	block(Vector2.ZERO, Vector2(26, 23), 295, top)
	status = label("", 17, MINT)
	block(Vector2(1, 0), Vector2(-378, 23), 350, status)
	feed = label("", 15)
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block(Vector2(1, 1), Vector2(-418, -179), 390, feed)
	target = label("", 15, MINT)
	block(Vector2(0, 1), Vector2(26, -102), 480, target)
	hint = label("", 14)
	block(Vector2(0, 1), Vector2(26, -56), 620, hint)
	menu = PanelContainer.new()
	layout_root.add_child(menu)
	menu.anchor_left = .5
	menu.anchor_right = .5
	menu.anchor_top = .5
	menu.anchor_bottom = .5
	menu.offset_left = -285
	menu.offset_right = 285
	menu.offset_top = -162
	menu.add_theme_stylebox_override("panel", panel(Color(.036, .071, .10, .97), Color("#9a895f")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	menu.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 13)
	margin.add_child(v)
	title = label("", 37)
	v.add_child(title)
	body = label("", 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	menu.visible = false


func show_menu(heading: String, words: String, options: Dictionary) -> void:
	menu.visible = true
	title.text = heading
	body.text = words
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	for key in options:
		var b := Button.new()
		b.text = options[key]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", panel(Color("#275851"), Color("#66a69a")))
		b.add_theme_stylebox_override("hover", panel(Color("#36685d"), MINT))
		b.pressed.connect(_picked.bind(key))
		buttons.add_child(b)


func _picked(value: String) -> void:
	menu_action.emit(value)


func dismiss() -> void:
	menu.visible = false


func sync(s, selected: Array, duties: Array) -> void:
	top.text = (
		"%s    /    %02d:%02d"
		% [
			"RING STORM" if s.difficulty == 1 else "THIS SIDE UP",
			int(maxi(0, s.deadline - s.tick) / 3600),
			int(maxi(0, s.deadline - s.tick) / 60) % 60
		]
	)
	status.text = (
		"Shell  %s    ·    %s    ·    %s"
		% [
			"●".repeat(maxi(s.hull, 0)) + "○".repeat(maxi(0, (2 if s.difficulty else 3) - s.hull)),
			s.ZONES[s.gravity],
			(
				"Hatch open"
				if s.hatch_open(s.tick)
				else (
					"Between passes"
					if s.tick >= s.hatch_at
					else "Hatch in %ds" % ceili((s.hatch_at - s.tick) / 60.)
				)
			)
		]
	)
	var lines := PackedStringArray()
	var ini := maxi(0, s.public_lines.size() - 3)
	for n in range(ini, s.public_lines.size()):
		var row: Dictionary = s.public_lines[n]
		lines.append(("%s   " % s.NAMES[row.actor] if row.actor >= 0 else "") + row.text)
	feed.text = "\n".join(lines) if not lines.is_empty() else "Flight recorder ready."
	feed.get_parent().visible = ledger_on
	var owe := ""
	for id in s.social.offers:
		var o: Dictionary = s.social.offers[id]
		if o.provider < 2 or o.buyer < 2:
			owe = (
				"    ·    %s → %s  %s [%s]"
				% [s.NAMES[o.buyer], s.NAMES[o.provider], o.duty, o.status]
			)
			break
	target.text = (
		"Nell [%d] → %s / %s    ·    Rafi [%d] → %s / %s%s"
		% [
			s.social.balance[0],
			s.NAMES[selected[0]],
			duties[0],
			s.social.balance[1],
			s.NAMES[selected[1]],
			duties[1],
			owe
		]
	)
	hint.text = "E / Enter  latch    ·    Space / /  cover    ·    F1  controls    ·    F2  recorder    ·    G  studio"


func gallery(name_: String, mode: String, angle: float) -> void:
	top.text = "CAST STUDIO    /    " + name_
	status.text = mode + "     ·     " + str(roundi(rad_to_deg(angle))) + "°"
	feed.get_parent().hide()
	target.text = "← →  character     ↑ ↓  expression     C  camera distance"
	hint.text = "Drag to orbit    ·    V  turntable    ·    G / Esc  return to flight"
