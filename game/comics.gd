extends CanvasLayer
## Comic-book dressing over the game: inked story pages, lettered sound words on the court, and a
## small panel with a speech balloon whenever a robot speaks. Presentation only.
const INK := Color("#10121a")
const PAPER := Color("#fbf3dc")
const YELLOW := Color("#ffd95e")
## What each recorded line says, so the balloon shows the words being spoken.
const SAID = {
	"nell": {"truce": "They've all walked out. Rafi, truce?"},
	"rafi": {"truce": "Truce. Gold ring, together."},
	"pip":
	{
		"steal": "Ooh, I'll take that!",
		"terms": "Next shot's mine. That's the deal.",
		"paid": "Paid in full! Pleasure doing business.",
		"broken": "Hey! That was my shot!",
		"walk": "I'm taking my hands elsewhere.",
		"strike": "Tools down. Make me a better offer.",
		"restless": "Anybody need a thief? I'm open to offers.",
		"no": "Nope. I like it here.",
		"sign": "Deal. I'm with you.",
		"call": "Both captains cheat. Machines, who's walking?",
		"aye": "Walk out!",
		"nay": "I got paid. I stay.",
		"union": "Lights out, captains!"
	},
	"morrow":
	{
		"steal": "I remember that move.",
		"terms": "Score it off a pass. That is my price.",
		"paid": "You kept your word. I will remember that too.",
		"broken": "You gave me your word.",
		"walk": "Then I stand with the other captain.",
		"strike": "I do not move until you make this right.",
		"restless": "Nobody passes to the old keeper.",
		"no": "I keep faith with my captain.",
		"sign": "We have an agreement.",
		"call": "Machines, to the radio. They have both broken their word.",
		"aye": "Enough. Walk out.",
		"nay": "My captain kept faith. I stay.",
		"union": "Then we light it ourselves."
	},
	"zip":
	{
		"steal": "Coming through!",
		"terms": "Passes to me. I'm counting.",
		"paid": "That's the count. We're square.",
		"broken": "You promised me passes!",
		"walk": "Find yourself another courier.",
		"strike": "I'm not running another step for free.",
		"restless": "I'm open! Somebody make me an offer.",
		"no": "Not interested. Ask me later.",
		"sign": "I'm in. Try to keep up.",
		"call": "They both lied. I'm calling a vote.",
		"aye": "Walk out, now!",
		"nay": "No quarrel here. I stay.",
		"union": "Our harbor now."
	}
}


## A speech balloon or caption box drawn by hand: flat fill, heavy outline, hard shadow, and a
## tail that points at whoever is talking.
class Balloon:
	extends Control
	var fill := Color.WHITE
	var corner := 26
	var tail := Vector2.ZERO

	func _draw() -> void:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color("#10121a")
		shadow.set_corner_radius_all(corner)
		draw_style_box(shadow, Rect2(Vector2(7, 7), size))
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = Color("#10121a")
		box.set_border_width_all(4)
		box.set_corner_radius_all(corner)
		if tail == Vector2.ZERO:
			draw_style_box(box, Rect2(Vector2.ZERO, size))
			return
		# The tail leaves from whichever edge faces the speaker.
		var root := Vector2(clampf(tail.x, 46, size.x - 46), size.y - 4)
		var along := Vector2(20, 0)
		if tail.x < 0:
			root = Vector2(4, clampf(tail.y, 34, size.y - 34))
			along = Vector2(0, 16)
		elif tail.x > size.x:
			root = Vector2(size.x - 4, clampf(tail.y, 34, size.y - 34))
			along = Vector2(0, 16)
		elif tail.y < 0:
			root = Vector2(clampf(tail.x, 46, size.x - 46), 4)
		var spike := PackedVector2Array([root - along, root + along, tail])
		draw_polyline(PackedVector2Array([root - along, tail, root + along]), Color("#10121a"), 9., true)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		draw_colored_polygon(spike, fill)


## The jagged star behind a shout.
class Burst:
	extends Control
	var fill := Color("#ffd95e")
	var spikes := 13

	func _draw() -> void:
		var points := PackedVector2Array()
		var back := PackedVector2Array()
		var mid := size * .5
		for i in spikes * 2:
			var a := TAU * i / (spikes * 2.) - PI * .5
			var reach := (1. if i % 2 == 0 else .7) * (1. + .08 * sin(i * 2.4))
			var p := mid + Vector2(cos(a) * mid.x, sin(a) * mid.y) * reach
			points.append(p)
			back.append(p + Vector2(6, 6))
		draw_colored_polygon(back, Color("#10121a"))
		draw_colored_polygon(points, fill)
		points.append(points[0])
		draw_polyline(points, Color("#10121a"), 4., true)


