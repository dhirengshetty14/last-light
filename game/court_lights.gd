extends Node3D
const Game = preload("res://game/star_match.gd")
## A single instanced strip for both sidelines. Each end of the dock keeps the crew's score in lamps.
const COLORS := [Color("#ffc675"), Color("#76dce7")]
var strip := ShaderMaterial.new()
var curtain := ShaderMaterial.new()
var score_lamps := [[], []]
var lit: Array = []
var dark: Material
var last_score := [-1, -1]
var age := 10.
var pulse_length := 1.
var peak := .5


func build(room) -> void:
	dark = room.metal("unlit beacon glass", "#3c4348", .26, .58)
	for side in 2:
		lit.append(room.metal("dock score %d" % side, COLORS[side].to_html(false), .22, .24, 2.))
		var x := Game.RING if side == 0 else -Game.RING
		for n in 3:
			var at := Vector3(x + (n - 1) * .31, .40, -Game.BOUNDS.y - .48)
			room.box(self, at, Vector3(.26, .61, .18), room.mats.iron)
			var lamp = room.box(self, at + Vector3(0, .12, .105), Vector3(.17, .24, .05), dark)
			score_lamps[side].append(lamp)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.30, .024, .070)
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = mesh
	# One lamp roughly every 75 centimetres along each sideline.
	var each := int(round((Game.RING * 2. + .1) / .77)) + 1
	var edge := Game.BOUNDS.y + .27
	group.instance_count = each * 2
	for i in each * 2:
		var x := lerpf(-Game.RING - .05, Game.RING + .05, float(i % each) / (each - 1.))
		group.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(x, .064, -edge if i < each else edge))
		)
	strip.shader = preload("res://game/shaders/court_signal.gdshader")
	var rail := MultiMeshInstance3D.new()
	rail.multimesh = group
	rail.material_override = strip
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rail)
	var sail := QuadMesh.new()
	sail.size = Vector2(38. * Game.RING / Game.OLD_RING, 4.1)
	curtain.shader = preload("res://game/shaders/harbor_aurora.gdshader")
	var sky = room.draw(self, sail, Vector3(0, 5.4, -12.8 * Game.BOUNDS.y / Game.OLD_BOUNDS.y), curtain)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func signal_crew(team: int, strong: bool) -> void:
	age = 0.
	pulse_length = 1.45 if strong else .85
	peak = 1. if strong else .52
	strip.set_shader_parameter("tint", COLORS[team])
	strip.set_shader_parameter("direction", 1. if team == 0 else -1.)


func sync(dt: float, scores: Array, surge: bool, seconds: float, reduced: bool) -> void:
	for side in 2:
		if last_score[side] == scores[side]:
			continue
		last_score[side] = scores[side]
		for n in 3:
			score_lamps[side][n].material_override = lit[side] if n < scores[side] else dark
	age += dt
	var progress := clampf(age / pulse_length, 0., 1.)
	strip.set_shader_parameter("progress", progress)
	strip.set_shader_parameter("strength", peak * (1. - progress))
	strip.set_shader_parameter("still", reduced)
	curtain.set_shader_parameter("clock", seconds)
	curtain.set_shader_parameter("intensity", .54 if surge else 0.)
