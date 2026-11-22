extends Node3D
## Everything beyond the dock rail: Saturn with the sun slipping behind it, a sea that mirrors the
## sky, whales that fly and surface, a lighthouse, ferries, lanterns and the crowd behind the rail.
## Presentation only. The court never reads this node.
const Game = preload("res://game/star_match.gd")
const SEA_LEVEL := -2.6
const LAMP := Vector3(-33., 3.4, -47.)
const CREW := [Color("#ffc056"), Color("#56d9ee")]
## The sky, written once and used twice: by the dome, and by the sea for what it reflects.
const SKY := """
uniform float seconds = 0.0;
uniform float dusk = 0.0;
uniform float cold = 0.0;
uniform float pulse = 0.0;
uniform vec3 pulse_tint : source_color = vec3(1.0, 0.74, 0.3);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return s;
}

vec3 sky(vec3 d, bool fine) {
	float up = d.y;
	vec3 horizon = mix(vec3(1.0, 0.50, 0.24), vec3(0.50, 0.40, 0.78), cold);
	vec3 mid = mix(vec3(0.47, 0.29, 0.46), vec3(0.13, 0.25, 0.48), cold);
	vec3 zenith = mix(vec3(0.07, 0.10, 0.24), vec3(0.02, 0.07, 0.20), cold);
	horizon = mix(horizon, horizon * 0.20 + vec3(0.02, 0.03, 0.08), dusk);
	mid = mix(mid, vec3(0.03, 0.045, 0.11), dusk);
	zenith = mix(zenith, vec3(0.006, 0.012, 0.04), dusk);
	vec3 col = mix(horizon, mid, smoothstep(-0.03, 0.22, up));
	col = mix(col, zenith, smoothstep(0.16, 0.8, up));

	// The sun goes down to the left of Saturn and is under the sea by the middle of a match.
	vec3 sun = normalize(vec3(-0.208, 0.087 - 0.24 * dusk, -0.978));
	vec3 warm = mix(vec3(1.0, 0.66, 0.32), vec3(0.80, 0.84, 1.0), cold);
	float halo = max(dot(d, sun), 0.0);
	float day = 1.0 - smoothstep(0.25, 0.75, dusk);
	col += warm * (pow(halo, 9.0) * 0.38 + pow(halo, 70.0) * 0.9) * (0.25 + 0.75 * day);
	col += vec3(1.0, 0.93, 0.78) * smoothstep(0.99962, 0.99982, halo) * 3.0 * day;

	// Saturn sits on the horizon to the right, small enough to see whole, with its rings open.
	vec3 c = normalize(vec3(0.2575, 0.1011, -0.9610));
	vec3 axis = normalize(vec3(0.22, 0.95, -0.14));
	float dist = 11.47;
	vec3 centre = c * dist;
	float b = dot(d, centre);
	float disc = b * b - (dist * dist - 1.0);
	float t_planet = 1.0e9;
	float shine = 0.55 + 0.45 * day;
	bool open_sky = true;
	if (disc > 0.0 && b > 0.0) {
		open_sky = false;
		t_planet = b - sqrt(disc);
		vec3 n = normalize(d * t_planet - centre);
		float lat = dot(n, axis);
		float band = 0.5 + 0.5 * sin(lat * 24.0 + 2.2 * sin(lat * 7.0 + 1.0));
		vec3 globe = mix(vec3(0.78, 0.60, 0.40), vec3(0.96, 0.84, 0.62), band);
		globe = mix(globe, vec3(0.58, 0.68, 0.86), cold * 0.55);
		float rim = pow(1.0 - max(dot(n, -d), 0.0), 3.0);
		// The light wraps well round the globe, so the bands show on the face we see.
		float lit = smoothstep(-0.75, 0.35, dot(n, sun));
		col = globe * (0.20 + 0.10 * day) + globe * lit * 0.85 * shine;
		col += warm * rim * (0.15 + 0.6 * lit) * shine;
		col += pulse_tint * pulse * (rim * 0.9 + 0.12);
	}
	float lean = dot(d, axis);
	if (abs(lean) > 0.0005) {
		float t_ring = dot(centre, axis) / lean;
		if (t_ring > 0.0 && t_ring < t_planet) {
			vec3 h = d * t_ring - centre;
			float r = length(h);
			float body = smoothstep(1.22, 1.30, r) * (1.0 - smoothstep(2.28, 2.34, r));
			float groove = 0.74 + 0.26 * sin(r * 62.0) * sin(r * 21.0 + 1.3);
			float dense = body * smoothstep(0.015, 0.045, abs(r - 1.95)) * groove;
			dense *= 0.50 + 0.50 * smoothstep(1.3, 1.75, r);
			// Where the planet stands between the sun and the rings, they dim.
			float along = dot(h, sun);
			float off = length(h - sun * along);
			float shadow = along < 0.0 ? 0.16 + 0.84 * smoothstep(0.92, 1.06, off) : 1.0;
			vec3 ring_col = mix(vec3(1.0, 0.88, 0.66), vec3(0.82, 0.88, 1.0), max(cold * 0.8, dusk * 0.6));
			float glow = dense * shadow * (0.55 + 0.40 * shine);
			col = mix(col, ring_col, clamp(glow, 0.0, 1.0) * 0.94) + ring_col * glow * 0.18;
			col += pulse_tint * pulse * dense * 0.5;
			open_sky = open_sky && glow < 0.3;
		}
	}
	if (open_sky) {
		if (fine) {
			vec2 sp = vec2(atan(d.z, d.x), asin(clamp(d.y, -1.0, 1.0))) * 46.0;
			vec2 cell = floor(sp);
			vec2 f = fract(sp) - 0.5;
			float h1 = hash21(cell);
			vec2 jitter = (vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5) * 0.7;
			float star = step(0.94, h1) * smoothstep(0.11, 0.0, length(f - jitter));
			star *= 0.55 + 0.45 * sin(seconds * (1.3 + h1 * 3.0) + h1 * 50.0);
			col += vec3(0.85, 0.92, 1.0) * star * smoothstep(0.02, 0.3, up) * (0.18 + 0.82 * dusk);
		}
		// A shooting star every few seconds, in a different place each time.
		if (fine) {
			float turn = floor(seconds / 3.7);
			float age = fract(seconds / 3.7);
			vec2 seed = vec2(turn, turn * 1.7);
			vec3 from = normalize(vec3(hash21(seed) * 1.6 - 0.8, 0.30 + 0.35 * hash21(seed + 2.0), -1.0));
			vec3 way = normalize(vec3(0.6 - 1.2 * hash21(seed + 5.0), -0.38, 0.1));
			vec3 head = normalize(from + way * age * 0.55);
			float near = dot(d, head);
			float tail = dot(normalize(d - head * near), -way);
			float streak = smoothstep(0.9990, 0.99995, near + 0.0009 * max(tail, 0.0));
			col += vec3(1.0, 0.96, 0.85) * streak * (1.0 - age) * step(age, 0.5) * (0.35 + 0.65 * dusk);
		}
		// Ribbons of aurora that strengthen as night comes.
		float az = atan(d.x, -d.z);
		float drift = fbm(vec2(az * 2.4 + seconds * 0.03, seconds * 0.05));
		float ribbon = pow(max(0.0, sin(az * 5.0 + drift * 5.0 + seconds * 0.12)), 4.0);
		float height = smoothstep(0.05, 0.22, up) * (1.0 - smoothstep(0.30, 0.62, up));
		vec3 aurora = mix(vec3(0.20, 0.95, 0.70), vec3(0.75, 0.35, 0.95), smoothstep(0.1, 0.5, up));
		col += aurora * ribbon * height * (0.10 + 0.55 * dusk) * (0.6 + 0.4 * cold);
	}
	col += pulse_tint * pulse * 0.10 * (1.0 - smoothstep(0.0, 0.5, up));
	return col;
}
"""
var room
var dome := ShaderMaterial.new()
var sea := ShaderMaterial.new()
var beam := ShaderMaterial.new()
var seconds := 0.0
var dusk := 0.0
var cold := 0.0
var pulse := 0.0
var pulse_tint := Color("#ffc056")
var beam_turn := 0.0
var beam_tint := Color("#ffdf9c")
var beam_power := 1.0
var beams := Node3D.new()
var lamp_glass: StandardMaterial3D
var whale_glow: StandardMaterial3D
var pod: Array = []
var splashes: Array = []
var ferries: Array = []
## The crowd: three shared meshes, one figure per instance.
var bodies := MultiMesh.new()
var heads := MultiMesh.new()
var caps := MultiMesh.new()
var arms := MultiMesh.new()
var lamps := MultiMesh.new()
var fans: Array = []
var joy := [0., 0.]
var lights := 1.0
var drift := CPUParticles3D.new()
var sparks: Array = []
var winner := -1


