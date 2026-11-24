extends CanvasLayer
## The way in: an animated title, how to play for both players, and the choice of game. Every
## screen works with a keyboard, a gamepad or a mouse, and says out loud what the keys do.
signal chosen(cmd: String)
signal cue(kind: String, pitch: float)

const DISPLAY = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const BODY = preload("res://assets/fonts/Barlow-Regular.ttf")
const MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const AMBER = Color("#ffd27a")
const PAPER = Color("#fff4dd")
const DIM = Color("#a9b8c0")
const INK = Color("#0d1117")
const GOLD = Color("#ffc056")
const BLUE = Color("#56d9ee")
const GREEN = Color("#9be27c")
const ROBOT = Color("#c9d2da")
## The two people at the keyboard, and the two characters they can play.
const WHO = [
	{
		"name": "NELL",
		"trade": "Ferry racer",
		"power": "FERRY RUN   The longest dash, and nobody can steal the star from her mid-dash.",
		"tint": Color("#5fe6c4")
	},
	{
		"name": "RAFI",
		"trade": "Ringwright's son",
		"power": "LONG SHOT   Scores from a step farther out than anyone else.",
		"tint": Color("#e08fd8")
	}
]
const SEATS = [
	{"seat": "PLAYER 1", "move": ["W", "A", "S", "D"], "go": "SPACE", "share": "F", "pad": "First gamepad"},
	{"seat": "PLAYER 2", "move": ["UP", "LEFT", "DOWN", "RIGHT"], "go": "ENTER", "share": "/", "pad": "Second gamepad"}
]
const MODES = [
	{
		"cmd": "free",
		"band": "RIVAL CAPTAINS",
		"title": "FREE AGENTS",
		"who": "Nell against Rafi. The three robots pick sides.",
		"meta": "4 MINUTES   ·   MOST GOALS WINS",
		"accent": Color("#ffc056"),
		"points":
		[
			"Each robot plays for whoever promises it something: Pip wants the next shot, Zip wants passes, Morrow wants a goal off a pass.",
			"Keep your word and it stays. Break it and it quits, strikes or joins your rival.",
			"Cheat them both and the robots walk out and play you for the harbor."
		]
	},
	{
		"cmd": "rivals",
		"band": "TWO AGAINST THREE",
		"title": "RIVALS",
		"who": "Nell and Rafi together against Pip, Morrow and Zip.",
		"meta": "4 MINUTES   ·   MOST GOALS WINS",
		"accent": Color("#56d9ee"),
		"points":
		[
			"Pass between you to slip past three defenders.",
			"Shoot from inside the painted arc in front of the gold ring.",
			"Pip steals, Morrow slows you down near him, and Zip passes fast."
		]
	},
	{
		"cmd": "crews",
		"band": "RECRUIT A ROBOT",
		"title": "OPEN CREWS",
		"who": "You start two against three. Win robots over mid-match.",
		"meta": "4 MINUTES   ·   MOST GOALS WINS",
		"accent": Color("#9be27c"),
		"points":
		[
			"Stand next to a robot and press SHARE to offer it a jersey.",
			"Pip joins early. Morrow helps whoever is behind. Zip wants to see you pass.",
			"Two passes in a row recharge every teammate's dash."
		]
	}
]