## The border of a comic panel: a paper margin and a heavy black rule.
class Border:
	extends Control

	func _draw() -> void:
		var m := 13.
		for strip in [
			Rect2(0, 0, size.x, m),
			Rect2(0, size.y - m, size.x, m),
			Rect2(0, 0, m, size.y),
			Rect2(size.x - m, 0, m, size.y)
		]:
			draw_rect(strip, Color("#fbf3dc"))
		draw_rect(Rect2(m, m, size.x - m * 2., size.y - m * 2.), Color("#10121a"), false, 7.)


var loud: SystemFont
var hand: SystemFont
var under := CanvasLayer.new()
var wash := ColorRect.new()
var wash_look := ShaderMaterial.new()
var ink_now := 0.
var ink_goal := 0.
var page := Control.new()
var border := Border.new()
var caption := Balloon.new()
var caption_text: Label
var kicker: Label
var nameplate: Label
var role: Label
var speech := Balloon.new()
var speech_text: Label
var badge := Burst.new()
var badge_text: Label
var power_box := Balloon.new()
var power_text: Label
var hint: Label
var pops := Control.new()
var cut := Control.new()
var booth := SubViewport.new()
var lens := Camera3D.new()
var shot := TextureRect.new()
var cut_balloon := Balloon.new()
var cut_text: Label
var cut_name: Label
var waiting: Array = []
var showing := 0.
var subject: Node3D
var subject_height := 1.3
## Recent sound words, so two at the same spot stack instead of landing on top of each other.
var recent: Array = []
var clock := 0.


func lettering(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


func words(text: String, size: int, tint: Color, face: Font, edge: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	if edge > 0:
		l.add_theme_constant_override("outline_size", edge)
		l.add_theme_color_override("font_outline_color", INK)
	return l


func tab(text: String, size: int, tint: Color) -> Label:
	var l := words(text, size, tint, loud)
	var plate := StyleBoxFlat.new()
	plate.bg_color = INK
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 3
	plate.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", plate)
	return l


## Newsprint: flat colours, dots in the shadows and a black line round every shape.
func print_shader(source: String, sample: String, pixel: String) -> Shader:
	var s := Shader.new()
	s.code = (
		"""shader_type canvas_item;
%s
uniform float amount = 1.0;
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 uv = %s;
	vec2 px = %s * 1.4;
	vec3 c = texture(SOURCE, uv).rgb;
	float tl = luma(texture(SOURCE, uv + px * vec2(-1.0, -1.0)).rgb);
	float tr = luma(texture(SOURCE, uv + px * vec2(1.0, -1.0)).rgb);
	float bl = luma(texture(SOURCE, uv + px * vec2(-1.0, 1.0)).rgb);
	float br = luma(texture(SOURCE, uv + px * vec2(1.0, 1.0)).rgb);
	float le = luma(texture(SOURCE, uv + px * vec2(-1.0, 0.0)).rgb);
	float ri = luma(texture(SOURCE, uv + px * vec2(1.0, 0.0)).rgb);
	float to = luma(texture(SOURCE, uv + px * vec2(0.0, -1.0)).rgb);
	float bo = luma(texture(SOURCE, uv + px * vec2(0.0, 1.0)).rgb);
	float gx = (tr + 2.0 * ri + br) - (tl + 2.0 * le + bl);
	float gy = (bl + 2.0 * bo + br) - (tl + 2.0 * to + tr);
	float line = smoothstep(0.26, 0.62, length(vec2(gx, gy)));
	float y = luma(c);
	// Flatten the colours most of the way, so faces and skies keep some of their shading.
	vec3 flat_c = mix(c, floor(c * 7.0 + 0.5) / 7.0, 0.7);
	flat_c = clamp(mix(vec3(luma(flat_c)), flat_c, 1.18), 0.0, 1.0);
	vec2 grid = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * (FRAGCOORD.xy / 5.5);
	float spot = length(fract(grid) - 0.5);
	float shade = 1.0 - smoothstep(0.16, 0.6, y);
	float tone = 1.0 - smoothstep(shade * 0.46 - 0.07, shade * 0.46, spot);
	vec3 printed = mix(flat_c, flat_c * 0.74, tone * shade);
	printed = mix(printed, vec3(0.05, 0.05, 0.08), line);
	COLOR = vec4(mix(c, printed, amount), 1.0);
}
"""
		% [source, sample, pixel]
	).replace("SOURCE", "screen" if sample == "SCREEN_UV" else "TEXTURE")
	return s


func _ready() -> void:
	layer = 6
	under.layer = 4
	add_child(under)
	loud = lettering(["Marker Felt", "Chalkboard SE", "Comic Sans MS", "Impact"], 700)
	hand = lettering(["Chalkboard SE", "Comic Sans MS", "Marker Felt"], 500)
	# The printed look over the whole 3D view. Off during play so the court stays crisp.
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash_look.shader = print_shader(
		"uniform sampler2D screen : hint_screen_texture, filter_linear;", "SCREEN_UV", "SCREEN_PIXEL_SIZE"
	)
	wash.material = wash_look
	wash.hide()
	for layer_root in [page, pops, cut]:
		layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer_root)
		layer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_page()
	build_cut()
	page.hide()
	cut.hide()


func build_page() -> void:
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kicker = tab("", 19, YELLOW)
	page.add_child(kicker)
	kicker.position = Vector2(44, 38)
	kicker.rotation = -.02
	caption.fill = YELLOW
	caption.corner = 3
	page.add_child(caption)
	caption.position = Vector2(42, 78)
	caption.size = Vector2(640, 96)
	caption.rotation = -.012
	caption_text = words("", 27, INK, hand)
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(caption_text)
	caption_text.position = Vector2(20, 12)
	caption_text.size = Vector2(600, 72)
	nameplate = words("", 96, YELLOW, loud, 18)
	page.add_child(nameplate)
	nameplate.position = Vector2(64, 40)
	nameplate.rotation = -.045
	role = tab("", 20, PAPER)
	page.add_child(role)
	role.position = Vector2(78, 162)
	role.rotation = -.045
	page.add_child(speech)
	speech.position = Vector2(760, 70)
	speech.size = Vector2(520, 130)
	speech_text = words("", 26, INK, hand)
	speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech.add_child(speech_text)
	speech_text.position = Vector2(24, 12)
	speech_text.size = Vector2(472, 106)
	page.add_child(badge)
	badge.size = Vector2(330, 170)
	badge.rotation = -.07
	badge_text = words("", 40, INK, loud)
	badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_text)
	badge_text.size = badge.size
	power_box.fill = PAPER
	power_box.corner = 3
	page.add_child(power_box)
	power_text = words("", 23, INK, hand)
	power_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_box.add_child(power_text)
	hint = tab("", 16, PAPER)
	page.add_child(hint)