func shader(body: String, modes: String) -> Shader:
	var s := Shader.new()
	s.code = "shader_type spatial;\nrender_mode %s;\n%s\n%s" % [modes, SKY, body]
	return s


func build(stage) -> void:
	room = stage
	# The sky is the inside of a very large ball.
	dome.shader = shader(
		"varying vec3 ray;\nvoid vertex() { ray = VERTEX; }\nvoid fragment() { ALBEDO = sky(normalize(ray), true); }",
		"unshaded, cull_front, shadows_disabled, fog_disabled"
	)
	var ball := SphereMesh.new()
	ball.radius = 420.
	ball.height = 840.
	ball.radial_segments = 48
	ball.rings = 24
	plain(stage.draw(self, ball, Vector3.ZERO, dome))
	# The sea mirrors that sky, bent by its own swell, and carries the lighthouse beam.
	sea.shader = shader(
		"""
uniform vec3 beam_from = vec3(0.0);
uniform float beam_angle = 0.0;
uniform float beam_power = 1.0;
uniform vec3 beam_tint : source_color = vec3(1.0, 0.87, 0.6);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec2 p = world_pos.xz;
	float far = length(p - CAMERA_POSITION_WORLD.xz);
	vec2 flow = vec2(seconds * 0.12, -seconds * 0.09);
	vec2 slope = vec2(0.9, 0.35) * cos(dot(p, vec2(0.09, 0.035)) + seconds * 0.55) * 0.045;
	slope += vec2(-0.4, 0.8) * cos(dot(p, vec2(-0.06, 0.12)) + seconds * 0.42) * 0.04;
	float n0 = fbm(p * 0.21 + flow);
	float nx = fbm((p + vec2(0.5, 0.0)) * 0.21 + flow);
	float nz = fbm((p + vec2(0.0, 0.5)) * 0.21 + flow);
	slope += vec2(nx - n0, nz - n0) / 0.5 * 0.42;
	// Calmer towards the horizon, so the far water does not shimmer.
	slope /= 1.0 + far * 0.06;
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 r = reflect(view, n);
	r.y = abs(r.y) + 0.01;
	vec3 mirror = sky(normalize(r), false);
	float graze = pow(1.0 - max(dot(-view, n), 0.0), 3.0);
	vec3 deep = mix(vec3(0.03, 0.09, 0.13), vec3(0.02, 0.06, 0.14), cold);
	deep = mix(deep, vec3(0.008, 0.02, 0.05), dusk);
	vec3 col = mix(deep, min(mirror, vec3(1.15)), 0.42 + 0.58 * graze);
	float crest = smoothstep(0.66, 0.86, n0) / (1.0 + far * 0.05);
	col += vec3(0.5, 0.6, 0.65) * crest * 0.05 * (1.0 - 0.6 * dusk);
	vec2 to = p - beam_from.xz;
	float turn = abs(mod(atan(to.y, to.x) - beam_angle + PI, TAU) - PI);
	float reach = length(to);
	float pool = smoothstep(0.16, 0.0, turn) * smoothstep(130.0, 8.0, reach) * smoothstep(1.0, 6.0, reach);
	col += beam_tint * pool * 0.40 * beam_power;
	vec3 haze = sky(normalize(vec3(view.x, 0.02, view.z)), false);
	col = mix(col, haze, smoothstep(150.0, 560.0, far) * 0.85);
	ALBEDO = col;
}
""",
		"unshaded, shadows_disabled, fog_disabled"
	)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(1500, 1500)
	plain(stage.draw(self, sheet, Vector3(0, SEA_LEVEL, 0), sea))
	sea.set_shader_parameter("beam_from", LAMP)
	lighthouse()
	whales()
	boats()
	crowd()
	lanterns()


