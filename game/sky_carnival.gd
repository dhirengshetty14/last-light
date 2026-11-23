extends Node3D
## The last night of summer on Saturn, out past the crowd: islands float over the harbor with
## waterfalls pouring off them into the sea, jellyfish rise out of the water and swim up into the
## sky, carnival airships circle, sailing boats tack across the bay and a big wheel turns on the
## pier. Everything here moves on its own clock and reacts to goals. Presentation only: the court
## never reads this node.
const SEA_LEVEL := -2.6
## Where the wheel stands, so the whales can keep clear of its pier.
const WHEEL_AT := Vector3(52., SEA_LEVEL, -74.)
const WHEEL_RADIUS := 10.
const WHEEL_HUB := 12.4
var room
var seconds := 0.
var dusk := 0.
var lights := 1.
var flash := 0.
var flash_tint := Color.WHITE
var islands: Array = []
var island_looks: Array = []
var tree_look := ShaderMaterial.new()
var fall_look := ShaderMaterial.new()
var bow_look := ShaderMaterial.new()
var swarm: Array = []
var jellies := MultiMesh.new()
var jelly_look := ShaderMaterial.new()
var ships: Array = []
var ship_look := ShaderMaterial.new()
var banner_look := ShaderMaterial.new()
var boats: Array = []
var sail_look := ShaderMaterial.new()
var wheel := Node3D.new()
var cars: Array = []
var bulbs := MultiMesh.new()
var bulb_look := ShaderMaterial.new()
var wheel_turn := 0.

const NOISE := """
float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float vnoise3(vec3 p) {
	return mix(vnoise(p.xy + floor(p.z) * 17.13), vnoise(p.xy + (floor(p.z) + 1.0) * 17.13), smoothstep(0.0, 1.0, fract(p.z)));
}
"""


func shade(code: String) -> Shader:
	var s := Shader.new()
	s.code = code.replace("//NOISE", NOISE)
	return s


func quiet(mesh: GeometryInstance3D) -> GeometryInstance3D:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func build(stage) -> void:
	room = stage
	floating_islands()
	jellyfish()
	airships()
	sailing_boats()
	big_wheel()


## A closed skin through oval sections [centre, half-axis, half-axis], with a colour per section.
func loft(st: SurfaceTool, sections: Array, around: int, paint: Array) -> void:
	var rows: Array = []
	for cut in sections:
		var row: Array = []
		for j in around:
			var ang := TAU * j / around
			row.append(cut[0] + cut[1] * cos(ang) + cut[2] * sin(ang))
		rows.append(row)
	for n in rows.size() - 1:
		for j in around:
			var k := (j + 1) % around
			for corner in [[n, j], [n + 1, j], [n, k], [n, k], [n + 1, j], [n + 1, k]]:
				st.set_color(paint[corner[0]])
				st.add_vertex(rows[corner[0]][corner[1]])


## Copy a primitive into a SurfaceTool with one colour on every vertex.
func part(st: SurfaceTool, shape: PrimitiveMesh, where: Transform3D, paint: Color) -> void:
	var arrays := shape.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var turn := where.basis.inverse().transposed()
	for i in order:
		st.set_normal((turn * normals[i]).normalized())
		st.set_uv(uvs[i])
		st.set_color(paint)
		st.add_vertex(where * points[i])


# ------------------------------------------------------------------ floating islands


const ISLAND := """shader_type spatial;
render_mode cull_disabled;
uniform float glow = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_tint : source_color = vec3(1.0);
uniform vec3 grass : source_color = vec3(0.2, 0.85, 0.6);
uniform vec3 rock_a : source_color = vec3(0.85, 0.45, 0.45);
uniform vec3 rock_b : source_color = vec3(0.35, 0.22, 0.48);
uniform vec3 crystal : source_color = vec3(0.4, 1.0, 0.95);
varying vec3 local;
varying float top;
//NOISE
void vertex() {
	local = VERTEX;
	top = COLOR.r;
}
void fragment() {
	float n = vnoise3(local * 0.35);
	float fine = vnoise3(local * 1.7 + 4.0);
	// Layered rock in two colours, each band wavering, darker towards the tip.
	float band = 0.5 + 0.5 * sin(local.y * 1.3 + n * 5.0);
	vec3 rock = mix(rock_a, rock_b, smoothstep(0.25, 0.75, band)) * (0.75 + 0.35 * fine);
	rock *= 0.6 + 0.4 * smoothstep(-30.0, 0.0, local.y);
	// Grass on top, its edge hanging a little way over the rim in uneven fringes.
	float lawn = smoothstep(0.35, 0.65, top + 0.25 * (fine - 0.5) + 0.12 * (n - 0.5));
	vec3 green = grass * (0.7 + 0.5 * fine) + vec3(0.12, 0.05, 0.1) * n;
	vec3 col = mix(rock, green, lawn);
	// Veins of crystal in the rock that glow after dark and flare when someone scores.
	float vein = smoothstep(0.82, 0.9, vnoise3(local * 0.55 + 9.0)) * (1.0 - lawn);
	col = mix(col, crystal * 0.8, vein * 0.6);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.3, vein);
	EMISSION = crystal * vein * (0.35 + 2.6 * glow) + flash_tint * vein * flash * 3.0;
}
"""

const TREE := """shader_type spatial;
uniform float seconds = 0.0;
uniform float glow = 0.0;
varying float leaf;
varying vec3 local;
varying vec3 tint;
//NOISE
void vertex() {
	leaf = COLOR.r;
	local = VERTEX;
	// The crown colour rides in the instance data, so the mesh colour can mark trunk and crown.
	tint = INSTANCE_CUSTOM.rgb;
	float seed = INSTANCE_CUSTOM.a;
	float sway = sin(seconds * 0.9 + seed * 6.0) + 0.4 * sin(seconds * 2.3 + seed * 13.0);
	VERTEX.x += sway * 0.06 * VERTEX.y * VERTEX.y;
	VERTEX.z += cos(seconds * 0.7 + seed * 4.0) * 0.04 * VERTEX.y * VERTEX.y;
}
void fragment() {
	float n = vnoise3(local * 5.0);
	vec3 bark = vec3(0.32, 0.2, 0.16) * (0.8 + 0.3 * n);
	vec3 crown = tint * (0.75 + 0.45 * n);
	ALBEDO = mix(bark, crown, leaf);
	ROUGHNESS = 0.7;
	// Glowing fruit hang in every crown.
	float fruit = smoothstep(0.86, 0.92, vnoise3(local * 9.0 + 3.0)) * leaf;
	EMISSION = (vec3(1.0, 0.85, 0.45) * fruit * (0.4 + 3.0 * glow)) + crown * leaf * glow * 0.25;
}
"""