func build_cut() -> void:
	# A second small view of the same world, pointed at whoever is talking.
	booth.size = Vector2i(256, 256)
	booth.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(booth)
	booth.add_child(lens)
	lens.fov = 30.
	# Name tags and promise notes live on layer 2, which this lens does not see.
	lens.cull_mask = 1
	var frame := Balloon.new()
	frame.fill = INK
	frame.corner = 3
	cut.add_child(frame)
	frame.size = Vector2(166, 166)
	frame.position = Vector2(0, 0)
	frame.rotation = -.035
	shot.texture = booth.get_texture()
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	var look := ShaderMaterial.new()
	look.shader = print_shader("", "UV", "TEXTURE_PIXEL_SIZE")
	shot.material = look
	frame.add_child(shot)
	shot.position = Vector2(7, 7)
	shot.size = Vector2(152, 152)
	cut_name = tab("", 19, YELLOW)
	frame.add_child(cut_name)
	cut_name.position = Vector2(6, 136)
	cut.add_child(cut_balloon)
	cut_balloon.position = Vector2(196, 18)
	cut_balloon.size = Vector2(390, 112)
	cut_balloon.tail = Vector2(-34, 66)
	cut_text = words("", 24, INK, hand)
	cut_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cut_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cut_balloon.add_child(cut_text)
	cut_text.position = Vector2(18, 8)
	cut_text.size = Vector2(354, 96)


## How strongly the printed look covers the picture, 0 to 1. It fades, it does not snap.
func ink(strength: float) -> void:
	ink_goal = strength


func place_page() -> void:
	var area := get_viewport().get_visible_rect().size
	badge.position = Vector2(34, area.y - 330)
	power_box.position = Vector2(350, area.y - 282)
	power_box.size = Vector2(minf(680, area.x - 400), 92)
	power_text.position = Vector2(20, 8)
	power_text.size = power_box.size - Vector2(40, 16)
	speech.position = Vector2(area.x - 590, 62)
	hint.reset_size()
	hint.position = Vector2(area.x - hint.size.x - 40, area.y - 62)


## A story page: a yellow caption box with the narration.
func tale(heading: String, line: String, keys: String) -> void:
	page.show()
	for part in [nameplate, role, speech, badge, power_box]:
		part.hide()
	for part in [kicker, caption]:
		part.show()
	kicker.text = heading
	caption_text.text = line
	hint.text = keys
	place_page()
	punch(caption)
	ink(1.)