func plain(mesh: MeshInstance3D) -> MeshInstance3D:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


func lighthouse() -> void:
	var rock: Material = room.metal("harbor rock", "#2b3038", .9, .05)
	var stone: Material = room.metal("lighthouse stone", "#d8cdb6", .8, .02)
	var stripe: Material = room.metal("lighthouse stripe", "#a5503c", .7, .05)
	var foot := Vector3(LAMP.x, SEA_LEVEL, LAMP.z)
	for lump in [[0., 0., 5.4, 1.5], [3.2, 1.4, 3.3, 1.1], [-3.5, -1.2, 3.8, 1.0]]:
		plain(room.ball(self, foot + Vector3(lump[0], .2, lump[1]), Vector3(lump[2], lump[3], lump[2] * .8), rock))
	for n in 4:
		var shaft := CylinderMesh.new()
		shaft.height = 1.35
		shaft.bottom_radius = 1.25 - n * .14
		shaft.top_radius = 1.11 - n * .14
		plain(room.draw(self, shaft, foot + Vector3(0, 1. + n * 1.35, 0), stripe if n % 2 else stone))
	plain(room.torus(self, Vector3(LAMP.x, LAMP.y - .55, LAMP.z), .78, .98, rock))
	lamp_glass = room.metal("lighthouse lamp", "#ffe2a4", .2, .0, 4.)
	plain(room.ball(self, LAMP, Vector3(.62, .62, .62), lamp_glass))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.
	cap.bottom_radius = .86
	cap.height = .8
	plain(room.draw(self, cap, LAMP + Vector3(0, .95, 0), stripe))
	# Two soft sheets of light, each a flat sheet crossed with an upright one.
	beam.shader = Shader.new()
	beam.shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.87, 0.6);
