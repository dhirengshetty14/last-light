extends CanvasLayer
signal chosen(cmd: String)
signal sound(kind: String)
const DISPLAY_FACE = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const BODY_FACE = preload("res://assets/fonts/Barlow-Regular.ttf")
const INSTRUMENT_FACE = preload("res://assets/fonts/SpaceMono-Regular.ttf")
var root: Control
var nav: VBoxContainer
var copy: Label
var heading: Label
var where_label: Label
var hero: TextureRect
var page := "title"
var first: Button
var active := false
var title_paint := ShaderMaterial.new()
var story_root: Control
var story_name: Label
var story_line: Label
var story_key: Label
var story_power: Label


func ink_label(content: String, size: int, tint: Color, serif: bool = false) -> Label:
	var l := Label.new()
	l.text = content
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", DISPLAY_FACE if serif else BODY_FACE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	return l


func full(c: Control, p: Node) -> void:
	p.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func shade(parent: Control, mode: String) -> void:
	var band := ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(band, parent)
	var s := Shader.new()
	if mode == "title":
		s.code = "shader_type canvas_item; void fragment(){float x=1.-smoothstep(0.,.66,UV.x);float y=smoothstep(.54,1.,UV.y);float top=1.-smoothstep(0.,.43,UV.y);COLOR=vec4(.024,.049,.064,min(.96,.15+.65*x*max(y,top)+.60*y));}"
	else:
		s.code = "shader_type canvas_item; void fragment(){float b=smoothstep(.67,.985,UV.y);float t=1.-smoothstep(0.,.13,UV.y);COLOR=vec4(.014,.025,.034,max(b*.94,t*.74));}"
	var m := ShaderMaterial.new()
	m.shader = s
	band.material = m


func _ready() -> void:
	layer = 5
	root = Control.new()
	full(root, self)
	title_paint.shader = preload("res://game/shaders/title_art.gdshader")
	hero = TextureRect.new()
	hero.material = title_paint
	hero.texture = load("res://assets/room/crew_key_art.webp")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(hero, root)
	shade(root, "title")
	where_label = ink_label("SATURN  /  NURSERY DOCK", 15, Color("#ffdea1"))
	where_label.add_theme_font_override("font", INSTRUMENT_FACE)
	root.add_child(where_label)
	where_label.position = Vector2(51, 36)
	heading = ink_label("This Side Up", 73, Color("#fff4d8"), true)
	var display := FontVariation.new()
	display.base_font = DISPLAY_FACE
	display.spacing_glyph = 2
	heading.add_theme_font_override("font", display)
	heading.add_theme_font_size_override("font_size", 84)
	heading.uppercase = true
	root.add_child(heading)
	heading.position = Vector2(46, 58)
	var lower := VBoxContainer.new()
	root.add_child(lower)
	lower.anchor_top = 1
	lower.anchor_bottom = 1
	lower.anchor_right = 1
	lower.offset_left = 50
	lower.offset_right = -42
	lower.offset_top = -172
	lower.offset_bottom = -26
	lower.add_theme_constant_override("separation", 14)
	copy = ink_label("", 19, Color("#f2e9d6"))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lower.add_child(copy)
	nav = VBoxContainer.new()
	lower.add_child(nav)
	story_root = Control.new()
	full(story_root, self)
	story_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade(story_root, "story")
	var credits := VBoxContainer.new()
	story_root.add_child(credits)
	credits.anchor_top = 1
	credits.anchor_bottom = 1
	credits.anchor_right = 1
	credits.offset_left = 50
	credits.offset_right = -48
	credits.offset_top = -182
	credits.offset_bottom = -15
	credits.add_theme_constant_override("separation", 5)
	story_name = ink_label("", 15, Color("#f3c984"))
	story_line = ink_label("", 29, Color("#fff4df"), true)
	story_key = ink_label("", 14, Color("#b7cbc9"))
	# One plain line under each introduction: what this character can do that nobody else can.
	story_power = ink_label("", 21, Color("#ffd98a"), true)
	story_power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_name.add_theme_font_override("font", INSTRUMENT_FACE)
	story_line.add_theme_font_override("font", BODY_FACE)
	story_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in [story_name, story_line, story_power, story_key]:
		credits.add_child(c)
	story_root.hide()
	home()


func set_controls(items: Dictionary) -> void:
	for child in nav.get_children():
		nav.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	nav.add_child(row)
	var i := 0
	for command in items:
		var b := Button.new()
		b.text = items[command]
		b.add_theme_font_override("font", DISPLAY_FACE)
		b.custom_minimum_size = Vector2(135, 45)
		b.add_theme_font_size_override("font_size", 21)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#e4c894") if i == 0 else Color(.055, .09, .11, .87)
		normal.set_corner_radius_all(4)
		normal.border_color = Color("#a48b62")
		normal.set_border_width_all(1)
		normal.content_margin_left = 18
		normal.content_margin_right = 18
		b.add_theme_stylebox_override("normal", normal)
		var focus := normal.duplicate() as StyleBoxFlat
		focus.set_border_width_all(2)
		focus.border_color = Color("#fff3cf")
		b.add_theme_stylebox_override("focus", focus)
		var ink := Color("#172c31") if i == 0 else Color("#f6e7cc")
		b.add_theme_color_override("font_color", ink)
		b.add_theme_color_override("font_focus_color", ink)
		b.add_theme_stylebox_override("hover", focus)
		b.add_theme_color_override("font_hover_color", ink)
		b.pressed.connect(pick.bind(command))
		b.pressed.connect(func(): sound.emit("ui_pick"))
		b.focus_entered.connect(func(): if active: sound.emit("ui_move"))
		b.mouse_entered.connect(b.grab_focus)
		row.add_child(b)
		if i == 0:
			first = b
		i += 1
	if first and active:
		first.grab_focus()


func home() -> void:
	active = true
	root.show()
	story_root.hide()
	page = "title"
	heading.text = "This Side Up"
	copy.text = "Her calf is caught in the nursery. Five crew members share control of the hatch."
	set_controls(
		{
			"story": "Begin story",
			"modes": "Game modes",
			"gallery": "Meet the crew",
			"help": "Controls"
		}
	)


func modes() -> void:
	page = "modes"
	heading.text = "Choose a shift"
	copy.text = "First Rescue · Saturn Nursery Dock. Ring Storm · Enceladus Ferry. Ice wakes deflect the pod and shorten each hatch pass."
	set_controls({"start": "First rescue", "storm": "Ring storm", "back": "Back to title"})


func pick(cmd: String) -> void:
	if cmd == "modes":
		modes()
		return
	if cmd == "back":
		home()
		return
	chosen.emit(cmd)


func leave() -> void:
	active = false
	root.hide()
	story_root.hide()


func dialogue(who: String, line: String, key: String, power: String = "") -> void:
	active = false
	root.hide()
	story_root.show()
	story_name.text = who
	story_line.text = line
	story_key.text = key
	story_power.text = power
	story_power.visible = power != ""
