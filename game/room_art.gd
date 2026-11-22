extends Node3D
## Visual stage only. All physical decisions belong to FlightSim.
const PADS = [Vector3(-4.3, 0, .3), Vector3(0, 0, -1.55), Vector3(4.3, 0, .3)]
const PAD_TINT = [Color("#eeb978"), Color("#8be7d3"), Color("#99c9e9")]
var mats: Dictionary = {}
const DockLife = preload("res://game/dock_life.gd")
var life = DockLife.new()
var calf: Node3D
var swimmer: Node3D
var swim_time := 0.0
var winch_cables: Array[MeshInstance3D] = []
var egg: Node3D
var tape: Node3D
var markers: Array = []
var dust: Array = []
var sun: DirectionalLight3D
var world_env: Environment
## The sky that lights the scene and shows in reflections. The visible sky is a mesh in the harbor.
var sky_paint := ProceduralSkyMaterial.new()
## Cool light from the camera side, so faces turned towards us are not lost against the sunset.
var fill := DirectionalLight3D.new()
var window: MeshInstance3D
var projected: Array = []
var training_buoy: Node3D
var practice := false
var tow_line: MeshInstance3D
var deflector: MeshInstance3D


func metal(
	id: String, shade: String, rough: float = .5, metallic: float = .0, light: float = .0
) -> StandardMaterial3D:
	if mats.has(id):
		return mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(shade)
	m.roughness = rough
	m.metallic = metallic
	if light > 0:
		m.emission_enabled = true
		m.emission = Color(shade)
		m.emission_energy_multiplier = light
	mats[id] = m
	return m