const FALL := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float seconds = 0.0;
uniform float glow = 0.0;
uniform vec3 tint : source_color = vec3(0.3, 1.0, 0.9);
//NOISE
void fragment() {
	float across = UV.x;
	float down = UV.y;
	float edge = smoothstep(0.0, 0.2, across) * smoothstep(1.0, 0.8, across);
	// Streaks that run down the fall, faster lower down as the water speeds up.
	float run = down * down * 6.0 + down * 2.0;
	float streak = vnoise(vec2(across * 13.0, run - seconds * 2.2));
	float fine = vnoise(vec2(across * 37.0, run * 3.0 - seconds * 5.0));
	float body = 0.4 + 0.45 * streak + 0.3 * fine;
	float a = edge * body * smoothstep(0.0, 0.04, down);
	// Lower down it breaks into spray.
	a *= 1.0 - 0.5 * smoothstep(0.55, 1.0, down) * (1.0 - fine);
	vec3 water = mix(vec3(0.82, 0.93, 1.0), tint, 0.25 + 0.55 * glow) * (0.85 + 0.35 * fine);
	ALBEDO = water * (0.9 + 0.6 * glow * streak);
	ALPHA = clamp(a * 0.9, 0.0, 0.92);
}
"""

const PUFF := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 - smoothstep(0.6, 1.0, r));
}
"""

