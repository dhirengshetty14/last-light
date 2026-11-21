extends Node3D
const FILES = ["nell", "rafi", "pip", "morrow", "zip"]
const TINT = [
	Color("#66d4bd"), Color("#d29aac"), Color("#f6b16c"), Color("#bcabed"), Color("#f2d5a1")
]
var index := 0
var figure: Node3D
var anim: AnimationPlayer
var face: MeshInstance3D
var controls: Array = []
var optics: Array = []
var pip_display: MultiMesh
var display_pose: String = ""
var display_blink := false
var iris_lenses: Array[MeshInstance3D] = []
var tag: Label3D
var playing := ""
var shapes: Dictionary = {}
var gear: Node3D


func gear_part(p: Node3D, m: Mesh, at: Vector3, shade: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = shade
	mat.roughness = .52
	mat.metallic = .46
	var part := MeshInstance3D.new()
	part.mesh = m
	part.material_override = mat
	p.add_child(part)
	part.position = at
	return part


func equipment() -> void:
	# These garments use stage metres. Attachments move with the same performer throughout play and close-ups.
	var collar := TorusMesh.new()
	collar.inner_radius = .123
	collar.outer_radius = .162
	collar.rings = 40
	collar.ring_segments = 8
	gear_part(figure, collar, Vector3(0, 1.445 if index == 0 else 1.49, .012), Color("#9b8d76")).scale.z = .88
	for side in [-1, 1]:
		var web := BoxMesh.new()
		web.size = Vector3(.044, .36, .025)
		var strap := gear_part(figure, web, Vector3(side * .115, 1.22, .111), Color("#57483a"))
		strap.rotation.z = side * .16
		var pad := BoxMesh.new()
		pad.size = Vector3(.10, .10, .027)
		gear_part(figure, pad, Vector3(side * .11, .51, .065), Color("#977d62"))
		var latch := BoxMesh.new()
		latch.size = Vector3(.049, .042, .031)
		gear_part(figure, latch, Vector3(side * .116, 1.24, .134), Color("#aa8b57"))
	var badge := CylinderMesh.new()
	badge.top_radius = .046
	badge.bottom_radius = .046
	badge.height = .01
	badge.radial_segments = 16
	var emblem := gear_part(figure, badge, Vector3(-.065, 1.29, .141), Color("#ad8a51"))
	emblem.rotation.x = PI * .5
	var pouch := BoxMesh.new()
	pouch.size = Vector3(.13, .15, .07)
	gear_part(figure, pouch, Vector3(-.191, .91, .075), Color("#7c614a"))
	gear = Node3D.new()
	figure.add_child(gear)
	if index == 0:
		gear.position = Vector3(.22, .92, .01)
		for k in 7:
			var hoop := TorusMesh.new()
			hoop.inner_radius = .062
			hoop.outer_radius = .085
			var part := gear_part(gear, hoop, Vector3(0, (k - 3) * .014, 0), Color("#bf884d"))
			part.rotation.z = PI * .5
		for side in [-1, 1]:
			var disk := CylinderMesh.new()
			disk.top_radius = .102
			disk.bottom_radius = .102
			disk.height = .02
			gear_part(gear, disk, Vector3(side * .06, 0, 0), Color("#59686b")).rotation.z = PI * .5
	else:
		gear.position = Vector3(-.18, 1.14, -.15)
		var plate := BoxMesh.new()
		plate.size = Vector3(.34, .56, .056)
		gear_part(gear, plate, Vector3(-.065, .02, 0), Color("#5c6260"))
		for k in 3:
			var stripe := BoxMesh.new()
			stripe.size = Vector3(.25, .048, .012)
			gear_part(gear, stripe, Vector3(-.065, -.13 + k * .13, -.036), Color("#d1a455")).rotation.z = -.25


func setup(i: int, show_name: bool = true) -> void:
	index = i
	var scene: PackedScene = load("res://assets/cast/" + FILES[i] + ".glb")
	figure = scene.instantiate()
	add_child(figure)
	if i < 2:
		equipment()
	# The FBX humans face +Z after glTF import. The machines face +Z as well.
	var animation_nodes := figure.find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		anim = animation_nodes[0]
		for key in anim.get_animation_list():
			if str(key) != "RESET":
				anim.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	for n in figure.find_children("*", "MeshInstance3D", true, false):
		if n.mesh is ArrayMesh and n.mesh.get_blend_shape_count() > 0:
			face = n
			for k in n.mesh.get_blend_shape_count():
				shapes[str(n.mesh.get_blend_shape_name(k))] = k
			break
	for part in figure.find_children("*", "Node3D", true, false):
		var nm := str(part.name).to_lower()
		if nm.begins_with("amber matrix led") or nm.begins_with("white expression bar"):
			optics.append([part, part.position, part.scale, part.rotation])
		if i == 3 and nm.begins_with("casthead"):
			make_goggles(part)
		if (
			nm.begins_with("casthead")
			or nm.begins_with("pivotarm")
			or nm.begins_with("pivotleg")
			or nm.begins_with("reelspindle")
			or nm.begins_with("netpole")
		):
			controls.append([part, part.rotation, nm])
	if i == 2 and not optics.is_empty():
		var first: MeshInstance3D = optics[0][0]
		pip_display = MultiMesh.new()
		pip_display.transform_format = MultiMesh.TRANSFORM_3D
		pip_display.mesh = first.mesh
		pip_display.instance_count = optics.size()
		var display := MultiMeshInstance3D.new()
		display.multimesh = pip_display
		display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		first.get_parent().add_child(display)
		for item in optics:
			item[0].hide()
	tag = Label3D.new()
	tag.font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	tag.text = FILES[i].capitalize()
	tag.font_size = 36
	tag.pixel_size = .0056
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = TINT[i]
	tag.outline_size = 8
	tag.no_depth_test = true
	tag.position.y = 2.25 if i < 2 else 2.0
	add_child(tag)
	tag.visible = show_name


func make_goggles(head: Node3D) -> void:
	var lens := SphereMesh.new()
	lens.radius = 1.0
	lens.height = 2.0
	lens.radial_segments = 20
	lens.rings = 10
	for side in [-1, 1]:
		var iris := gear_part(head, lens, Vector3(side * .060, .029, .147), Color("#72542c"))
		iris.scale = Vector3(.025, .024, .006)
		var pupil := gear_part(head, lens, Vector3(side * .060, .029, .151), Color("#263339"))
		pupil.scale = Vector3(.014, .014, .005)
		var glint := gear_part(
			head, lens, Vector3(side * .060 - .004, .036, .156), Color("#e0dbc7")
		)
		glint.scale = Vector3(.004, .004, .002)
		iris_lenses.append(pupil)


func machine_expression(state: String, t: float) -> void:
	var blink := 1. - smoothstep(.035, .14, absf(fposmod(t + index * .40, 4.37) - 2.51))
	if index == 2 and display_pose == state and display_blink == (blink >= .70):
		return
	display_pose = state
	display_blink = blink >= .70
	for n in optics.size():
		var item: Array = optics[n]
		var lamp: Node3D = item[0]
		var origin: Vector3 = item[1]
		var side := signf(origin.x)
		if index == 2:
			var x: float = (absf(origin.x) - .079) / .01332
			var row: float = (origin.y - .050) / .01332
			var lit := true
			if state == "Relief":
				lit = absf(row - (1.4 - absf(x) * .85)) < .82
			elif state == "Commit":
				lit = row < .55 + x * .40
			elif state == "Alarm":
				lit = absf(x) > 1.2 or absf(row) > 1.2
			var matrix: Transform3D = lamp.transform
			if not lit or (display_blink and absf(row) >= .51):
				matrix.basis = matrix.basis.scaled(Vector3.ONE * .0001)
			pip_display.set_instance_transform(n, matrix)
		elif index == 4:
			lamp.scale = (
				Vector3(item[2])
				* Vector3(
					1.23 if state == "Alarm" else 1.,
					(.53 if state == "Relief" else 1.) * (1. - .87 * blink),
					1.
				)
			)
			lamp.rotation = (
				Vector3(item[3])
				+ Vector3(
					0, 0, side * (.48 if state == "Commit" else -.35 if state == "Relief" else 0.)
				)
			)
	for n in iris_lenses.size():
		var lens := iris_lenses[n]
		var size := .010 if state == "Alarm" else .017 if state == "Relief" else .014
		lens.scale = Vector3(size, size * (1. - .88 * blink), .005)
		lens.position.x = (-.060 if n == 0 else .060) + .003 * sin(t * 1.15)


func express(state: String, t: float, walking: bool = false) -> void:
	if index >= 2:
		machine_expression(state, t)
	var clip := "Walk" if walking and state == "Idle" else state
	if gear and index == 1:
		gear.rotation.y = lerp_angle(gear.rotation.y, 1.26 if state == "Commit" else -.15, .22)
	if anim and clip != playing and anim.has_animation(clip):
		anim.play(clip, .14)
		playing = clip
	if face:
		var blink := clampf((absf(fmod(t + index * .57, 4.2) - 2.1) - 1.96) * 8., 0., 1.)
		var targets = {
			"AK_03_BrowInnerUp": .72 if state == "Alarm" else 0.0,
			"AK_01_BrowDownLeft": .48 if state == "Commit" else 0.0,
			"AK_02_BrowDownRight": .42 if state == "Commit" else 0.0,
			"AK_25_JawOpen": .27 if state == "Alarm" else 0.0,
			"AK_44_MouthSmileLeft": .58 if state == "Relief" else 0.0,
			"AK_45_MouthSmileRight": .52 if state == "Relief" else 0.0,
			"AK_09_EyeBlinkLeft": blink,
			"AK_10_EyeBlinkRight": blink
		}
		for key in targets:
			if shapes.has(key):
				face.set_blend_shape_value(shapes[key], targets[key])
	for control in controls:
		var obj: Node3D = control[0]
		var rest: Vector3 = control[1]
		var nm: String = control[2]
		var side: float = -1. if nm.ends_with("l") else 1.
		if nm.begins_with("casthead"):
			obj.rotation = (
				rest
				+ Vector3(
					-.16 if state == "Alarm" else .12 if state == "Commit" else .023 * sin(t * 2.),
					.17 if state == "Alarm" else .035 * sin(t * 1.4),
					.12 if state == "Relief" else 0.
				)
			)
		elif nm.begins_with("pivotarm"):
			obj.rotation = (
				rest
				+ Vector3(
					(
						(sin(t * 9.) * side * .28 if walking else 0.)
						+ (.49 if state == "Commit" else .15 if state == "Alarm" else 0.)
					),
					0,
					side * (-.23 if state == "Alarm" else -.08 if state == "Relief" else 0.)
				)
			)
		elif nm.begins_with("pivotleg"):
			obj.rotation = (
				rest
				+ Vector3(
					sin(t * 9.) * side * (.22 if index == 2 else .31) if walking else 0.,
					0,
					side * .05 if state == "Commit" else 0.
				)
			)
		elif nm.begins_with("reelspindle"):
			obj.rotation = rest + Vector3(0, 0, t * (2. if state == "Commit" else .42))
		else:
			obj.rotation = (
				rest
				+ Vector3(
					.16 if state == "Commit" else 0.,
					0,
					-.20 if state == "Alarm" else .025 * sin(t * 2.)
				)
			)
	figure.position.y = .016 * absf(sin(t * 9.)) if walking else .003 * sin(t * 1.7)