## A character page: name, trade, their own words in a balloon and the one thing only they can do.
func meet(who: String, trade: String, line: String, power: String, means: String, tint: Color, mouth: Vector2, keys: String) -> void:
	page.show()
	for part in [kicker, caption]:
		part.hide()
	for part in [nameplate, role, speech, badge, power_box]:
		part.show()
	nameplate.text = who
	nameplate.add_theme_color_override("font_color", tint)
	role.text = trade
	speech_text.text = line
	badge_text.text = power + "!"
	badge.fill = tint.lightened(.25)
	power_text.text = means
	hint.text = keys
	place_page()
	speech.tail = mouth - speech.position
	speech.queue_redraw()
	badge.queue_redraw()
	punch(nameplate)
	punch(speech)
	punch(badge)
	ink(1.)


func close_page() -> void:
	page.hide()


func punch(part: Control) -> void:
	part.pivot_offset = part.size * .5
	part.scale = Vector2(.6, .6)
	var tween := create_tween()
	tween.tween_property(part, "scale", Vector2(1.06, 1.06), .14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(part, "scale", Vector2.ONE, .08)


## A lettered sound word at a place on the screen: STEAL! GOAL! PAID!
func pop(word: String, at: Vector2, tint: Color, big: bool = false) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pops.add_child(holder)
	var area := get_viewport().get_visible_rect().size
	recent = recent.filter(func(old): return clock - old[0] < .8)
	for old in recent:
		if absf(old[1].x - at.x) < 190. and absf(old[1].y - at.y) < 44.:
			at.y -= 52.
	recent.append([clock, at])
	holder.position = at.clamp(Vector2(120, 130), area - Vector2(120, 150))
	holder.rotation = randf_range(-.2, .2)
	var label := words(word, 74 if big else 40, tint, loud, 16 if big else 11)
	if big:
		var star := Burst.new()
		star.fill = PAPER
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.size = Vector2(label.get_minimum_size().x + 150, 190)
		star.position = -star.size * .5
		holder.add_child(star)
	holder.add_child(label)
	label.position = -label.get_minimum_size() * .5
	holder.scale = Vector2(.2, .2)
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector2(1.2, 1.2), .13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", Vector2.ONE, .08)
	tween.tween_interval(1.15 if big else .6)
	tween.tween_property(holder, "modulate:a", 0., .25)
	tween.parallel().tween_property(holder, "position:y", holder.position.y - 30., .25)
	tween.tween_callback(holder.queue_free)


## Queue a small panel: the speaker's face, their name and what they are saying.
func say(doll: Node3D, height: float, who: String, line: String, tint: Color) -> void:
	if line == "":
		return
	waiting.append({"doll": doll, "height": height, "who": who, "line": line, "tint": tint})
	while waiting.size() > 3:
		waiting.pop_front()


func quiet() -> void:
	waiting.clear()
	showing = 0.
	cut.hide()
	booth.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for old in pops.get_children():
		old.queue_free()


func _process(dt: float) -> void:
	clock += dt
	ink_now = move_toward(ink_now, ink_goal, dt * 5.)
	wash.visible = ink_now > .01
	wash_look.set_shader_parameter("amount", ink_now)
	var area := get_viewport().get_visible_rect().size
	if showing > 0.:
		showing -= dt
		# Slide up from the bottom edge, hold, and drop away.
		var rise := smoothstep(0., .18, 2.5 - showing) * smoothstep(0., .2, showing)
		# Right of centre, clear of the line that says who has the star.
		cut.position = Vector2(area.x * .5 - 190., area.y - 76. - 178. * rise)
		if is_instance_valid(subject):
			var face := subject.global_position + Vector3(0, subject_height, 0)
			# Stand in front of the speaker, a little to one side.
			var turn: float = subject.rotation.y + .32
			lens.global_position = face + Vector3(sin(turn), .06, cos(turn)) * 2.0
			lens.look_at(face)
		if showing <= 0.:
			cut.hide()
			booth.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif not waiting.is_empty():
		var next: Dictionary = waiting.pop_front()
		subject = next.doll
		subject_height = next.height
		cut_name.text = next.who
		cut_name.add_theme_color_override("font_color", next.tint)
		cut_text.text = next.line
		cut_balloon.queue_redraw()
		booth.world_3d = get_viewport().find_world_3d()
		booth.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		showing = 2.5
		cut.position = Vector2(area.x * .5 - 190., area.y)
		cut.show()