uniform float power = 1.0;
void fragment() {
	float along = 1.0 - UV.x;
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	ALBEDO = tint;
	ALPHA = pow(along, 1.7) * smoothstep(0.0, 0.8, across) * 0.30 * power;
}"""
	add_child(beams)
	beams.position = LAMP
	for way in 2:
		for upright in 2:
			var sheet := QuadMesh.new()
			sheet.size = Vector2(74., 4.6)
			sheet.center_offset = Vector3(37., 0, 0)
			var ray := plain(room.draw(beams, sheet, Vector3.ZERO, beam))
			ray.rotation = Vector3(PI * .5 * upright, PI * way, 0)


func whales() -> void:
	whale_glow = room.metal("whale lanterns", "#7ff2e0", .3, .0, 1.4)
	for swim in [
		{"size": 13., "centre": Vector2(8, -46), "radius": 27., "period": 78., "start": 0., "ride": .5, "leap": 4.6, "beats": 2.},
		{"size": 8.5, "centre": Vector2(-9, -26), "radius": 13.5, "period": 52., "start": 1.9, "ride": .2, "leap": 3.4, "beats": 3.},
		{"size": 4.6, "centre": Vector2(-9, -26), "radius": 12., "period": 52., "start": 1.55, "ride": 0., "leap": 3., "beats": 3.},
		{"size": 10., "centre": Vector2(31, -31), "radius": 16., "period": 64., "start": 4., "ride": .8, "leap": 4., "beats": 2.}
	]:
		var whale: Node3D = room.make_whale(self, swim.size)
		for mesh in whale.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A line of soft lights down each flank, brighter after dark.
		for side in [-1, 1]:
			for n in 6:
				room.ball(
					whale,
					Vector3(-.30 + n * .11, .02, side * (.165 - absf(n - 2.) * .017)) * swim.size,
					Vector3.ONE * .011 * swim.size,
					whale_glow
				)
		swim["whale"] = whale
		swim["under"] = true
		swim["thrill"] = 0.
		pod.append(swim)
	# Rings on the water where a whale breaks the surface.
	for n in 8:
		var foam := StandardMaterial3D.new()
		foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		foam.albedo_color = Color(.8, .95, 1., 0.)
		var ring: MeshInstance3D = plain(room.torus(self, Vector3.ZERO, .86, 1., foam))
		ring.hide()
		splashes.append({"ring": ring, "foam": foam, "age": 9.})


func boats() -> void:
	var hull: Material = room.metal("ferry hull", "#27323d", .7, .2)
	var cabin: Material = room.metal("ferry cabin", "#c9b99b", .7, .05)
	var bulbs: Material = room.metal("ferry lights", "#ffd27a", .3, .0, 3.)
	for n in 2:
		var ferry := Node3D.new()
		add_child(ferry)
		plain(room.box(ferry, Vector3(0, .2, 0), Vector3(8.6, 1.3, 2.6), hull))
		plain(room.box(ferry, Vector3(-.5, 1.35, 0), Vector3(5., 1.1, 2.), cabin))
		plain(room.box(ferry, Vector3(-1.4, 2.25, 0), Vector3(1.6, .8, 1.4), cabin))
		for k in 9:
			plain(room.ball(ferry, Vector3(-4. + k, 2.9 - absf(k - 4.) * .17, 0), Vector3.ONE * .13, bulbs))
			plain(room.ball(ferry, Vector3(-4. + k, 1.35, 1.02), Vector3(.2, .16, .04), bulbs))
		ferries.append({"boat": ferry, "lane": -37. - n * 17., "pace": 2.3 - n * .7, "way": 1. if n == 0 else -1., "at": n * 60.})


## Bleachers behind the far rail. Fans by the gold ring cheer for gold, the others for blue.
func crowd() -> void:
	var step_mat: Material = room.metal("bleacher", "#2c3943", .7, .3)
	var edge: float = Game.BOUNDS.y + 2.1
	for block in 2:
		var x0 := 1.6 if block == 0 else -Game.RING - .3
		var x1 := Game.RING + .3 if block == 0 else -1.6
		for row in 3:
			var z: float = -edge - row * .92
			var top: float = .09 + row * .26
			plain(room.box(self, Vector3((x0 + x1) * .5, top - .25, z), Vector3(x1 - x0 + .6, .5, .9), step_mat))
			var count := int((x1 - x0) / .86)
			for k in count:
				fans.append(
					{
						"spot": Vector3(lerpf(x0, x1, (k + .5) / count) + (row % 2) * .2, top, z),
						"side": block,
						"beat": randf() * TAU,
						"tall": randf_range(.86, 1.16),
						"shirt": [Color("#2f8f8a"), Color("#b98b3e"), Color("#8c4a3c"), Color("#566579"), Color("#d9cdb4")][randi() % 5]
					}
				)
	var body := CylinderMesh.new()
	body.top_radius = .13
	body.bottom_radius = .25
	body.height = .8
	body.radial_segments = 10
	var head := SphereMesh.new()
	head.radius = .145
	head.height = .29
	head.radial_segments = 10
	head.rings = 6
	var cap := CylinderMesh.new()
	cap.top_radius = .11
	cap.bottom_radius = .2
	cap.height = .1
	cap.radial_segments = 10
	var arm := CapsuleMesh.new()
	arm.radius = .05
	arm.height = .46
	arm.radial_segments = 6
	var lamp := SphereMesh.new()
	lamp.radius = .09
	lamp.height = .2
	lamp.radial_segments = 8
	lamp.rings = 5
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = .85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#caa98c")
	skin.roughness = .8
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in [
		[bodies, body, cloth, true],
		[heads, head, skin, false],
		[caps, cap, cloth, true],
		[arms, arm, cloth, true],
		[lamps, lamp, glow, true]
	]:
		var many: MultiMesh = part[0]
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_colors = part[3]
		many.mesh = part[1]
		many.instance_count = fans.size()
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = many
		holder.material_override = part[2]
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(holder)
	for n in fans.size():
		bodies.set_instance_color(n, fans[n].shirt)
		arms.set_instance_color(n, fans[n].shirt)
		caps.set_instance_color(n, fans[n].shirt.darkened(.45))


func lanterns() -> void:
	# Paper lanterns let go from the water, rising all match.
	var paper := SphereMesh.new()
	paper.radius = .2
	paper.height = .5
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.vertex_color_use_as_albedo = true
	lit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paper.material = lit
	add_child(drift)
	drift.mesh = paper
	drift.amount = 64
	drift.lifetime = 19.
	drift.preprocess = 19.
	drift.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drift.emission_box_extents = Vector3(46, .2, 17)
	drift.position = Vector3(0, SEA_LEVEL + .2, -31)
	drift.direction = Vector3.UP
	drift.spread = 12.
	drift.gravity = Vector3(.05, .02, 0)
	drift.initial_velocity_min = .45
	drift.initial_velocity_max = .9
	drift.scale_amount_min = .7
	drift.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1., .78, .42, 0.))
	fade.add_point(.12, Color(1., .78, .42, 1.))
	fade.add_point(.8, Color(1., .66, .36, .9))
	fade.set_color(1, Color(1., .6, .3, 0.))
	drift.color_ramp = fade
	# A burst of sparks at the ring that was just lit.
	var bit := SphereMesh.new()
	bit.radius = .07
	bit.height = .14
	bit.material = lit
	for n in 2:
		var burst := CPUParticles3D.new()
		add_child(burst)
		burst.mesh = bit
		burst.emitting = false
		burst.one_shot = true
		burst.amount = 70
		burst.lifetime = 1.9
		burst.explosiveness = .94
		burst.direction = Vector3.UP
		burst.spread = 75.
		burst.gravity = Vector3(0, -3.4, 0)
		burst.initial_velocity_min = 2.4
		burst.initial_velocity_max = 6.2
		burst.scale_amount_min = .6
		burst.scale_amount_max = 1.5
		var ember := Gradient.new()
		ember.set_color(0, Color(1, 1, 1, 1))
		ember.set_color(1, Color(CREW[n].r, CREW[n].g, CREW[n].b, 0.))
		ember.add_point(.25, CREW[n])
		burst.color_ramp = ember
		burst.position = Vector3(Game.RING if n == 0 else -Game.RING, Game.HEIGHT, 0)
		sparks.append(burst)


## A goal: the sky flushes with that crew's colour, their fans jump and the nearest whale leaps.
func cheer(team: int) -> void:
	pulse = 1.
	pulse_tint = CREW[team]
	joy[team] = 1.
	sparks[team].restart()
	sparks[team].emitting = true
	var nearest: Dictionary = pod[0]
	for swim in pod:
		if swim.whale.position.distance_to(sparks[team].position) < nearest.whale.position.distance_to(sparks[team].position):
			nearest = swim
	nearest.thrill = 1.


## The final whistle: the lighthouse takes the winner's colour. -1 is a shared light.
func finale(team: int) -> void:
	winner = team
	if team >= 0:
		joy[team] = 1.
		pulse = 1.
		pulse_tint = CREW[team]


func restart() -> void:
	winner = -1
	joy = [0., 0.]
	pulse = 0.


## `night` runs from sunset to dark. `out` is the robots taking the harbor lights with them.
func animate(dt: float, night: float, chill: float, out: float, still: bool) -> void:
	seconds += dt * (.3 if still else 1.)
	dusk = move_toward(dusk, clampf(maxf(night, out), 0., 1.), dt * .5)
	cold = move_toward(cold, chill, dt * .8)
	pulse = move_toward(pulse, 0., dt * .55)
	lights = move_toward(lights, 1. - .88 * out, dt * .8)
	for mat in [dome, sea]:
		mat.set_shader_parameter("seconds", seconds)
		mat.set_shader_parameter("dusk", dusk)
		mat.set_shader_parameter("cold", cold)
		mat.set_shader_parameter("pulse", pulse)
		mat.set_shader_parameter("pulse_tint", pulse_tint)
	# The lighthouse turns. At the whistle it burns in the winner's colour.
	beam_turn = fposmod(beam_turn + dt * (.2 if still else .55), TAU)
	var shade: Color = CREW[winner] if winner >= 0 else Color("#ffdf9c")
	beam_tint = beam_tint.lerp(shade, 1. - exp(-dt * 3.))
	beam_power = move_toward(beam_power, (2.4 if winner >= 0 else 1. + .5 * dusk) * (.25 + .75 * lights), dt * 2.)
	beams.rotation.y = -beam_turn
	beam.set_shader_parameter("tint", beam_tint)
	beam.set_shader_parameter("power", beam_power)
	sea.set_shader_parameter("beam_angle", beam_turn)
	sea.set_shader_parameter("beam_tint", beam_tint)
	sea.set_shader_parameter("beam_power", beam_power)
	lamp_glass.emission = beam_tint
	lamp_glass.emission_energy_multiplier = 1.5 + 2.5 * beam_power
	whale_glow.emission_energy_multiplier = .5 + 2.2 * dusk + 2.6 * out
	drift.speed_scale = .3 if still else 1.
	for swim in pod:
		swim.thrill = move_toward(swim.thrill, 0., dt / 2.6)
		var at := whale_place(swim, seconds)
		var ahead := whale_place(swim, seconds + .35)
		# A thrilled whale throws in one extra leap and a roll.
		var lift: float = sin(PI * (1. - swim.thrill)) * 4.2 if swim.thrill > 0. else 0.
		at.y += lift
		var whale: Node3D = swim.whale
		var nose := (ahead - at + Vector3(0, .0001, 0)).normalized()
		var x := -nose
		var z := x.cross(Vector3.UP).normalized()
		whale.transform = Transform3D(Basis(x, z.cross(x).normalized(), z), at)
		whale.rotate_object_local(Vector3.RIGHT, swim.thrill * TAU)
		for fin in ["FlukeLeft", "FlukeRight"]:
			whale.get_node(fin).rotation.z = .2 * sin(seconds * 2.2 + swim.start)
		var under: bool = at.y < SEA_LEVEL + swim.size * .05
		if under != swim.under:
			swim.under = under
			splash(Vector3(at.x, SEA_LEVEL + .06, at.z), swim.size)
	for mark in splashes:
		mark.age += dt
		mark.ring.visible = mark.age < 2.4
		if mark.ring.visible:
			var grown: float = mark.reach * (.35 + mark.age * .9)
			mark.ring.scale = Vector3(grown, .08, grown)
			mark.foam.albedo_color.a = .55 * (1. - mark.age / 2.4) * (1. - .5 * dusk)
	for ferry in ferries:
		ferry.at += dt * ferry.pace * (.3 if still else 1.)
		var across: float = fposmod(ferry.at, 190.) - 95.
		var boat: Node3D = ferry.boat
		boat.position = Vector3(across * ferry.way, SEA_LEVEL + .25 + .12 * sin(seconds * .8 + ferry.lane), ferry.lane)
		boat.rotation = Vector3(.02 * sin(seconds * .7), 0. if ferry.way > 0 else PI, .025 * sin(seconds * .9 + 1.))
	# The crowd sways, and a side that has just scored jumps.
	for side in 2:
		joy[side] = move_toward(joy[side], 1. if winner == side else 0., dt / 3.2)
	for n in fans.size():
		var fan: Dictionary = fans[n]
		var glad: float = joy[fan.side]
		var sad: float = joy[1 - fan.side] * (1. - glad)
		var hop: float = absf(sin(seconds * 7.5 + fan.beat)) * .42 * glad
		var sway: float = sin(seconds * 1.3 + fan.beat) * .05
		var foot: Vector3 = fan.spot + Vector3(sway, hop, 0)
		var grow := Vector3(1., fan.tall * (1. - .12 * sad), 1.)
		bodies.set_instance_transform(n, Transform3D(Basis.from_scale(grow), foot + Vector3(0, .4 * grow.y, 0)))
		var crown: Vector3 = foot + Vector3(0, .93 * grow.y, 0)
		heads.set_instance_transform(n, Transform3D(Basis.IDENTITY, crown))
		caps.set_instance_transform(n, Transform3D(Basis.IDENTITY, crown + Vector3(0, .13, 0)))
		# One arm holds a lantern up. It goes higher with a cheer and droops with a loss.
		var raised: float = .86 + .5 * glad + .06 * sin(seconds * 2. + fan.beat) - .32 * sad
		var hand: Vector3 = foot + Vector3(.27, raised * grow.y, .08)
		var shoulder: Vector3 = foot + Vector3(.13, .7 * grow.y, .02)
		var reach := (hand - shoulder).normalized()
		var across := reach.cross(Vector3.FORWARD).normalized()
		arms.set_instance_transform(
			n, Transform3D(Basis(across, reach, across.cross(reach)), shoulder.lerp(hand, .5))
		)
		lamps.set_instance_transform(n, Transform3D(Basis.IDENTITY, hand + Vector3(0, .1, 0)))
		var flame: Color = Color("#ffcf7d").lerp(CREW[fan.side], .25 + .75 * glad)
		var flicker: float = .82 + .18 * sin(seconds * 9. + fan.beat * 3.)
		lamps.set_instance_color(n, flame * (flicker * lights * (1. - .6 * sad)))


func whale_place(swim: Dictionary, when: float) -> Vector3:
	var turn: float = when * TAU / swim.period + swim.start
	return Vector3(
		swim.centre.x + swim.radius * cos(turn),
		swim.ride + swim.leap * sin(turn * swim.beats + swim.start * 2.),
		swim.centre.y + swim.radius * .62 * sin(turn)
	)


func splash(at: Vector3, size: float) -> void:
	var oldest: Dictionary = splashes[0]
	for mark in splashes:
		if mark.age > oldest.age:
			oldest = mark
	oldest.age = 0.
	oldest["reach"] = size * .42
	oldest.ring.position = at