const RAINBOW := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float day = 1.0;
void fragment() {
	vec2 p = (UV - vec2(0.5, 1.0)) * vec2(2.0, 2.0);
	float r = length(p);
	float t = (r - 0.72) / 0.22;
	vec3 hue = clamp(abs(mod(t * 5.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	float band = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.85, t);
	// It fades out where it meets the sea and the sky.
	float ends = smoothstep(0.02, 0.35, 1.0 - UV.y);
	ALBEDO = hue * band * ends * 0.32 * day;
}
"""


## Rock hanging under a disc of grass, ragged and different for every seed.
func island_mesh(radius: float, depth: float, seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.
	# From the middle of the top, out to the rim and down to the tip: [reach, height].
	var profile := [
		Vector2(0., .5), Vector2(.3, .48), Vector2(.6, .38), Vector2(.84, .22), Vector2(.97, .07),
		Vector2(1., -.03), Vector2(.94, -.14), Vector2(.82, -.3), Vector2(.66, -.48), Vector2(.5, -.64),
		Vector2(.34, -.79), Vector2(.2, -.91), Vector2(.08, -.99), Vector2(0., -1.03)
	]
	var around := 44
	var sections: Array = []
	for i in profile.size():
		var p: Vector2 = profile[i]
		var row: Array = []
		for j in around:
			var c := Vector2(cos(TAU * j / around), sin(TAU * j / around))
			var y := 0.
			var reach := p.x * radius * rim_bump(noise, c)
			if p.y < 0.:
				# Hanging rock: ridged and ragged, with points dripping lower than the rest.
				var drop := -p.y
				reach *= 1. + (.3 * noise.get_noise_3d(c.x * 4., c.y * 4., drop * 2.) + .25 * noise.get_noise_3d(c.x * 1.5 + 3., c.y * 1.5, drop)) * drop
				y = (p.y - .45 * maxf(0., noise.get_noise_3d(c.x * 2.4 + 9., c.y * 2.4, drop * .7)) * drop) * depth
			else:
				y = (p.y + .06 * noise.get_noise_2d(c.x * 3. * p.x + 4., c.y * 3. * p.x)) * radius * .28
			row.append(Vector3(c.x * reach, y, c.y * reach))
		sections.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in sections.size() - 1:
		for j in around:
			var k := (j + 1) % around
			for corner in [[n, j], [n + 1, j], [n, k], [n, k], [n + 1, j], [n + 1, k]]:
				var lawn := 1. if corner[0] <= 4 else (.45 if corner[0] == 5 else 0.)
				st.set_color(Color(lawn, 0, 0))
				st.add_vertex(sections[corner[0]][corner[1]])
	st.index()
	st.generate_normals()
	return st.commit()


func rim_bump(noise: FastNoiseLite, c: Vector2) -> float:
	return 1. + .16 * noise.get_noise_2d(c.x * 1.6, c.y * 1.6)


## A lollipop tree: a trunk and a round crown, one mesh drawn many times in candy colours.
func tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = .09
	trunk.bottom_radius = .16
	trunk.height = 1.6
	trunk.radial_segments = 8
	trunk.rings = 1
	part(st, trunk, Transform3D(Basis.IDENTITY, Vector3(0, .8, 0)), Color(0, 0, 0))
	var crown := SphereMesh.new()
	crown.radius = .85
	crown.height = 1.5
	crown.radial_segments = 14
	crown.rings = 8
	part(st, crown, Transform3D(Basis.IDENTITY, Vector3(0, 2.15, 0)), Color(1, 0, 0))
	part(st, crown, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .6), Vector3(.45, 2.7, .1)), Color(1, 0, 0))
	return st.commit()


## A curtain of water from `top` that shoots out along `out` and falls `drop` metres.
func fall_mesh(top: Vector3, out: Vector3, drop: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := out.cross(Vector3.UP).normalized()
	var rows := 36
	var cols := 4
	var grid: Array = []
	for r in rows + 1:
		var s := float(r) / rows
		var fallen := s * drop
		# Thrown out at the lip, then falling: far less out than down, as real water does.
		var flight := sqrt(2. * fallen / 9.8)
		var centre := top + out * 2.4 * flight + Vector3.DOWN * fallen
		var wide := width * (1. + .9 * s)
		var row: Array = []
		for c in cols + 1:
			var u := float(c) / cols
			var bulge := out * .25 * wide * sin(u * PI)
			row.append([centre + across * (u - .5) * wide + bulge, Vector2(u, s)])
		grid.append(row)
	for r in rows:
		for c in cols:
			for corner in [[r, c], [r + 1, c], [r, c + 1], [r, c + 1], [r + 1, c], [r + 1, c + 1]]:
				var cell: Array = grid[corner[0]][corner[1]]
				st.set_uv(cell[1])
				st.set_normal(-out)
				st.add_vertex(cell[0])
	return st.commit()


func floating_islands() -> void:
	tree_look.shader = shade(TREE)
	fall_look.shader = shade(FALL)
	var crown := tree_mesh()
	var island_code := shade(ISLAND)
	# Spray is soft round puffs that always face the camera.
	var mist_ball := QuadMesh.new()
	mist_ball.size = Vector2(2.2, 2.2)
	var mist_paint := ShaderMaterial.new()
	mist_paint.shader = Shader.new()
	mist_paint.shader.code = PUFF
	mist_ball.material = mist_paint
	var mist_fade := Gradient.new()
	mist_fade.set_color(0, Color(1, 1, 1, 0.))
	mist_fade.add_point(.15, Color(.95, .98, 1., .5))
	mist_fade.set_color(1, Color(.9, .95, 1., 0.))
	var palettes := [
		[Color("#3fe0a0"), Color("#f08a6a"), Color("#5b3a8c"), Color("#6ff7ff")],
		[Color("#b2f25c"), Color("#e7a35a"), Color("#8c3a6a"), Color("#ff7ae0")],
		[Color("#46d7ff"), Color("#f5c26b"), Color("#3c4f9a"), Color("#ffe27a")],
		[Color("#ff9ad5"), Color("#c99ae6"), Color("#344a7a"), Color("#8cffb0")]
	]
	var tree_tints := [
		Color("#ff6fb5"), Color("#ffd04a"), Color("#6ef0c8"), Color("#9a7cff"), Color("#ff8a4a"), Color("#7fe85a")
	]
	# [where, radius, depth, waterfalls (angle from facing us), spin]
	for spec in [
		[Vector3(-66, 21, -142), 15., 24., [.2, -.45], .012],
		[Vector3(-14, 31, -205), 11., 17., [-.15], -.009],
		[Vector3(104, 17, -132), 9., 14., [.35], .015],
		[Vector3(-118, 34, -118), 6., 9., [], -.02],
		[Vector3(18, 44, -150), 4.2, 7., [], .025]
	]:
		var at: Vector3 = spec[0]
		var radius: float = spec[1]
		var depth: float = spec[2]
		var seed_value := islands.size() * 37 + 5
		var paint: Array = palettes[islands.size() % palettes.size()]
		var look := ShaderMaterial.new()
		look.shader = island_code
		look.set_shader_parameter("grass", paint[0])
		look.set_shader_parameter("rock_a", paint[1])
		look.set_shader_parameter("rock_b", paint[2])
		look.set_shader_parameter("crystal", paint[3])
		island_looks.append(look)
		var isle := Node3D.new()
		add_child(isle)
		isle.position = at
		quiet(room.draw(isle, island_mesh(radius, depth, seed_value), Vector3.ZERO, look))
		# A grove of trees on top.
		var grove := MultiMesh.new()
		grove.transform_format = MultiMesh.TRANSFORM_3D
		grove.use_custom_data = true
		grove.mesh = crown
		var count := int(radius * 1.1)
		grove.instance_count = count
		var noise := FastNoiseLite.new()
		noise.seed = seed_value
		noise.frequency = 1.
		for n in count:
			var a := randf() * TAU
			var u := sqrt(randf()) * .72
			var c := Vector2(cos(a), sin(a))
			var ground := (.5 - .5 * u * u) * radius * .28 - .3
			var size := randf_range(.9, 1.8) * clampf(radius / 10., .6, 1.4)
			grove.set_instance_transform(
				n, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * size), Vector3(c.x * u * radius, ground, c.y * u * radius) * Vector3(rim_bump(noise, c), 1, rim_bump(noise, c)))
			)
			var tint: Color = tree_tints[randi() % tree_tints.size()]
			grove.set_instance_custom_data(n, Color(tint.r, tint.g, tint.b, randf()))
		var trees := MultiMeshInstance3D.new()
		trees.multimesh = grove
		trees.material_override = tree_look
		quiet(trees)
		isle.add_child(trees)
		# Waterfalls off the rim, each falling all the way to the sea.
		for turn in spec[3]:
			var a: float = PI * .5 + turn
			var c := Vector2(cos(a), sin(a))
			var lip := Vector3(c.x, 0, c.y) * radius * rim_bump(noise, c) * .95 + Vector3(0, .5, 0)
			var out := Vector3(c.x, 0, c.y)
			var drop: float = at.y - SEA_LEVEL + 3.
			var sheet: MeshInstance3D = quiet(room.draw(isle, fall_mesh(lip, out, drop, radius * .22), Vector3.ZERO, fall_look))
			sheet.extra_cull_margin = 4.
			# Spray where it lands.
			var mist := CPUParticles3D.new()
			add_child(mist)
			mist.mesh = mist_ball
			mist.position = at + lip + out * 2.4 * sqrt(2. * (drop - 3.) / 9.8) + Vector3(0, SEA_LEVEL - at.y - lip.y + .4, 0)
			mist.amount = 40
			mist.lifetime = 4.5
			mist.preprocess = 4.5
			mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			mist.emission_box_extents = Vector3(radius * .2, .3, 1.)
			mist.direction = Vector3.UP
			mist.spread = 35.
			mist.gravity = Vector3(0, .3, 0)
			mist.initial_velocity_min = .6
			mist.initial_velocity_max = 1.8
			mist.scale_amount_min = 1.4
			mist.scale_amount_max = 3.4
			mist.color_ramp = mist_fade
			quiet(mist)
			if islands.is_empty() and turn == spec[3][0]:
				# A rainbow stands in the spray of the biggest fall while the sun is up.
				bow_look.shader = shade(RAINBOW)
				var arc := QuadMesh.new()
				arc.size = Vector2(radius * 2.6, radius * 1.3)
				quiet(room.draw(self, arc, mist.position + Vector3(0, radius * .62, 4.), bow_look))
		islands.append({"node": isle, "home": at, "spin": spec[4], "seed": randf() * 50., "turn": randf() * TAU})


# ------------------------------------------------------------------ jellyfish


const JELLY := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float seconds = 0.0;
uniform float glow = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_tint : source_color = vec3(1.0);
varying float kind;
varying float along;
varying vec3 tint;
varying vec3 local;
void vertex() {
	kind = COLOR.r;
	along = COLOR.g;
	local = VERTEX;
	// Each jellyfish's colour comes from a hue in its instance data.
	tint = 0.6 + 0.4 * cos(6.2832 * (INSTANCE_CUSTOM.z + vec3(0.0, 0.33, 0.67)));
	float phase = INSTANCE_CUSTOM.x * 6.2832 + seconds * INSTANCE_CUSTOM.y;
	vec3 v = VERTEX;
	if (kind < 0.25) {
		// The bell squeezes, pushing water out, then relaxes.
		float squeeze = pow(max(sin(phase), 0.0), 1.6);
		float rim = smoothstep(0.15, 1.0, length(v.xz));
		v.xz *= 1.0 - 0.24 * squeeze * (0.35 + 0.65 * rim);
		v.y *= 1.0 + 0.14 * squeeze;
	} else {
		// Tentacles and arms take each squeeze a moment later the farther down they are, and
		// trail and curl in the air.
		float squeeze = pow(max(sin(phase - along * 2.4), 0.0), 1.6);
		v.xz *= 1.0 - 0.22 * squeeze * (1.0 - 0.6 * along);
		float seed = COLOR.b * 23.0 + INSTANCE_CUSTOM.x * 40.0;
		v.x += sin(seconds * 1.2 + along * 5.0 + seed) * 0.22 * along;
		v.z += cos(seconds * 1.0 + along * 4.3 + seed * 1.3) * 0.22 * along;
		v.y -= along * 0.4 * squeeze;
	}
	VERTEX = v;
}
void fragment() {
	float face = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - face, 2.0);
	vec3 col = tint;
	float lit = 0.35 + 1.1 * glow;
	if (kind < 0.25) {
		// Canals running out from the top of the bell, and a ring of spots round its edge.
		float ang = atan(local.z, local.x);
		float canal = smoothstep(0.75, 0.98, cos(ang * 8.0)) * smoothstep(0.1, 0.5, length(local.xz));
		float spots = smoothstep(0.6, 0.9, cos(ang * 24.0)) * smoothstep(0.75, 0.95, length(local.xz)) * smoothstep(0.35, 0.05, local.y);
		ALPHA = clamp(0.22 + 0.6 * rim + 0.35 * canal + 0.5 * spots, 0.0, 0.9);
		col = mix(tint, vec3(1.0), 0.25 * canal + 0.5 * spots);
		EMISSION = tint * lit * (0.35 + rim + canal) + vec3(1.0, 0.95, 0.8) * spots * lit + flash_tint * flash * (0.6 + rim);
	} else {
		ALPHA = (0.55 - 0.4 * along) * (kind > 0.75 ? 0.75 : 1.0);
		EMISSION = tint * lit * (0.6 + 0.6 * (1.0 - along)) + flash_tint * flash * 0.5;
	}
	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.7;
}
"""


## One jellyfish a metre across: a bell, frilled arms in the middle and long tentacles.
func jelly_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The bell is a cup with a thickness: out over the top, round the rim, back up inside.
	var profile := [
		Vector2(0., .78), Vector2(.3, .74), Vector2(.55, .62), Vector2(.76, .44), Vector2(.92, .22),
		Vector2(1., .02), Vector2(.97, -.05), Vector2(.88, .04), Vector2(.68, .24), Vector2(.4, .38), Vector2(0., .44)
	]
	var sections: Array = []
	var paint: Array = []
	for p in profile:
		sections.append([Vector3(0, p.y, 0), Vector3(p.x, 0, 0), Vector3(0, 0, p.x)])
		paint.append(Color(0, 0, 0))
	loft(st, sections, 24, paint)
	# Frilled arms hang from the middle; thin tentacles from the rim.
	for arm in 4:
		var a := TAU * arm / 4. + .4
		var side := Vector3(cos(a), 0, sin(a))
		var flat := side.cross(Vector3.UP)
		var cuts: Array = []
		var marks: Array = []
		for n in 10:
			var u := n / 9.
			var curl := Vector3(sin(u * 7. + arm), 0, cos(u * 6. + arm)) * .08
			cuts.append([side * .12 + Vector3(0, .3 - u * 1.9, 0) + curl, flat * (.11 * (1. - .6 * u) + .02), side * .02])
			marks.append(Color(.5, u, float(arm) / 4.))
		loft(st, cuts, 6, marks)
	for k in 14:
		var a := TAU * k / 14.
		var root := Vector3(cos(a) * .9, .0, sin(a) * .9)
		var cuts: Array = []
		var marks: Array = []
		var long := 2.4 + 1.4 * fmod(k * .618, 1.)
		for n in 14:
			var u := n / 13.
			cuts.append([root * (1. - .25 * u) + Vector3(0, -u * long, 0), Vector3(.016, 0, 0), Vector3(0, 0, .016)])
			marks.append(Color(1, u, float(k) / 14.))
		loft(st, cuts, 4, marks)
	st.index()
	st.generate_normals()
	return st.commit()


func jellyfish() -> void:
	jelly_look.shader = Shader.new()
	jelly_look.shader.code = JELLY
	jellies.transform_format = MultiMesh.TRANSFORM_3D
	jellies.use_custom_data = true
	jellies.mesh = jelly_mesh()
	var count := 34
	jellies.instance_count = count
	for n in count:
		var giant := n == 0
		var j := {
			"at": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"size": 14. if giant else randf_range(1.1, 3.6),
			"rate": .55 if giant else randf_range(1.1, 2.1),
			"phase": randf(),
			"tilt": Vector3.UP,
			"wander": randf() * TAU,
			"giant": giant,
			"hue": [.0, .15, .55, .72, .85, .4][n % 6] + randf_range(-.04, .04)
		}
		spawn(j, true)
		swarm.append(j)
		jellies.set_instance_custom_data(n, Color(j.phase, j.rate, j.hue, 0))
	var school := MultiMeshInstance3D.new()
	school.multimesh = jellies
	school.material_override = jelly_look
	quiet(school)
	add_child(school)
	# The school spans the whole bay, so never let the engine cull it as a block.
	school.custom_aabb = AABB(Vector3(-200, -20, -260), Vector3(400, 140, 260))


## Put a jellyfish back where they come from: up out of the sea, out in the bay. On the first
## call they start anywhere along the way up.
func spawn(j: Dictionary, anywhere: bool) -> void:
	if j.giant:
		# Far out on the left, clear of Saturn and the islands.
		j.at = Vector3(randf_range(-128., -104.), 26. if anywhere else -12., randf_range(-178., -162.))
	else:
		var x := randf_range(-95., 95.)
		var z := randf_range(-115., -36.)
		# Keep the dock clear: none rise right in front of the crowd.
		if absf(x) < 45. and z > -46.:
			z -= 14.
		j.at = Vector3(x, randf_range(-1., 36.) if anywhere else SEA_LEVEL - j.size * 1.4, z)
	j.vel = Vector3(0, .6, 0)
	j.tilt = Vector3(randf_range(-.25, .25), 1., randf_range(-.25, .25)).normalized()


func swim_jellies(dt: float) -> void:
	for n in swarm.size():
		var j: Dictionary = swarm[n]
		# Each squeeze of the bell is a push along the way the bell points, then it coasts.
		var phase: float = j.phase * TAU + seconds * j.rate
		var push: float = pow(maxf(sin(phase), 0.), 1.6)
		j.wander += dt * (.15 + .1 * sin(seconds * .3 + n))
		var lean := Vector3(sin(j.wander) * .35, 1., cos(j.wander * .8 + n) * .25).normalized()
		j.tilt = j.tilt.lerp(lean, 1. - exp(-dt * .4)).normalized()
		var strength: float = (1.6 if not j.giant else 1.1) * sqrt(j.size)
		j.vel += j.tilt * push * strength * dt
		j.vel -= j.vel * dt * .9
		# A breeze off the sea carries them gently inland and sideways.
		j.vel += Vector3(.12 * sin(seconds * .07 + n), 0, .05) * dt
		j.at += j.vel * dt
		if j.at.y > (70. if j.giant else 48.) or absf(j.at.x) > 140.:
			spawn(j, false)
		var up: Vector3 = j.tilt
		var side := up.cross(Vector3.FORWARD).normalized()
		var basis := Basis(side, up, side.cross(up)).scaled(Vector3.ONE * j.size)
		jellies.set_instance_transform(n, Transform3D(basis, j.at))


# ------------------------------------------------------------------ airships


const ENVELOPE := """shader_type spatial;
uniform vec3 stripe_a : source_color = vec3(1.0, 0.4, 0.6);
uniform vec3 stripe_b : source_color = vec3(1.0, 0.95, 0.85);
uniform float glow = 0.0;
uniform float seconds = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_tint : source_color = vec3(1.0);
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float ang = atan(local.z, local.y);
	float stripe = step(0.5, fract(ang / 6.2832 * 12.0));
	vec3 col = mix(stripe_a, stripe_b, stripe);
	// A band of bulbs round the middle and a ring at each end, chasing at night.
	float belt = 1.0 - smoothstep(0.03, 0.06, abs(local.y));
	float bulbs = smoothstep(0.55, 0.9, sin(local.x * 40.0 - seconds * 6.0)) * belt;
	float caps = smoothstep(0.86, 0.9, abs(local.x)) * (1.0 - smoothstep(0.9, 0.94, abs(local.x)));
	ALBEDO = col;
	ROUGHNESS = 0.45;
	EMISSION = vec3(1.0, 0.85, 0.5) * (bulbs + caps) * (0.4 + 3.0 * glow) + col * glow * 0.12 + flash_tint * flash * (bulbs + caps) * 4.0;
}
"""

const BANNER := """shader_type spatial;
render_mode cull_disabled;
uniform float seconds = 0.0;
uniform vec3 colour_a : source_color = vec3(1.0, 0.75, 0.34);
uniform vec3 colour_b : source_color = vec3(0.34, 0.85, 0.93);
uniform float glow = 0.0;
void vertex() {
	float wave = UV.x * UV.x;
	VERTEX.z += sin(UV.x * 9.0 - seconds * 5.0) * 0.45 * wave + sin(UV.x * 17.0 - seconds * 8.0) * 0.12 * wave;
	VERTEX.y += sin(UV.x * 6.0 - seconds * 3.0) * 0.12 * wave;
}
void fragment() {
	float check = step(0.5, fract(UV.x * 6.0)) ;
	vec3 col = mix(colour_a, colour_b, check);
	col = mix(col, vec3(1.0, 0.97, 0.9), step(0.42, abs(UV.y - 0.5)));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	EMISSION = col * glow * 0.5;
}
"""


func airships() -> void:
	ship_look.shader = Shader.new()
	ship_look.shader.code = ENVELOPE
	banner_look.shader = Shader.new()
	banner_look.shader.code = BANNER
	banner_look.set_shader_parameter("colour_a", Color("#ffc056"))
	banner_look.set_shader_parameter("colour_b", Color("#56d9ee"))
	var body := SphereMesh.new()
	body.radius = 1.
	body.height = 2.
	body.radial_segments = 40
	body.rings = 20
	var fin_paint: Material = room.metal("airship fin", "#ff5d8f", .6, .1)
	var hull_paint: Material = room.metal("gondola", "#3a2a4a", .5, .3)
	var window_paint: Material = room.metal("gondola windows", "#ffd98a", .3, 0., 2.6)
	var blade_paint: Material = room.metal("propeller", "#e8e0d0", .4, .5)
	var flag := PlaneMesh.new()
	flag.size = Vector2(9., 1.3)
	flag.subdivide_width = 24
	flag.orientation = PlaneMesh.FACE_Z
	# [path centre, half-widths, height, speed, phase, size, stripe colours]
	for spec in [
		[Vector2(-6, -112), Vector2(118, 42), 27., .045, .3, 1., [Color("#ff5d8f"), Color("#fff3d6")]],
		[Vector2(14, -128), Vector2(132, 52), 36., -.033, 2.4, .8, [Color("#3fa9ff"), Color("#ffd04a")]]
	]:
		var look := ship_look.duplicate() as ShaderMaterial
		look.set_shader_parameter("stripe_a", spec[6][0])
		look.set_shader_parameter("stripe_b", spec[6][1])
		var ship := Node3D.new()
		add_child(ship)
		var size: float = spec[5]
		var frame := Node3D.new()
		ship.add_child(frame)
		frame.scale = Vector3.ONE * size
		var envelope: MeshInstance3D = quiet(room.draw(frame, body, Vector3.ZERO, look))
		envelope.scale = Vector3(8., 2.6, 2.6)
		for k in 4:
			var a := TAU * k / 4. + PI * .25
			var fin: MeshInstance3D = quiet(room.box(frame, Vector3(6.4, cos(a) * 2.2, sin(a) * 2.2), Vector3(2.4, .12, 1.8), fin_paint))
			fin.rotation.x = a
		quiet(room.box(frame, Vector3(.3, -3.35, 0), Vector3(4.2, 1.1, 1.3), hull_paint))
		quiet(room.box(frame, Vector3(.3, -3.25, 0), Vector3(3.8, .42, 1.34), window_paint))
		for side in [-1., 1.]:
			room.tube(frame, Vector3(-1.4, -2.85, side * .5), Vector3(-1.6, -1.9, side * 1.1), .04, hull_paint)
			room.tube(frame, Vector3(2., -2.85, side * .5), Vector3(2.4, -1.9, side * 1.1), .04, hull_paint)
		var props: Array = []
		for side in [-1., 1.]:
			var hub := Node3D.new()
			frame.add_child(hub)
			hub.position = Vector3(2.7, -3.3, side * .9)
			quiet(room.box(hub, Vector3.ZERO, Vector3(.08, 1.6, .16), blade_paint))
			quiet(room.box(hub, Vector3.ZERO, Vector3(.08, .16, 1.6), blade_paint))
			props.append(hub)
		quiet(room.draw(frame, flag, Vector3(12.8, -.6, 0), banner_look))
		room.tube(frame, Vector3(7.4, -.6, 0), Vector3(8.4, -.6, 0), .03, hull_paint)
		ships.append({"node": ship, "centre": spec[0], "reach": spec[1], "height": spec[2], "speed": spec[3], "phase": spec[4], "props": props, "look": look})


# ------------------------------------------------------------------ sailing boats


const SAIL := """shader_type spatial;
render_mode cull_disabled;
uniform float seconds = 0.0;
uniform float glow = 0.0;
uniform vec3 colour_a : source_color = vec3(1.0, 0.4, 0.7);
uniform vec3 colour_b : source_color = vec3(1.0, 0.8, 0.3);
uniform float flash = 0.0;
uniform vec3 flash_tint : source_color = vec3(1.0);
void vertex() {
	// Full of wind: the belly of the sail pushed out, and the edges shivering.
	float belly = sin(UV.x * 3.1416) * sin(UV.y * 3.1416 * 0.9 + 0.2);
	float shiver = sin(seconds * 7.0 + UV.y * 9.0) * 0.04 * (1.0 - UV.x);
	VERTEX.z += belly * (0.55 + 0.08 * sin(seconds * 1.7)) + shiver;
}
void fragment() {
	vec3 col = mix(colour_a, colour_b, smoothstep(0.2, 0.8, UV.y));
	float band = step(0.82, fract(UV.y * 4.0));
	col = mix(col, vec3(1.0, 0.97, 0.92), band * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	BACKLIGHT = col * 0.6;
	EMISSION = col * (0.08 + 1.1 * glow) + flash_tint * flash * band * 2.0;
}
"""


## A triangular sail from the foot of the mast: `rise` up the mast and `reach` back along the boom.
func sail_mesh(rise: float, reach: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	var grid: Array = []
	for i in steps + 1:
		var row: Array = []
		for k in steps + 1:
			var u := float(k) / steps
			var v := float(i) / steps
			row.append([Vector3(reach * u * (1. - v), rise * v, 0), Vector2(u * (1. - v), v)])
		grid.append(row)
	for i in steps:
		for k in steps:
			for corner in [[i, k], [i + 1, k], [i, k + 1], [i, k + 1], [i + 1, k], [i + 1, k + 1]]:
				var cell: Array = grid[corner[0]][corner[1]]
				st.set_uv(cell[1])
				st.set_normal(Vector3.BACK)
				st.add_vertex(cell[0])
	return st.commit()


func sailing_boats() -> void:
	sail_look.shader = Shader.new()
	sail_look.shader.code = SAIL
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuts: Array = []
	var marks: Array = []
	for n in 14:
		var u := n / 13.
		var x := u * 2. - 1.
		var wide := .5 * pow(1. - pow(absf(x - .15) / 1.15, 2.4), .6) + .01
		cuts.append([Vector3(x * 2.4, .1 * x * x, 0), Vector3(0, .42 * wide / .5, 0), Vector3(0, 0, wide)])
		marks.append(Color.WHITE)
	loft(hull, cuts, 16, marks)
	hull.index()
	hull.generate_normals()
	var hull_mesh := hull.commit()
	var wood: Material = room.metal("boat hull", "#f4efe6", .5, .1)
	var mast_paint: Material = room.metal("boat mast", "#5a4636", .7, .1)
	var lamp: Material = room.metal("masthead lamp", "#ffe08a", .3, 0., 4.)
	for spec in [
		[Vector2(-50, -33), 8., .16, [Color("#ff4fa3"), Color("#ffb347")]],
		[Vector2(10, -31), 6.5, -.2, [Color("#38e0d0"), Color("#9a7cff")]],
		[Vector2(-22, -62), 11., .12, [Color("#ffd23f"), Color("#ff6b4a")]]
	]:
		var boat := Node3D.new()
		add_child(boat)
		quiet(room.draw(boat, hull_mesh, Vector3.ZERO, wood))
		room.tube(boat, Vector3(-.4, 0, 0), Vector3(-.4, 5.4, 0), .06, mast_paint)
		room.tube(boat, Vector3(-.4, .9, 0), Vector3(2.2, .9, 0), .04, mast_paint)
		quiet(room.ball(boat, Vector3(-.4, 5.55, 0), Vector3.ONE * .14, lamp))
		var look := sail_look.duplicate() as ShaderMaterial
		look.set_shader_parameter("colour_a", spec[3][0])
		look.set_shader_parameter("colour_b", spec[3][1])
		quiet(room.draw(boat, sail_mesh(4.4, 2.5), Vector3(-.36, .95, 0), look))
		var jib: MeshInstance3D = quiet(room.draw(boat, sail_mesh(4., 1.9), Vector3(-.44, 1., 0), look))
		jib.rotation.y = PI
		jib.scale = Vector3(1., 1., -1.)
		boats.append({"node": boat, "centre": spec[0], "radius": spec[1], "speed": spec[2], "turn": randf() * TAU, "look": look})


# ------------------------------------------------------------------ big wheel


const BULB := """shader_type spatial;
render_mode unshaded;
uniform float seconds = 0.0;
uniform float glow = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_tint : source_color = vec3(1.0);
varying float index;
void vertex() { index = INSTANCE_CUSTOM.x; }
void fragment() {
	// The lights chase round the rim, through the colours of a carnival.
	float chase = 0.5 + 0.5 * sin(index * 6.2832 * 6.0 - seconds * 3.0);
	vec3 hue = clamp(abs(mod((index * 3.0 + seconds * 0.05) * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	vec3 col = mix(vec3(1.0, 0.9, 0.7), hue, 0.6);
	col = mix(col, flash_tint, flash);
	ALBEDO = col * (0.6 + (0.8 + 2.4 * glow) * chase + 2.0 * flash);
}
"""


func big_wheel() -> void:
	var steel: Material = room.metal("wheel steel", "#f2ede4", .45, .55)
	var pier_wood: Material = room.metal("pier deck", "#6b4f3a", .85, .05)
	var post: Material = room.metal("pier post", "#3a3038", .8, .1)
	var at := WHEEL_AT
	quiet(room.box(self, at + Vector3(0, 1.6, 0), Vector3(26., .6, 9.), pier_wood))
	for x in [-11., -5.5, 0., 5.5, 11.]:
		for z in [-3.8, 3.8]:
			room.tube(self, at + Vector3(x, -1., z), at + Vector3(x, 1.4, z), .28, post)
	var hub := at + Vector3(0, WHEEL_HUB, 0)
	for side in [-1., 1.]:
		for lean in [-1., 1.]:
			room.tube(self, at + Vector3(lean * 6.5, 1.9, side * 2.2), hub + Vector3(0, 0, side * 1.6), .26, steel)
	add_child(wheel)
	wheel.position = hub
	for side in [-1., 1.]:
		var rim: MeshInstance3D = room.torus(wheel, Vector3(0, 0, side * 1.1), WHEEL_RADIUS - .12, WHEEL_RADIUS + .12, steel)
		rim.rotation.x = PI * .5
		var inner: MeshInstance3D = room.torus(wheel, Vector3(0, 0, side * 1.1), WHEEL_RADIUS * .55 - .08, WHEEL_RADIUS * .55 + .08, steel)
		inner.rotation.x = PI * .5
		for k in 16:
			var a := TAU * k / 16.
			room.tube(wheel, Vector3(0, 0, side * 1.5), Vector3(cos(a), sin(a), 0) * WHEEL_RADIUS + Vector3(0, 0, side * 1.1), .07, steel)
	room.tube(wheel, Vector3(0, 0, -1.8), Vector3(0, 0, 1.8), .45, steel)
	# Lights round both rims and along every spoke.
	bulb_look.shader = Shader.new()
	bulb_look.shader.code = BULB
	var dot := SphereMesh.new()
	dot.radius = .2
	dot.height = .4
	dot.radial_segments = 8
	dot.rings = 4
	bulbs.transform_format = MultiMesh.TRANSFORM_3D
	bulbs.use_custom_data = true
	bulbs.mesh = dot
	var spots: Array = []
	for side in [-1., 1.]:
		for k in 64:
			var a := TAU * k / 64.
			spots.append([Vector3(cos(a), sin(a), 0) * (WHEEL_RADIUS + .05) + Vector3(0, 0, side * 1.25), k / 64.])
		for k in 16:
			var a := TAU * k / 16.
			for r in [.3, .45, .7, .85]:
				spots.append([Vector3(cos(a), sin(a), 0) * WHEEL_RADIUS * r + Vector3(0, 0, side * 1.3), k / 16. + r * .1])
	bulbs.instance_count = spots.size()
	for n in spots.size():
		bulbs.set_instance_transform(n, Transform3D(Basis.IDENTITY, spots[n][0]))
		bulbs.set_instance_custom_data(n, Color(spots[n][1], 0, 0, 0))
	var lamps := MultiMeshInstance3D.new()
	lamps.multimesh = bulbs
	lamps.material_override = bulb_look
	quiet(lamps)
	wheel.add_child(lamps)
	# Sixteen cars that hang level as the wheel carries them round.
	var colours := ["#ff5d8f", "#ffd04a", "#38e0d0", "#9a7cff", "#ff8a4a", "#7fe85a", "#3fa9ff", "#ff6fb5"]
	var glass: Material = room.metal("car windows", "#ffe9b0", .3, 0., 1.8)
	for k in 16:
		var car := Node3D.new()
		add_child(car)
		var shell: Material = room.metal("car %d" % (k % 8), colours[k % 8], .5, .2)
		quiet(room.box(car, Vector3(0, -1.25, 0), Vector3(1.6, 1.3, 1.4), shell))
		quiet(room.box(car, Vector3(0, -1.15, 0), Vector3(1.64, .5, 1.44), glass))
		quiet(room.ball(car, Vector3(0, -.45, 0), Vector3(.95, .35, .8), shell))
		room.tube(car, Vector3(0, 0, 0), Vector3(0, -.4, 0), .05, steel)
		cars.append({"node": car, "angle": TAU * k / 16., "swing": 0., "spin": 0.})


# ------------------------------------------------------------------ every frame


## A goal: lights everywhere flash in that crew's colour.
func cheer(tint: Color) -> void:
	flash = 1.
	flash_tint = tint


func animate(dt: float, night: float, lit: float) -> void:
	seconds += dt
	dusk = night
	lights = lit
	flash = move_toward(flash, 0., dt * .7)
	var glow := clampf(smoothstep(.25, .9, dusk) + .8 * (1. - lights), 0., 1.6)
	var lamps := (.25 + .75 * smoothstep(.15, .8, dusk)) * (.3 + .7 * lights)
	for look in island_looks:
		look.set_shader_parameter("glow", glow)
		look.set_shader_parameter("flash", flash)
		look.set_shader_parameter("flash_tint", flash_tint)
	for mat in [tree_look, fall_look, jelly_look, banner_look]:
		mat.set_shader_parameter("seconds", seconds)
		mat.set_shader_parameter("glow", glow)
	jelly_look.set_shader_parameter("flash", flash)
	jelly_look.set_shader_parameter("flash_tint", flash_tint)
	bow_look.set_shader_parameter("day", 1. - smoothstep(.2, .6, dusk))
	bulb_look.set_shader_parameter("seconds", seconds)
	bulb_look.set_shader_parameter("glow", lamps)
	bulb_look.set_shader_parameter("flash", flash)
	bulb_look.set_shader_parameter("flash_tint", flash_tint)
	# Islands drift up and down and turn a little, each on its own clock.
	for isle in islands:
		var t: float = seconds + isle.seed
		var node: Node3D = isle.node
		node.position = isle.home + Vector3(.6 * sin(t * .11), .9 * sin(t * .23) + .4 * sin(t * .51), .4 * cos(t * .09))
		node.rotation = Vector3(.025 * sin(t * .19), isle.turn + .18 * sin(t * isle.spin * 6.), .025 * cos(t * .17))
	swim_jellies(dt)
	# Airships go round wide loops over the bay, banking into the turns.
	for ship in ships:
		var phase: float = ship.phase + seconds * ship.speed
		var reach: Vector2 = ship.reach
		var centre: Vector2 = ship.centre
		var at := Vector3(centre.x + reach.x * cos(phase), ship.height + .8 * sin(seconds * .4 + ship.phase), centre.y + reach.y * sin(phase))
		var way := Vector3(-reach.x * sin(phase), 0, reach.y * cos(phase)).normalized() * signf(ship.speed)
		var node: Node3D = ship.node
		var bank := clampf(ship.speed * 6., -.2, .2) * (1. - absf(way.x))
		# The envelope's long axis is x with the nose at -x: turn the ship so its nose leads.
		node.transform = Transform3D(Basis.looking_at(way, Vector3.UP) * Basis(Vector3.UP, -PI * .5) * Basis(Vector3.RIGHT, bank), at)
		for hub in ship.props:
			hub.rotation.x += dt * 14.
		var look: ShaderMaterial = ship.look
		look.set_shader_parameter("seconds", seconds)
		look.set_shader_parameter("glow", lamps)
		look.set_shader_parameter("flash", flash)
		look.set_shader_parameter("flash_tint", flash_tint)
	# Boats sail round their marks, heeling in the breeze and riding the swell.
	for boat in boats:
		boat.turn += dt * boat.speed
		var c: Vector2 = boat.centre
		var a: float = boat.turn
		var at := Vector3(c.x + cos(a) * boat.radius, 0, c.y + sin(a) * boat.radius)
		var swell: float = .16 * sin(seconds * .55 + at.x * .09) + .1 * sin(seconds * .42 + at.z * .12)
		at.y = SEA_LEVEL + .05 + swell
		var way := Vector3(-sin(a), 0, cos(a)) * signf(boat.speed)
		var heel: float = (.22 + .06 * sin(seconds * .8 + c.x)) * signf(boat.speed)
		var node: Node3D = boat.node
		node.transform = Transform3D(
			Basis.looking_at(way, Vector3.UP) * Basis(Vector3.UP, -PI * .5) * Basis(Vector3.RIGHT, heel) * Basis(Vector3.BACK, .05 * cos(seconds * .9 + c.y)),
			at
		)
		var look: ShaderMaterial = boat.look
		look.set_shader_parameter("seconds", seconds)
		look.set_shader_parameter("glow", glow)
		look.set_shader_parameter("flash", flash)
		look.set_shader_parameter("flash_tint", flash_tint)
	# The wheel turns, and each car hangs below its pin, swinging a little.
	wheel_turn += dt * .09
	wheel.rotation.z = wheel_turn
	for car in cars:
		var a: float = car.angle + wheel_turn
		var node: Node3D = car.node
		node.position = wheel.position + Vector3(cos(a), sin(a), 0) * WHEEL_RADIUS + Vector3(0, 0, 0)
		node.rotation.z = .07 * sin(seconds * 1.1 + car.angle * 3.) + .04 * cos(a)