func draw(p: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var i := MeshInstance3D.new()
	i.mesh = mesh
	i.material_override = mat
	p.add_child(i)
	i.position = at
	return i


func box(p: Node3D, at: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return draw(p, b, at, m)


func ball(p: Node3D, at: Vector3, radii: Vector3, m: Material) -> MeshInstance3D:
	var b := SphereMesh.new()
	b.radius = 1
	b.height = 2
	b.radial_segments = 36
	b.rings = 18
	var obj := draw(p, b, at, m)
	obj.scale = radii
	return obj


func tube(p: Node3D, a: Vector3, b: Vector3, rad: float, m: Material) -> MeshInstance3D:
	var cy := CylinderMesh.new()
	cy.top_radius = rad
	cy.bottom_radius = rad
	cy.height = a.distance_to(b)
	cy.radial_segments = 12
	var obj := draw(p, cy, (a + b) * .5, m)
	obj.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return obj


func torus(p: Node3D, at: Vector3, inner: float, outer: float, m: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 64
	t.ring_segments = 12
	return draw(p, t, at, m)


func placard(p: Node3D, words: String, at: Vector3, tint: Color, size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	l.text = words
	l.font_size = size
	l.pixel_size = .0055
	l.modulate = tint
	l.outline_size = 3
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	p.add_child(l)
	l.position = at
	return l


func build(arena: bool = false) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#091628")
	# Ambient light and reflections come from a sunset sky, so metal and skin pick up its colours.
	sky_paint.sky_top_color = Color("#4a4f8c")
	sky_paint.sky_horizon_color = Color("#ffb07a")
	sky_paint.ground_horizon_color = Color("#8a5a5a")
	sky_paint.ground_bottom_color = Color("#1d2433")
	sky_paint.sun_angle_max = 18.
	var sky := Sky.new()
	sky.sky_material = sky_paint
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = .7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = .92
	# Bright things bleed light, like a night game under lamps.
	# Only truly bright things bloom: lamps, the star, neon. The sky stays crisp.
	env.glow_enabled = true
	env.glow_intensity = .7
	env.glow_strength = 1.
	env.glow_bloom = 0.
	env.glow_hdr_threshold = 1.35
	env.glow_hdr_scale = 2.
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in 7:
		env.set_glow_level(level, [0., .6, .8, .6, .35, 0., 0.][level])
	# Contact shadows where feet, crates and rails meet the deck.
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	# The far harbor fades into the haze at the horizon. The court stays clear.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 45.
	env.fog_depth_end = 260.
	env.fog_density = .4
	env.fog_light_color = Color("#f0a27e")
	env.fog_sky_affect = 0.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	var world := WorldEnvironment.new()
	world.environment = env
	world_env = env
	add_child(world)
	sun = DirectionalLight3D.new()
	add_child(sun)
	# A low, warm sun behind the far rail, the same one that sets in the sky.
	sun.rotation_degrees = Vector3(-27, -157, 0)
	sun.light_color = Color("#ffb67a")
	sun.light_energy = 1.35
	sun.light_angular_distance = .8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 48
	add_child(fill)
	fill.rotation_degrees = Vector3(-34, 8, 0)
	fill.light_color = Color("#9fb6ff")
	fill.light_energy = .55
	fill.shadow_enabled = false
	var iron := metal("iron", "#30404b", .52, .48)
	var dark := metal("dark", "#202d39", .55, .52)
	var brass := metal("brass", "#ac8050", .39, .60)
	var teal := metal("strip", "#85e9db", .35, .2, 1.0)
	var tungsten := metal("worklamps", "#ffce8c", .29, .18, 2.6)
	var worn := ShaderMaterial.new()
	worn.shader = preload("res://game/shaders/deck_steel.gdshader")
	worn.set_shader_parameter("steel_color", preload("res://assets/room/steel_Diffuse.jpg"))
	worn.set_shader_parameter("steel_normal", preload("res://assets/room/steel_nor_gl.jpg"))
	worn.set_shader_parameter("arm", preload("res://assets/room/steel_arm.jpg"))
	box(self, Vector3(0, -.38, 2.05), Vector3(32, .65, 12.9), dark)
	box(self, Vector3(0, -.026, 1.95), Vector3(32, .065, 12.5), worn)
	for row in 5:
		for col in 12:
			var p := Vector3(-6.89 + float(col) * 1.25, -.024, -2.32 + float(row) * 1.15)
			if row % 2 == 0 and col % 2 == 0:
				for side in [-1, 1]:
					box(self, p + Vector3(side * .49, .038, .44), Vector3(.055, .012, .043), brass)
	for axis in [-1, 1]:
		box(self, Vector3(0, .027, 1.82 + axis * .12), Vector3(15, .043, .05), brass)
		box(self, Vector3(0, -.12, 3.16 + axis * .06), Vector3(15, .24, .041), iron)
	for n in 34:
		box(self, Vector3(-7.25 + n * .44, .042, 2.74), Vector3(.23, .023, .065), brass).rotation.y = -.33
	for z in 0 if arena else 3:
		var p: Vector3 = PADS[z]
		var ringmat := metal("p" + str(z), PAD_TINT[z].to_html(false), .4, .17, .7)
		torus(self, p + Vector3.UP * .06, .80, .86, ringmat)
		torus(self, p + Vector3.UP * .045, 1.0, 1.04, brass)
		var ticks := []
		for k in 3:
			var dot := box(self, p + Vector3((k - 1) * .23, .09, .89), Vector3(.15, .08, .1), iron)
			ticks.append(dot)
		markers.append(ticks)
		placard(self, ["DECK", "CEILING", "HATCH"][z], p + Vector3(0, .19, 1.11), PAD_TINT[z], 32)
	# Tilted structural ribs frame a continuous view of space.
	for x in [-8.2, -5.9, 5.9, 8.2]:
		tube(self, Vector3(x, -.12, -2.92), Vector3(x * .90, 4.75, -3.38), .14, iron)
		tube(self, Vector3(x * .90, 4.75, -3.38), Vector3(x * .76, 5.95, -1.95), .13, brass)
	for h in [.34, 4.78]:
		tube(self, Vector3(-8, h, -3.25), Vector3(8, h, -3.25), .079, iron)
	for x in [-6.65, 6.65]:
		crate(Vector3(x, .0, -1.91), Vector3(1.07, .63, .85))
		crate(Vector3(x + .10, .64, -1.89), Vector3(.80, .49, .68))
		tube(self, Vector3(x, 2.67, -2.98), Vector3(x * .90, 2.67, -3.25), .042, iron)
		box(self, Vector3(x, 2.65, -2.93), Vector3(.25, .67, .15), iron)
		box(self, Vector3(x, 2.65, -2.82), Vector3(.105, .50, .045), tungsten)
		for j in [-1, 0, 1]:
			box(self, Vector3(x, 2.65 + j * .18, -2.785), Vector3(.147, .022, .036), brass)
	crate(Vector3(-6.67, 0, 1.22), Vector3(.89, .55, .77))
	crate(Vector3(6.92, 0, 1.31), Vector3(.87, .49, .69))
	var caution := metal("rail ochre", "#a47837", .57, .46)
	for x in [-7.05, -5.3, -3.3, -1.53, 1.53, 3.30, 5.30, 7.05]:
		tube(self, Vector3(x, .03, -2.63), Vector3(x, 1.09, -2.63), .038, iron)
		box(self, Vector3(x, .08, -2.63), Vector3(.15, .12, .17), brass)
	for span in [[-7.05, -1.53], [1.53, 7.05]]:
		for y in [.53, 1.05]:
			tube(self, Vector3(span[0], y, -2.63), Vector3(span[1], y, -2.63), .036, caution)
	for k in 3:
		tube(
			self,
			Vector3(-7, -.24 + k * .053, 3.49),
			Vector3(7, -.24 + k * .053, 3.49),
			.021,
			brass if k == 1 else iron
		)
	for x in [-6.8, -4.9, -2.2, 2.2, 4.9, 6.8]:
		box(self, Vector3(x, -.20, 3.49), Vector3(.09, .25, .10), iron)
	var hook_x: float = PADS[0].x
	tube(self, Vector3(-7.2, 3.75, -.7), Vector3(-2.7, 3.75, -.7), .079, iron)
	tube(self, Vector3(-6.70, 3.72, -.7), Vector3(-6.70, 2.60, -2.85), .055, brass)
	box(self, Vector3(hook_x, 3.64, -.69), Vector3(.40, .29, .24), brass)
	for s in [-1, 1]:
		winch_cables.append(tube(self, Vector3.ZERO, Vector3.UP, .012, iron))
	for x in [-1.15, 1.15]:
		tube(self, Vector3(x, .11, -2.42), Vector3(x, 2.83, -2.42), .057, brass)
		tube(self, Vector3(x, 2.83, -2.42), Vector3(x * .54, 3.36, -2.41), .055, iron)
	tube(self, Vector3(-.64, 3.36, -2.41), Vector3(.64, 3.36, -2.41), .038, teal)
	batch_fixed_dock()
	window_plate()
	if arena:
		for cable in winch_cables:
			cable.hide()
		return
	for n in 16:
		var d := ball(self, Vector3.ZERO, Vector3.ONE * .039, teal)
		d.hide()
		projected.append(d)
	egg = Node3D.new()
	egg.name = "Living cargo"
	add_child(egg)
	var glass := metal("egg shell", "#c6f5ed", .16, .16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(.70, .94, .96, .23)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ball(egg, Vector3.ZERO, Vector3(.52, .69, .50), glass)
	calf = make_whale(egg, .91)
	calf.rotation.z = .19
	swimmer = make_whale(self, 1.14)
	swimmer.hide()
	var halo := torus(egg, Vector3(0, -.32, 0), .39, .418, brass)
	halo.rotation.z = .18
	var halo2 := torus(egg, Vector3(0, .25, 0), .43, .444, brass)
	halo2.rotation.z = -.19
	egg.scale = Vector3.ONE * 1.32
	for side in [-1, 1]:
		var hoop := torus(egg, Vector3.ZERO, .51, .527, brass)
		hoop.rotation = Vector3(PI * .5, side * .46, 0)
		hoop.scale = Vector3(.86, 1., 1.26)
		tube(egg, Vector3(side * .31, -.44, .12), Vector3(side * .40, .39, .09), .016, iron)
	training_buoy = Node3D.new()
	add_child(training_buoy)
	ball(training_buoy, Vector3.ZERO, Vector3(.27, .35, .27), caution)
	torus(training_buoy, Vector3.ZERO, .259, .279, teal)
	training_buoy.hide()
	tow_line = tube(self, Vector3.ZERO, Vector3.UP, .014, teal)
	tow_line.hide()
	deflector = box(self, Vector3.ZERO, Vector3(.88, .09, .65), caution)
	deflector.rotation.z = .24
	deflector.hide()
	tape = Node3D.new()
	add_child(tape)
	box(tape, Vector3.ZERO, Vector3(.35, .12, .25), brass)
	for side in [-1, 1]:
		torus(tape, Vector3(side * .088, .065, 0), .037, .062, iron)
	for n in 8:
		var bit := box(self, Vector3(-3.5 + n, .3, -2.18), Vector3(.065, .024, .045), brass)
		dust.append(bit)


func crate(foot: Vector3, size: Vector3) -> void:
	var shell := metal("crate umber", "#674f43", .76, .32)
	shell.albedo_color = Color("#b8a080")
	shell.albedo_texture = preload("res://assets/room/steel_Diffuse.jpg")
	shell.uv1_triplanar = true
	shell.uv1_scale = Vector3.ONE * .76
	var cap := metal("corner steel", "#737571", .48, .47)
	var c := foot + Vector3.UP * size.y * .5
	box(self, c, size, shell)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(
				self,
				c + Vector3(sx * size.x * .46, 0, sz * size.z * .46),
				Vector3(.07, size.y + .02, .07),
				cap
			)
		for sy in [-1, 1]:
			box(
				self,
				c + Vector3(sx * size.x * .31, sy * size.y * .475, 0),
				Vector3(.075, .04, size.z + .04),
				cap
			)
		box(
			self,
			c + Vector3(sx * size.x * .28, .028, size.z * .53),
			Vector3(.078, .127, .034),
			mats.brass
		)
	box(
		self,
		c + Vector3(0, .07, size.z * .515),
		Vector3(size.x * .29, .073, .014),
		metal("cargo stencil", "#a29979", .83)
	)
	for side in [-1, 1]:
		tube(
			self,
			c + Vector3(side * size.x * .33, -size.y * .35, size.z * .51),
			c + Vector3(0, -size.y * .11, size.z * .51),
			.014,
			cap
		)
	var stamp := placard(self, "N-72", c + Vector3(0, -.03, size.z * .519), Color("#e0cfac"), 21)
	stamp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	stamp.pixel_size = .0032
	stamp.outline_size = 1


func batch_fixed_dock() -> void:
	# Fixed deck plates, ribs, rail fasteners and crates share a draw surface per finish.
	# Vote markers and winch cables remain individual meshes because gameplay changes them.
	var dynamic: Array = winch_cables.duplicate()
	for lane in markers:
		dynamic.append_array(lane)
	var batches: Dictionary = {}
	for child in get_children():
		if not child is MeshInstance3D or child in dynamic:
			continue
		var material: Material = child.material_override
		if not batches.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[material] = surface
		var surface: SurfaceTool = batches[material]
		for n in child.mesh.get_surface_count():
			surface.append_from(child.mesh, n, child.transform)
		remove_child(child)
		child.queue_free()
	for material in batches:
		draw(self, batches[material].commit(), Vector3.ZERO, material)


func window_plate() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/shaders/nursery_window.gdshader")
	mat.set_shader_parameter("plate", preload("res://assets/room/nursery_window.webp"))
	var view := Vector3(0, 3.77, 10.9)
	var direction := (Vector3(0, 1.26, -.60) - view).normalized()
	var plane := QuadMesh.new()
	plane.size = Vector2(54.8, 30.82)
	window = draw(self, plane, view + direction * 36., mat)
	window.look_at(view, Vector3.UP, true)
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(life)
	life.build(self, mat)


func make_whale(parent: Node3D, length: float) -> Node3D:
	var w := Node3D.new()
	parent.add_child(w)
	var skin := metal("whale", "#56687d", .5, .16)
	var belly := metal("throat", "#9faeaf", .55, .04)
	var sections = [
		[-.49, .035, .048],
		[-.45, .092, .116],
		[-.36, .132, .158],
		[-.23, .143, .17],
		[-.02, .128, .15],
		[.17, .094, .105],
		[.31, .050, .058],
		[.43, .022, .033],
		[.48, .014, .02]
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for q in sections:
		var row: Array = []
		for j in 24:
			var a := TAU * j / 24.0
			row.append(Vector3(q[0], sin(a) * q[1] + .02 * sin(q[0] * 7.0), cos(a) * q[2]) * length)
		rows.append(row)
	for n in rows.size() - 1:
		for j in 24:
			var k := (j + 1) % 24
			for v in [
				rows[n][j], rows[n + 1][j], rows[n][k], rows[n][k], rows[n + 1][j], rows[n + 1][k]
			]:
				st.add_vertex(v)
	st.generate_normals()
	var skin2 := ShaderMaterial.new()
	skin2.shader = preload("res://game/shaders/calf_skin.gdshader")
	draw(w, st.commit(), Vector3.ZERO, skin2)
	for s in [-1, 1]:
		var p := ball(
			w, Vector3(.02, -.115, s * .119) * length, Vector3(.14, .024, .043) * length, belly
		)
		p.rotation.z = -.60
		p.rotation.y = s * .66
		var fluke := ball(
			w, Vector3(.456, -.005, s * .077) * length, Vector3(.075, .016, .103) * length, skin
		)
		fluke.rotation.y = -s * .57
		fluke.name = "FlukeLeft" if s < 0 else "FlukeRight"
		var eye_pos := Vector3(-.33, .013, s * .155) * length
		ball(w, eye_pos, Vector3.ONE * .020 * length, metal("eye rim", "#a6a69a", .4))
		ball(
			w,
			eye_pos + Vector3(0, 0, s * .011) * length,
			Vector3.ONE * .012 * length,
			metal("whale eye", "#152937", .18, .20)
		)
		for jj in 4:
			var x: float = -.385 + jj * .032
			tube(
				w,
				Vector3(x, -.044, s * .130) * length,
				Vector3(x + .022, -.081, s * .116) * length,
				.0028 * length,
				belly
			)
	return w


func loc(z: int) -> Vector3:
	return PADS[z] + Vector3(0, 1.20, 0)


func sync(s) -> void:
	var p: Vector3 = loc(s.egg_zone)
	if not s.flight.is_empty():
		var f: Dictionary = s.flight
		p = Vector3(f.pos) * .01
	elif not s.dwell.is_empty():
		var landing: Vector2i = s.arrival_point(s.dwell.cargo)
		p = Vector3(landing.x * .01, 1.2, landing.y * .01)
	for n in winch_cables.size():
		var cable := winch_cables[n]
		var side := float(2 * n - 1)
		var upper := Vector3(PADS[0].x + side * .13, 3.60, -.64)
		var lower := (
			upper + Vector3(0, -.19, 0) if s.phase > 0 else p + Vector3(side * .26, .58, -.03)
		)
		var down := lower - upper
		cable.position = (upper + lower) * .5
		cable.scale.y = down.length()
		cable.quaternion = Quaternion(Vector3.UP, down.normalized())
	egg.position = p
	egg.rotation.z = sin(float(s.tick) * .024) * .055
	egg.visible = not practice and not (s.ending in ["The herd answers", "The calf answers"])
	training_buoy.visible = practice
	training_buoy.position = p
	tow_line.visible = not s.flight.is_empty() and s.flight.slow
	if tow_line.visible:
		var xy: Vector2i = s.seats[0].pos
		var a := Vector3(xy.x * .01, .99, xy.y * .01)
		var delta := p - a
		tow_line.position = (a + p) * .5
		tow_line.scale.y = delta.length()
		tow_line.quaternion = (
			Quaternion(Vector3.UP, delta.normalized())
			if delta.length() > .001
			else Quaternion.IDENTITY
		)
	deflector.visible = not s.flight.is_empty() and s.flight.banked
	if deflector.visible:
		var xy: Vector2i = s.seats[1].pos
		deflector.position = Vector3(xy.x * .01, .67, xy.y * .01 + .22)
	tape.visible = s.reel != -2 and s.reel != 5
	if s.reel == -1:
		tape.position = PADS[1] + Vector3(.32, .20, .27)
	elif s.reel >= 0 and s.reel < 5:
		var c: Vector2i = s.seats[s.reel].pos
		tape.position = Vector3(c.x * .01 + .2, 1.08, c.y * .01)
	tape.rotation.y = float(s.tick) * .014
	for z in 3:
		var count := 0
		for actor in s.seats:
			if actor.vote == z:
				count += 1
		for k in 3:
			markers[z][k].material_override = mats["p" + str(z)] if k < count else mats.iron
	for k in dust.size():
		dust[k].position.y = (
			.20 + (.32 + .16 * sin(s.tick * .028 + k)) * (1 if s.gravity == 1 else 0)
		)
	for n in projected.size():
		var visible_: bool = (
			not s.flight.is_empty()
			and (s.forecast_until > s.tick or (s.difficulty == 1 and s.visible_approach()))
		)
		projected[n].visible = visible_
		if visible_:
			var sample: Dictionary = s.flight.duplicate()
			var t := float(n + 1) / 17.
			s.Cargo.advance(sample, int(lerpf(sample.anchor_tick, sample.end, t)))
			projected[n].position = Vector3(sample.pos) * .01


func animate_dock(dt: float, sim) -> void:
	life.update(dt, sim, practice)
	calf.rotation = Vector3(
		.07 * sin(life.seconds * .63),
		.20 * sin(life.seconds * .81),
		.19 + .08 * sin(life.seconds * .97)
	)
	calf.position.y = .035 * sin(life.seconds * .76)
	for fluke in ["FlukeLeft", "FlukeRight"]:
		calf.get_node(fluke).rotation.z = .16 * sin(life.seconds * 2.1)
	var delivered: bool = sim.ending in ["The herd answers", "The calf answers"]
	if not delivered:
		swim_time = 0.0
		swimmer.hide()
		return
	swim_time = minf(swim_time + dt, 7.0)
	var u := swim_time / 7.0
	swimmer.visible = u < 1.0
	var ease := smoothstep(0.0, 1.0, u)
	swimmer.position = Vector3(
		4.3 - 18.0 * ease, 1.2 + 1.85 * sin(u * PI) + 2.1 * u, .30 - 10.0 * u
	)
	swimmer.rotation.z = -.10 * sin(u * TAU)
	for fluke in ["FlukeLeft", "FlukeRight"]:
		swimmer.get_node(fluke).rotation.z = .30 * sin(swim_time * 3.4)


func location(mode: int) -> void:
	life.storm = mode == 1
	var exterior: Texture2D = preload("res://assets/room/nursery_window.webp")
	if mode == 1:
		exterior = preload("res://assets/room/ring_shadow.webp")
	life.plate.set_shader_parameter("plate", exterior)
	life.plate.set_shader_parameter("ring_ice", float(mode == 1))
	life.plate.set_shader_parameter(
		"eye_position", Vector2(.229, .153) if mode == 1 else Vector2(.248, .102)
	)