const GLASS := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.02, 0.035, 0.06, 0.74);
uniform vec3 edge : source_color = vec3(1.0, 0.82, 0.48);
uniform float lift = 0.0;
uniform vec2 size = vec2(400.0, 400.0);
uniform float radius = 22.0;
void fragment() {
	vec2 p = UV * size;
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 back = textureLod(screen, SCREEN_UV, 4.5).rgb;
	vec3 col = mix(back, tint.rgb, tint.a - 0.1 * lift);
	float rim = 1.0 - smoothstep(0.0, 1.5 + 1.5 * lift, abs(d + 1.4));
	col += edge * rim * (0.28 + 0.72 * lift);
	col += edge * 0.12 * lift * smoothstep(0.6, 0.0, UV.y);
	col += vec3(1.0) * 0.04 * smoothstep(0.35, 0.0, UV.y);
	COLOR = vec4(col, inside);
}
"""
const SHADE := """shader_type canvas_item;
uniform float amount = 1.0;
uniform float top = 0.35;
uniform float bottom = 0.6;
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.5, 1.05, length(c * vec2(1.0, 1.3)));
	float low = smoothstep(0.62, 1.0, UV.y);
	float high = 1.0 - smoothstep(0.0, 0.26, UV.y);
	COLOR = vec4(0.012, 0.02, 0.045, clamp(v * 0.22 + low * bottom + high * top, 0.0, 0.9) * amount);
}
"""
const BEAM := """shader_type canvas_item;
render_mode blend_add;
uniform float sweep = -0.5;
uniform vec3 tint : source_color = vec3(1.0, 0.84, 0.55);
void fragment() {
	float x = UV.x + (UV.y - 0.5) * 0.38;
	float band = exp(-pow((x - sweep) * 6.0, 2.0));
	float core = exp(-pow((x - sweep) * 24.0, 2.0));
	COLOR = vec4(tint * (band * 0.28 + core * 0.42) * smoothstep(1.0, 0.25, UV.y), 1.0);
}
"""


## A key on a keyboard, drawn with depth so it reads as something to press.
class Keycap:
	extends Control
	const FACE = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	var text := ""
	var tint := Color.WHITE

	func _init(label: String, wide: float, shade: Color) -> void:
		text = label
		tint = shade
		custom_minimum_size = Vector2(wide, 50)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var depth := StyleBoxFlat.new()
		depth.bg_color = tint.darkened(.62)
		depth.set_corner_radius_all(9)
		draw_style_box(depth, Rect2(Vector2(0, 5), size - Vector2(0, 5)))
		var top := StyleBoxFlat.new()
		top.bg_color = Color("#f7f1e3")
		top.set_corner_radius_all(9)
		top.border_color = tint
		top.border_width_bottom = 3
		draw_style_box(top, Rect2(Vector2.ZERO, size - Vector2(0, 5)))
		var mid := Vector2(size.x * .5, (size.y - 5) * .5)
		var ink := Color("#141a20")
		var arrows := {"UP": Vector2.UP, "DOWN": Vector2.DOWN, "LEFT": Vector2.LEFT, "RIGHT": Vector2.RIGHT}
		if arrows.has(text):
			var way: Vector2 = arrows[text]
			var side := way.orthogonal()
			draw_colored_polygon(
				PackedVector2Array([mid + way * 11., mid - way * 7. + side * 10., mid - way * 7. - side * 10.]), ink
			)
			return
		var size_px := 26 if text.length() <= 1 else 20
		var wide: float = FACE.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(FACE, Vector2(mid.x - wide * .5, mid.y + size_px * .36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)


## A small moving picture of who plays whom in each mode.
class Matchup:
	extends Control
	const FACE = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	var kind := "free"
	var clock := 0.0

	func _init(mode: String) -> void:
		kind = mode
		custom_minimum_size = Vector2(340, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		clock += dt
		queue_redraw()

	func token(at: Vector2, letter: String, fill: Color, human: bool) -> void:
		if human:
			draw_circle(at, 17., fill.darkened(.55))
			draw_circle(at, 14., fill)
		else:
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.set_corner_radius_all(5)
			box.border_color = fill.darkened(.55)
			box.set_border_width_all(2)
			draw_style_box(box, Rect2(at - Vector2(14, 14), Vector2(28, 28)))
		var w: float = FACE.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(FACE, at + Vector2(-w * .5, 6.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#10161c"))

	func _draw() -> void:
		var gold := Color("#ffc056")
		var blue := Color("#56d9ee")
		var y := size.y * .5
		var mid := size.x * .5
		draw_line(Vector2(mid, 6), Vector2(mid, size.y - 6), Color(1, 1, 1, .18), 2.)
		match kind:
			"free":
				token(Vector2(36, y), "N", gold, true)
				token(Vector2(size.x - 36, y), "R", blue, true)
				# The robots drift between the captains, each on its own clock.
				for k in 3:
					var swing := sin(clock * .9 + k * 2.1)
					var x := lerpf(96., size.x - 96., .5 + .5 * swing)
					token(Vector2(x, y + (k - 1) * 22.), ["P", "M", "Z"][k], gold.lerp(blue, .5 + .5 * swing), false)
			"rivals":
				var toss := .5 + .5 * sin(clock * 2.)
				token(Vector2(40, y - 18), "N", gold, true)
				token(Vector2(40, y + 18), "R", gold, true)
				draw_circle(Vector2(62, lerpf(y - 18, y + 18, toss)), 5., Color("#fff2c6"))
				for k in 3:
					token(Vector2(size.x - 40 - (k % 2) * 46, y + (k - 1) * 24.), ["P", "M", "Z"][k], blue, false)
			_:
				token(Vector2(40, y - 18), "N", gold, true)
				token(Vector2(40, y + 18), "R", gold, true)
				# Pip comes over, gets a gold jersey, and goes back to try again.
				var walk := clampf(fmod(clock, 4.) / 2.2, 0., 1.)
				walk = walk * walk * (3. - 2. * walk)
				token(Vector2(lerpf(size.x - 40, 96, walk), y - 24), "P", blue.lerp(gold, walk), false)
				token(Vector2(size.x - 40, y + 4), "M", blue, false)
				token(Vector2(size.x - 86, y + 26), "Z", blue, false)


var root := Control.new()
var shade := ColorRect.new()
var shade_look := ShaderMaterial.new()
var beam := ColorRect.new()
var beam_look := ShaderMaterial.new()
var page := Control.new()
var glass := Shader.new()
## The current screen's buttons, in order. Tests press them by position.
var buttons: Array[Button] = []
var letters: Array[Label] = []
var lit_letters := 0
var logo_done := false
var reel: Tween
var prompt: Label
var clock := 0.0
var quiet_until := 0.0
var screen := ""


func _ready() -> void:
	layer = 7
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.code = GLASS
	shade_look.shader = Shader.new()
	shade_look.shader.code = SHADE
	shade.material = shade_look
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	beam_look.shader = Shader.new()
	beam_look.shader.code = BEAM
	beam.material = beam_look
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(beam)
	beam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	beam_look.set_shader_parameter("sweep", -1.)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func area() -> Vector2:
	return root.get_viewport_rect().size


func words(text: String, face: Font, size_px: int, tint: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", tint)
	return l


## Words that sit straight on the harbor get a dark edge and a soft shadow, so they read against
## a bright sky without the scene behind them having to be darkened.
func edged(l: Label) -> Label:
	var px: int = l.get_theme_font_size("font_size")
	l.add_theme_constant_override("outline_size", clampi(px / 5, 3, 10))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.94))
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.06, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", clampi(px / 3, 7, 16))
	return l


## Small print gets a dark plate just its own size, placed in the middle of the screen at `y`
## (or left where it is when `y` is negative).
func plated(l: Label, y := -1.) -> Label:
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.03, 0.04, 0.07, 0.64)
	plate.set_corner_radius_all(10)
	plate.content_margin_left = 14
	plate.content_margin_right = 14
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", plate)
	l.size = l.get_minimum_size()
	if y >= 0.:
		l.position = Vector2((area().x - l.size.x) * .5, y)
	return l


func clear() -> void:
	if reel and reel.is_valid():
		reel.kill()
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	buttons.clear()
	letters.clear()
	quiet_until = clock + .35
	show()


func leave() -> void:
	clear()
	screen = ""
	hide()


## Slide a piece of the screen in from below, after `delay` seconds.
func arrive(part: Control, delay: float, rise: float = 26.) -> void:
	part.modulate.a = 0.
	var home := part.position
	part.position = home + Vector2(0, rise)
	var t := part.create_tween().set_parallel()
	t.tween_property(part, "modulate:a", 1., .35).set_delay(delay)
	t.tween_property(part, "position", home, .45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func frosted(parent: Control, rect: Rect2, accent: Color, tint: Color = Color(0.02, 0.035, 0.06, 0.74)) -> ShaderMaterial:
	var pane := ColorRect.new()
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = glass
	look.set_shader_parameter("size", rect.size)
	look.set_shader_parameter("edge", accent)
	look.set_shader_parameter("tint", tint)
	pane.material = look
	parent.add_child(pane)
	pane.position = rect.position
	pane.size = rect.size
	return look


## A card or button that lights up when it has focus, whether from the mouse or the keys.
func pressable(parent: Control, rect: Rect2, accent: Color, cmd: String, solid: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, empty)
	parent.add_child(b)
	b.position = rect.position
	b.size = rect.size
	b.pivot_offset = rect.size * .5
	var look := frosted(b, Rect2(Vector2.ZERO, rect.size), accent, Color(accent.r * .9, accent.g * .9, accent.b * .9, .96) if solid else Color(0.02, 0.035, 0.06, 0.74))
	b.set_meta("look", look)
	b.focus_entered.connect(glow.bind(b, true))
	b.focus_exited.connect(glow.bind(b, false))
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(pick.bind(cmd))
	buttons.append(b)
	return b


func glow(b: Button, on: bool) -> void:
	var look: ShaderMaterial = b.get_meta("look")
	var t := b.create_tween().set_parallel()
	t.tween_method(func(v: float): look.set_shader_parameter("lift", v), 1. - float(on), float(on), .18)
	t.tween_property(b, "scale", Vector2.ONE * (1.035 if on else 1.), .18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on and clock > quiet_until:
		cue.emit("ui_move", 1.)


func pick(cmd: String) -> void:
	cue.emit("ui_back" if cmd in ["controls", "story"] and screen == "modes" else "ui_pick", 1.)
	chosen.emit(cmd)


## A text button for the row along the bottom of a screen.
func action(parent: Control, at: Vector2, width: float, text: String, cmd: String, accent: Color, primary: bool) -> Button:
	var b := pressable(parent, Rect2(at, Vector2(width, 54)), accent, cmd, primary)
	var label := words(text, DISPLAY, 24, INK if primary else PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


func heading(kicker: String, title: String) -> void:
	var top := words(kicker, MONO, 15, Color("#ffd98a"))
	page.add_child(top)
	plated(top)
	top.position = Vector2(58, 26)
	var big := edged(words(title, DISPLAY, 52, PAPER))
	page.add_child(big)
	big.position = Vector2(62, 58)
	arrive(top, 0.)
	arrive(big, .06)


# ------------------------------------------------------------------ title


func title() -> void:
	clear()
	screen = "title"
	logo_done = false
	lit_letters = 0
	shade_look.set_shader_parameter("top", 0.)
	shade_look.set_shader_parameter("bottom", .42)
	var size := area()
	var kicker := words("SATURN   ·   LAMPLIGHT HARBOR   ·   THE LAST NIGHT OF SUMMER", MONO, 15, Color("#fff0c9"))
	page.add_child(kicker)
	plated(kicker, 96)
	kicker.modulate.a = 0.
	var halo := ColorRect.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark := ShaderMaterial.new()
	dark.shader = Shader.new()
	# A band of shadow across the screen behind the name, like the title card of a film.
	dark.shader.code = "shader_type canvas_item; void fragment(){ vec2 c = (UV - 0.5) * vec2(1.0, 1.9); COLOR = vec4(0.03, 0.03, 0.08, 0.3 * (1.0 - smoothstep(0.1, 0.5, length(c)))); }"
	halo.material = dark
	page.add_child(halo)
	halo.position = Vector2(0, 96)
	halo.size = Vector2(size.x, 372)
	halo.modulate.a = 0.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	page.add_child(row)
	row.position = Vector2(0, 150)
	row.size = Vector2(size.x, 190)
	for ch in "LAST LIGHT":
		if ch == " ":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(52, 10)
			row.add_child(gap)
			continue
		var letter := words(ch, DISPLAY, 178, Color("#252b36"))
		letter.add_theme_constant_override("outline_size", 6)
		letter.add_theme_color_override("font_outline_color", Color("#05070a"))
		letter.add_theme_color_override("font_shadow_color", Color(1., .62, .2, 0.))
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 0)
		letter.add_theme_constant_override("shadow_outline_size", 34)
		row.add_child(letter)
		letters.append(letter)
	var rule := ColorRect.new()
	rule.color = AMBER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(rule)
	rule.size = Vector2(0, 3)
	rule.position = Vector2(size.x * .5, 352)
	var line := edged(words("Two humans. Three robots. One light to win.", BODY, 30, Color("#fffaf0")))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(line)
	line.position = Vector2(0, 372)
	line.size = Vector2(size.x, 40)
	line.modulate.a = 0.
	var small := words("A party game for two players on one keyboard", MONO, 14, PAPER)
	page.add_child(small)
	plated(small, 420)
	small.modulate.a = 0.
	prompt = edged(words("PRESS ANY KEY", DISPLAY, 34, AMBER))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(prompt)
	prompt.position = Vector2(0, size.y - 118)
	prompt.size = Vector2(size.x, 40)
	prompt.modulate.a = 0.
	var skip := words("ESC   skip the story and go straight to the controls", MONO, 13, PAPER)
	page.add_child(skip)
	plated(skip, size.y - 76)
	skip.modulate.a = 0.
	reel = create_tween()
	reel.tween_property(halo, "modulate:a", 1., .45)
	reel.tween_property(kicker, "modulate:a", 1., .5)
	for n in letters.size():
		reel.tween_callback(ignite.bind(n))
		reel.tween_interval(.12)
	reel.tween_callback(sweep)
	reel.tween_property(rule, "size:x", 560., .45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reel.parallel().tween_property(rule, "position:x", size.x * .5 - 280., .45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reel.tween_property(line, "modulate:a", 1., .5)
	reel.tween_property(small, "modulate:a", 1., .4)
	reel.tween_callback(func(): logo_done = true)
	reel.tween_property(prompt, "modulate:a", 1., .35)
	reel.parallel().tween_property(skip, "modulate:a", 1., .35)


## One letter of the name lights like a harbor lamp coming on.
func ignite(n: int) -> void:
	if n < lit_letters:
		return
	lit_letters = n + 1
	var letter: Label = letters[n]
	letter.pivot_offset = letter.size * .5
	letter.scale = Vector2(1.22, 1.22)
	var t := letter.create_tween().set_parallel()
	t.tween_property(letter, "scale", Vector2.ONE, .4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(
		func(v: float):
			letter.add_theme_color_override("font_color", Color("#252b36").lerp(Color("#fff0cf"), v))
			letter.add_theme_color_override("font_shadow_color", Color(1., .62, .2, .75 * v)),
		0., 1., .3
	)
	cue.emit("lamp", .82 + n * .055)


func sweep() -> void:
	cue.emit("title_hit", 1.)
	var t := create_tween()
	t.tween_method(func(v: float): beam_look.set_shader_parameter("sweep", v), -.3, 1.35, 1.3).set_trans(Tween.TRANS_SINE)


## A key on the title. The first press finishes the animation, the next one moves on.
func title_key() -> bool:
	if screen != "title":
		return false
	if logo_done:
		return true
	if reel and reel.is_valid():
		reel.custom_step(30.)
	for n in letters.size():
		ignite(n)
	logo_done = true
	return false


# ------------------------------------------------------------------ how to play


func controls(pilots: Array) -> void:
	clear()
	screen = "controls"
	shade_look.set_shader_parameter("top", .3)
	shade_look.set_shader_parameter("bottom", .5)
	heading("HOW TO PLAY   ·   TWO PLAYERS, ONE KEYBOARD", "Move, and two buttons. That's all.")
	var size := area()
	var gap := 40.
	var wide := (size.x - 128. - gap) * .5
	for seat in 2:
		var who: Dictionary = WHO[pilots[seat]]
		var keys: Dictionary = SEATS[seat]
		var tint: Color = who.tint
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(card)
		card.position = Vector2(64 + seat * (wide + gap), 140)
		card.size = Vector2(wide, 452)
		frosted(card, Rect2(Vector2.ZERO, card.size), tint)
		var tag := words(keys.seat, MONO, 15, tint)
		card.add_child(tag)
		tag.position = Vector2(30, 22)
		var called := words(who.name, DISPLAY, 58, tint)
		card.add_child(called)
		called.position = Vector2(28, 36)
		var trade := words(who.trade, BODY, 20, DIM)
		card.add_child(trade)
		trade.position = Vector2(34 + called.get_minimum_size().x, 64)
		var power := words(who.power, BODY, 17, AMBER)
		power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(power)
		power.position = Vector2(30, 108)
		power.size = Vector2(wide - 60, 48)
		var cut := ColorRect.new()
		cut.color = Color(1, 1, 1, .12)
		cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cut)
		cut.position = Vector2(30, 166)
		cut.size = Vector2(wide - 60, 1)
		# MOVE: four keys in the usual cross.
		key_row(card, 186, "MOVE", "Run anywhere on the court.", tint)
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pad)
		pad.position = Vector2(118, 180)
		var spots := [Vector2(54, 0), Vector2(0, 52), Vector2(54, 52), Vector2(108, 52)]
		for n in 4:
			var cap := Keycap.new(keys.move[n], 50, tint)
			pad.add_child(cap)
			cap.position = spots[n]
		var go_wide := 170. if keys.go == "SPACE" else 116.
		key_row(card, 306, "GO", "In range of the ring: shoot. Anywhere else: dash, or steal the star.", tint, go_wide)
		var go := Keycap.new(keys.go, go_wide, tint)
		card.add_child(go)
		go.position = Vector2(118, 300)
		key_row(card, 382, "SHARE", "Pass to a teammate. In Free Agents it also pays a robot or makes it an offer.", tint, 50.)
		var share := Keycap.new(keys.share, 50, tint)
		card.add_child(share)
		share.position = Vector2(118, 376)
		arrive(card, .12 + seat * .1)
	var tip := words(
		"In a match, the bar at the bottom of the screen always says what your two buttons will do right now.",
		BODY, 19, PAPER
	)
	page.add_child(tip)
	plated(tip, 600)
	arrive(tip, .3)
	var pad_line := words("Gamepads work too: left stick to move, A is GO, X is SHARE.", MONO, 13, PAPER)
	page.add_child(pad_line)
	plated(pad_line, 640)
	arrive(pad_line, .34)
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bar)
	var swap_text := "SWAP   ·   PLAYER 1 PLAYS %s" % WHO[pilots[1]].name
	var first := action(bar, Vector2(size.x * .5 - 430, 680), 300, "CHOOSE A GAME   →", "modes", AMBER, true)
	action(bar, Vector2(size.x * .5 - 110, 680), 330, swap_text, "swap", AMBER, false)
	action(bar, Vector2(size.x * .5 + 240, 680), 190, "WATCH THE STORY", "story", AMBER, false)
	arrive(bar, .4, 14.)
	first.grab_focus.call_deferred()


## The name of a control and what it does, to the right of where its keys are drawn.
func key_row(card: Control, y: float, what: String, meaning: String, tint: Color, keys_wide: float = 158.) -> void:
	var label := words(what, DISPLAY, 24, PAPER)
	card.add_child(label)
	label.position = Vector2(30, y + 8)
	var text := words(meaning, BODY, 18, PAPER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(text)
	var left := 118. + keys_wide + 22.
	text.position = Vector2(left, y + (22 if what == "MOVE" else 0))
	text.size = Vector2(card.size.x - left - 26, 54)
	text.add_theme_color_override("font_color", PAPER.lerp(tint, .15))


# ------------------------------------------------------------------ choose a game


func modes() -> void:
	clear()
	screen = "modes"
	shade_look.set_shader_parameter("top", .3)
	shade_look.set_shader_parameter("bottom", .5)
	heading("CHOOSE YOUR GAME", "Three ways to play.")
	var size := area()
	var gap := 30.
	var wide := (size.x - 128. - gap * 2.) / 3.
	var first: Button
	for n in MODES.size():
		var mode: Dictionary = MODES[n]
		var accent: Color = mode.accent
		var card := pressable(page, Rect2(Vector2(64 + n * (wide + gap), 136), Vector2(wide, 492)), accent, mode.cmd)
		if n == 0:
			first = card
		var band := words(" %s " % mode.band, MONO, 13, INK)
		var chip := StyleBoxFlat.new()
		chip.bg_color = accent
		chip.set_corner_radius_all(4)
		chip.content_margin_left = 8
		chip.content_margin_right = 8
		chip.content_margin_top = 2
		chip.content_margin_bottom = 2
		band.add_theme_stylebox_override("normal", chip)
		card.add_child(band)
		band.position = Vector2(26, 24)
		var called := words(mode.title, DISPLAY, 54, PAPER)
		card.add_child(called)
		called.position = Vector2(24, 50)
		var picture := Matchup.new(mode.cmd)
		card.add_child(picture)
		picture.position = Vector2(24, 122)
		picture.size = Vector2(wide - 48, 74)
		var who := words(mode.who, BODY, 20, accent)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(who)
		who.position = Vector2(26, 206)
		who.size = Vector2(wide - 52, 52)
		var meta := words(mode.meta, MONO, 13, DIM)
		card.add_child(meta)
		meta.position = Vector2(26, 262)
		var points := VBoxContainer.new()
		points.mouse_filter = Control.MOUSE_FILTER_IGNORE
		points.add_theme_constant_override("separation", 8)
		card.add_child(points)
		points.position = Vector2(26, 290)
		points.size = Vector2(wide - 52, 150)
		for line in mode.points:
			var item := words("•  " + line, BODY, 16, PAPER)
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.custom_minimum_size = Vector2(wide - 52, 0)
			points.add_child(item)
		var go := words("PRESS ENTER OR CLICK TO PLAY", DISPLAY, 19, accent)
		go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(go)
		go.position = Vector2(0, 450)
		go.size = Vector2(wide, 26)
		go.modulate.a = 0.
		card.focus_entered.connect(func(): go.create_tween().tween_property(go, "modulate:a", 1., .2))
		card.focus_exited.connect(func(): go.create_tween().tween_property(go, "modulate:a", 0., .15))
		arrive(card, .1 + n * .08)
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bar)
	action(bar, Vector2(64, 668), 250, "←   HOW TO PLAY", "controls", AMBER, false)
	action(bar, Vector2(330, 668), 250, "MEET THE CREW AGAIN", "story", AMBER, false)
	var hint := words("←  →   choose          ENTER   play          ESC   back", MONO, 14, PAPER)
	bar.add_child(hint)
	plated(hint)
	hint.position = Vector2(size.x - 64 - hint.size.x, 680)
	arrive(bar, .35, 14.)
	first.grab_focus.call_deferred()


func _process(dt: float) -> void:
	clock += dt
	if screen == "title" and logo_done and is_instance_valid(prompt):
		prompt.modulate.a = .55 + .45 * sin(clock * 3.2)
