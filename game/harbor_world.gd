extends Node3D
## Everything beyond the dock rail: Saturn with the sun slipping behind it, a sea that mirrors the
## sky, whales that fly and surface, a lighthouse, ferries, lanterns and the crowd behind the rail.
## Presentation only. The court never reads this node.
const Game = preload("res://game/star_match.gd")
## A splash or a firework, for the sound to follow: what it was, where, and how big.
signal heard(kind: String, where: Vector3, power: float)
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
	if (!fine && !open_sky) {
		// In the water the planet is a soft glow, not a second planet.
		col = mix(col, mix(horizon, mid, 0.4), 0.55);
	}
	// Keep the brightest sky inside the range the tone mapper renders as colour, not white, and
	// push the colour a little so the sunset stays a sunset.
	col = max(col, vec3(0.0));
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	return mix(vec3(grey), col, 1.3) * 0.66;
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
## Whales are simulated, not played back: each has a heading, a speed and a vertical speed, steers
## smoothly, leaps under gravity and throws up spray where it meets the water.
const LEAP_GRAVITY := 7.4
var pod: Array = []
var foam_rings: Array = []
var sprays: Array = []
var spray_turn := 0
var ripples: Array = [Vector4(0, 0, 99, 0), Vector4(0, 0, 99, 0), Vector4(0, 0, 99, 0), Vector4(0, 0, 99, 0)]
var ripple_turn := 0
var ferries: Array = []
## The crowd is one mesh drawn many times. A shader does all of its movement.
var bots := MultiMesh.new()
var bot_look := ShaderMaterial.new()
var joy := [0., 0.]
var lights := 1.0
var shells: Array = []
var finale_clock := 0.
var fire_ramps := {}
var drift := CPUParticles3D.new()
var sparks: Array = []
var winner := -1
var spark_look: StandardMaterial3D


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
uniform vec4 ripple0 = vec4(0.0, 0.0, 99.0, 0.0);
uniform vec4 ripple1 = vec4(0.0, 0.0, 99.0, 0.0);
uniform vec4 ripple2 = vec4(0.0, 0.0, 99.0, 0.0);
uniform vec4 ripple3 = vec4(0.0, 0.0, 99.0, 0.0);
varying vec3 world_pos;
// A splash at ring.xy, ring.z seconds ago, of strength ring.w: a packet of waves moving outward.
vec2 spread(vec4 ring, vec2 p) {
	vec2 to = p - ring.xy;
	float d = length(to) + 0.001;
	float front = ring.z * 6.5;
	float packet = exp(-pow((d - front) * 0.32, 2.0));
	return to / d * sin((d - front) * 1.8) * packet * ring.w * exp(-ring.z * 0.5);
}
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
	// Calm with distance: far ripples are smaller than a pixel and would only shimmer and streak.
	slope /= 1.0 + far * 0.22;
	slope += spread(ripple0, p) + spread(ripple1, p) + spread(ripple2, p) + spread(ripple3, p);
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
	effects()


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


## One whale, in units of its own length, nose at -x: a lofted body, flukes, fins and a dorsal fin.
func whale_mesh() -> ArrayMesh:
	# Body: a smooth loft through these slices (along, height, width), sampled finely and shaded
	# with shared normals so it reads as skin, not facets.
	var slices := [
		Vector3(-.5, .004, .004),
		Vector3(-.475, .052, .062),
		Vector3(-.42, .098, .118),
		Vector3(-.34, .132, .156),
		Vector3(-.22, .146, .17),
		Vector3(-.08, .14, .16),
		Vector3(.06, .12, .134),
		Vector3(.18, .094, .098),
		Vector3(.28, .066, .064),
		Vector3(.36, .042, .038),
		Vector3(.42, .026, .022),
		Vector3(.47, .016, .013)
	]
	var around := 30
	var rows: Array = []
	for n in 46:
		var f := float(n) / 45. * (slices.size() - 1)
		var k := mini(int(f), slices.size() - 2)
		var t := f - k
		var a: Vector3 = slices[maxi(k - 1, 0)]
		var b: Vector3 = slices[k]
		var c: Vector3 = slices[k + 1]
		var d: Vector3 = slices[mini(k + 2, slices.size() - 1)]
		var cut: Vector3 = b.cubic_interpolate(c, a, d, t)
		var row: Array = []
		for j in around:
			var ang := TAU * j / around
			row.append(Vector3(cut.x, sin(ang) * cut.y + .018 * sin(cut.x * 7.), cos(ang) * cut.z))
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in rows.size() - 1:
		for j in around:
			var k := (j + 1) % around
			for v in [rows[n][j], rows[n + 1][j], rows[n][k], rows[n][k], rows[n + 1][j], rows[n + 1][k]]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	# Fins are thin blades with their own flat shading, in a second surface.
	var fins := SurfaceTool.new()
	fins.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1., 1.]:
		for blade in [
			[Vector3(.44, 0, 0), Vector3(.5, .004, side * .19), Vector3(.585, .002, side * .155), Vector3(.52, 0, 0)],
			[Vector3(-.25, -.07, side * .13), Vector3(-.17, -.15, side * .36), Vector3(-.08, -.13, side * .31), Vector3(-.13, -.07, side * .12)]
		]:
			for v in [blade[0], blade[1], blade[2], blade[0], blade[2], blade[3]]:
				fins.add_vertex(v)
	for v in [Vector3(.08, .115, 0), Vector3(.17, .175, 0), Vector3(.215, .1, 0)]:
		fins.add_vertex(v)
	fins.generate_normals()
	fins.commit(mesh)
	return mesh


const WHALE := """shader_type spatial;
render_mode cull_disabled;
uniform float seconds = 0.0;
uniform float stroke = 1.0;
uniform float beat = 0.0;
uniform float glow = 0.3;
uniform vec3 glow_tint : source_color = vec3(0.35, 1.0, 0.85);
uniform vec3 back : source_color = vec3(0.05, 0.11, 0.16);
varying vec3 skin;
float grain(vec3 p) {
	vec3 i = floor(p), w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	vec4 n = dot(i, vec3(1.0, 67.0, 139.0)) + vec4(0.0, 67.0, 139.0, 206.0);
	vec4 a = fract(sin(n) * 43758.53), b = fract(sin(n + 1.0) * 43758.53);
	vec4 c = mix(a, b, w.x);
	return mix(mix(c.x, c.y, w.y), mix(c.z, c.w, w.y), w.z);
}
void vertex() {
	skin = VERTEX;
	// The stroke runs down the spine and grows towards the tail, so the flukes do the work.
	float along = clamp(VERTEX.x + 0.5, 0.0, 1.1);
	float wave = beat - along * 3.6;
	VERTEX.y += sin(wave) * along * along * 0.085 * stroke;
	VERTEX.y += cos(wave + 1.0) * (1.0 - along) * 0.014 * stroke;
}
void fragment() {
	float pores = grain(skin * 70.0);
	float marbling = grain(skin * 22.0 + pores * 0.3);
	float spots = smoothstep(0.66, 0.84, marbling + 0.16 * pores);
	vec3 dorsal = mix(back, back * 2.4 + vec3(0.10, 0.14, 0.17), spots);
	float belly = 1.0 - smoothstep(-0.07, -0.005, skin.y + 0.014 * marbling);
	float pleat = smoothstep(0.72, 0.99, cos(skin.z * 190.0 + skin.x * 17.0));
	ALBEDO = mix(dorsal, vec3(0.62, 0.66, 0.62) * (1.0 - pleat * 0.18), belly);
	ROUGHNESS = 0.34 + 0.22 * pores;
	METALLIC = 0.05;
	// Living light: a dotted line down each flank and a pulse that runs from head to tail.
	float along = skin.x + 0.5;
	float row = 1.0 - smoothstep(0.010, 0.034, abs(skin.y - 0.03 - 0.018 * sin(along * 9.0)));
	float dots = 1.0 - smoothstep(0.16, 0.34, abs(fract(along * 26.0) - 0.5));
	float run = 0.3 + 0.7 * pow(0.5 + 0.5 * sin(along * 11.0 - seconds * 2.6), 3.0);
	float flank = smoothstep(0.02, 0.07, abs(skin.z)) * (1.0 - smoothstep(0.88, 0.97, along));
	EMISSION = glow_tint * row * dots * run * flank * glow * 3.4;
}
"""


func whales() -> void:
	var shape := whale_mesh()
	var code := Shader.new()
	code.code = WHALE
	for spec in [
		{"long": 14., "home": Vector2(6, -52), "roam": 30., "cruise": 5.0, "sky": 0., "tint": Color("#58ffe0"), "back": Color("#0c1c2a")},
		{"long": 9., "home": Vector2(-13, -29), "roam": 15., "cruise": 4.3, "sky": 0., "tint": Color("#ff8be0"), "back": Color("#16203a")},
		{"long": 5., "home": Vector2(-13, -29), "roam": 15., "cruise": 4.6, "sky": 0., "tint": Color("#ffe27a"), "back": Color("#1c2a3a"), "lead": 1},
		{"long": 11., "home": Vector2(31, -36), "roam": 18., "cruise": 4.7, "sky": 0., "tint": Color("#7ab8ff"), "back": Color("#0e1b30")},
		{"long": 12., "home": Vector2(-4, -34), "roam": 36., "cruise": 6.4, "sky": 8.5, "tint": Color("#9dff8a"), "back": Color("#10242b")},
		{"long": 7.5, "home": Vector2(16, -26), "roam": 27., "cruise": 5.6, "sky": 6., "tint": Color("#ffb86b"), "back": Color("#1a2236")}
	]:
		var look := ShaderMaterial.new()
		look.shader = code
		look.set_shader_parameter("glow_tint", spec.tint)
		look.set_shader_parameter("back", spec.back)
		var body := plain(room.draw(self, shape, Vector3.ZERO, look))
		body.scale = Vector3.ONE * spec.long
		spec["body"] = body
		spec["look"] = look
		spec["seed"] = randf() * 100.
		var turn := randf() * TAU
		spec["heading"] = turn
		spec["at"] = Vector3(spec.home.x + cos(turn) * spec.roam * .5, spec.sky if spec.sky > 0. else SEA_LEVEL - .6, spec.home.y + sin(turn) * spec.roam * .5)
		spec["turn"] = 0.
		spec["vy"] = 0.
		spec["pace"] = spec.cruise
		spec["pitch"] = 0.
		spec["roll"] = 0.
		spec["spin"] = 0.
		spec["beat"] = randf() * TAU
		spec["stroke"] = 1.
		spec["state"] = "glide" if spec.sky > 0. else "cruise"
		spec["clock"] = randf_range(4., 16.) if spec.sky == 0. else randf_range(18., 40.)
		spec["blown"] = false
		spec["wet"] = spec.sky == 0.
		spec["thrill"] = false
		pod.append(spec)
	# Rings of foam where a whale breaks the surface.
	for n in 8:
		var foam := StandardMaterial3D.new()
		foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		foam.albedo_color = Color(.85, .97, 1., 0.)
		var ring: MeshInstance3D = plain(room.torus(self, Vector3.ZERO, .8, 1., foam))
		ring.hide()
		foam_rings.append({"ring": ring, "foam": foam, "age": 9., "reach": 1.})


## One whale for one frame. Steering, speed and height all ease towards what it wants, so nothing
## about its path repeats or snaps.
func swim(w: Dictionary, dt: float) -> void:
	var t: float = seconds + w.seed
	var flat := Vector2(w.at.x, w.at.z)
	var wander: float = .35 * sin(t * .13) + .28 * sin(t * .071 + 1.7) + .12 * sin(t * .31 + 4.)
	var want: float = w.heading + wander
	var target: Vector2 = w.home
	var leash: float = w.roam
	if w.has("lead"):
		# A calf keeps station off its mother's flank.
		var mother: Dictionary = pod[w.lead]
		var ahead := Vector2(cos(mother.heading), sin(mother.heading))
		target = Vector2(mother.at.x, mother.at.z) - ahead * mother.long * .7 + ahead.orthogonal() * 3.2
		leash = 2.5
	var away := target - flat
	var pull: float = clampf((away.length() - leash) / maxf(leash * .5, 4.), 0., 1.)
	# Whales read best side-on, so they mostly travel along the horizon, not towards us.
	if not w.has("lead"):
		want = lerp_angle(want, 0. if cos(w.heading) >= 0. else PI, .5 * (1. - pull))
	if pull > 0.:
		want = lerp_angle(want, away.angle(), pull)
	# Nothing swims or flies through the dock. The nearer it gets, the harder it turns away.
	var shy: float = clampf((flat.y + 24.) / 7., 0., 1.) * float(absf(flat.x) < 50.)
	if shy > 0.:
		want = lerp_angle(want, -PI * .5, shy)
	var agile: float = .55 + .9 * shy
	w.turn = lerpf(w.turn, clampf(angle_difference(w.heading, want), -1., 1.) * agile, 1. - exp(-dt * (1.6 + 2. * shy)))
	w.heading += w.turn * dt
	var forward := 1.
	var bank: float = -w.turn * (1.5 if w.sky > 0. else .6)
	var effort := 1.
	match str(w.state):
		"cruise":
			# Porpoising: the back and the blowhole come up for air every few seconds.
			var breath: float = sin(t * .55)
			var ride: float = SEA_LEVEL - w.long * .055 + w.long * .05 * breath
			w.vy = lerpf(w.vy, (ride - w.at.y) * 1.5, 1. - exp(-dt * 3.))
			w.pace = lerpf(w.pace, w.cruise, 1. - exp(-dt))
			if breath > .93 and not w.blown:
				w.blown = true
				spout(w)
			elif breath < 0.:
				w.blown = false
			w.clock -= dt
			if (w.clock <= 0. or w.thrill) and flat.y < -17.:
				w.thrill = false
				w.state = "dive"
				w.clock = 1.1
		"dive":
			# Down and faster, to get a run at the surface.
			w.vy = lerpf(w.vy, -w.long * .5, 1. - exp(-dt * 3.))
			w.pace = lerpf(w.pace, w.cruise * 1.55, 1. - exp(-dt * 2.))
			effort = 1.7
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "leap"
				w.wet = true
				var apex: float = SEA_LEVEL + w.long * randf_range(.26, .44)
				w.vy = sqrt(2. * LEAP_GRAVITY * (apex - w.at.y))
				w.spin = randf_range(-1., 1.) * 1.9
		"leap":
			# From here it is a thrown body: only gravity acts until it is back under.
			w.vy -= LEAP_GRAVITY * dt
			forward = .72
			effort = .35 if not w.wet else 1.8
			# Clear of the water it turns over in the air, as the big ones do.
			if not w.wet:
				w.roll += w.spin * dt
			bank = w.roll
			if w.wet and w.at.y > SEA_LEVEL - w.long * .02:
				w.wet = false
				splash(w, .6)
			elif not w.wet and w.vy < 0. and w.at.y < SEA_LEVEL - w.long * .03:
				w.wet = true
				splash(w, 1.)
				w.state = "settle"
				w.clock = 1.8
		"settle":
			# The water takes the fall out of it and it rolls upright again.
			w.vy = lerpf(w.vy, (SEA_LEVEL - w.long * .16 - w.at.y) * 1.2, 1. - exp(-dt * 3.2))
			w.pace = lerpf(w.pace, w.cruise * .7, 1. - exp(-dt * 2.))
			bank = 0.
			effort = .7
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "cruise"
				w.clock = randf_range(9., 24.)
		"glide":
			# A sky whale: long slow strokes, banking into its turns.
			var height: float = w.sky + 1.9 * sin(t * .21) + .8 * sin(t * .47)
			w.vy = lerpf(w.vy, (height - w.at.y) * .8, 1. - exp(-dt * 1.5))
			w.pace = lerpf(w.pace, w.cruise * (1. - .12 * sin(t * .21)), 1. - exp(-dt))
			effort = .75
			w.clock -= dt
			if (w.clock <= 0. or w.thrill) and flat.y < -19.:
				w.thrill = false
				w.state = "plunge"
		"plunge":
			# Now and then one folds its fins and drops into the sea.
			w.vy -= LEAP_GRAVITY * 1.3 * dt
			effort = .3
			if w.at.y < SEA_LEVEL - w.long * .03:
				splash(w, 1.15)
				w.state = "under"
				w.clock = 2.4
		"under":
			w.vy = lerpf(w.vy, (SEA_LEVEL - w.long * .45 - w.at.y) * 1.4, 1. - exp(-dt * 3.))
			w.pace = lerpf(w.pace, w.cruise * 1.3, 1. - exp(-dt * 2.))
			effort = 1.6
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "climb"
				w.wet = true
				w.vy = sqrt(2. * LEAP_GRAVITY * (w.sky * .75 - w.at.y))
		"climb":
			# Out again on its own momentum, then back up to where it flies.
			w.vy -= LEAP_GRAVITY * dt
			effort = 1.5
			if w.wet and w.at.y > SEA_LEVEL:
				w.wet = false
				splash(w, .7)
			if w.vy < 1.2:
				w.state = "glide"
				w.clock = randf_range(26., 55.)
	w.at += Vector3(cos(w.heading), 0, sin(w.heading)) * w.pace * forward * dt
	w.at.y += w.vy * dt
	if absf(w.at.x) < 46.:
		w.at.z = minf(w.at.z, -15.5)
	w.pitch = lerp_angle(w.pitch, atan2(w.vy, maxf(1.2, w.pace * forward)), 1. - exp(-dt * 5.))
	w.roll = lerp_angle(w.roll, bank, 1. - exp(-dt * 2.2))
	# Faster swimming is a faster stroke. In the air the tail hardly moves.
	w.stroke = lerpf(w.stroke, effort, 1. - exp(-dt * 4.))
	w.beat += dt * (2.2 + w.pace * .55) * (10. / (6. + w.long))
	var nose := Vector3(cos(w.heading) * cos(w.pitch), sin(w.pitch), sin(w.heading) * cos(w.pitch))
	var x := -nose
	var z := x.cross(Vector3.UP).normalized()
	var body: MeshInstance3D = w.body
	body.transform = Transform3D(
		(Basis(x, z.cross(x).normalized(), z) * Basis(Vector3.RIGHT, w.roll)).scaled(Vector3.ONE * w.long), w.at
	)
	var look: ShaderMaterial = w.look
	look.set_shader_parameter("seconds", seconds)
	look.set_shader_parameter("beat", w.beat)
	look.set_shader_parameter("stroke", w.stroke)
	look.set_shader_parameter("glow", .05 + 1.6 * pow(dusk, 1.5) + 1.4 * (1. - lights))


## Water thrown up where a whale goes through the surface, a ring of foam and a ripple that spreads.
func splash(w: Dictionary, power: float) -> void:
	var where := Vector3(w.at.x, SEA_LEVEL + .08, w.at.z)
	var big: float = sqrt(w.long / 10.) * power
	var jet: CPUParticles3D = sprays[spray_turn]
	spray_turn = (spray_turn + 1) % sprays.size()
	jet.position = where
	jet.emission_sphere_radius = w.long * .09
	jet.initial_velocity_min = 4.5 * big
	jet.initial_velocity_max = 12.5 * big
	jet.scale_amount_min = .5 * big
	jet.scale_amount_max = 1.7 * big
	jet.restart()
	jet.emitting = true
	var oldest: Dictionary = foam_rings[0]
	for mark in foam_rings:
		if mark.age > oldest.age:
			oldest = mark
	oldest.age = 0.
	oldest.reach = w.long * .4 * power
	oldest.ring.position = where
	ripples[ripple_turn] = Vector4(where.x, where.z, 0., .55 * big)
	heard.emit("splash", where, big)
	ripple_turn = (ripple_turn + 1) % ripples.size()


## The breath a whale blows when it comes up for air.
func spout(w: Dictionary) -> void:
	var jet: CPUParticles3D = sprays[spray_turn]
	spray_turn = (spray_turn + 1) % sprays.size()
	var nose := Vector3(cos(w.heading), 0, sin(w.heading))
	jet.position = Vector3(w.at.x, SEA_LEVEL + .1, w.at.z) + nose * w.long * .28
	jet.emission_sphere_radius = .15
	jet.initial_velocity_min = 2.5
	jet.initial_velocity_max = 5.5 * sqrt(w.long / 10.)
	jet.scale_amount_min = .3
	jet.scale_amount_max = .8
	jet.restart()
	jet.emitting = true


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


## Copy a simple shape into the dock-bot mesh. `kind` says what it is made of (0 paint, 1 dark
## metal, 2 the face screen, 3 a light) and `arm` marks the raised arm, which the shader waves.
func add_part(st: SurfaceTool, shape: PrimitiveMesh, where: Transform3D, kind: float, arm: float = 0.) -> void:
	var arrays := shape.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in order:
		st.set_normal(where.basis * normals[i])
		st.set_uv(uvs[i])
		st.set_uv2(Vector2(kind, arm))
		st.add_vertex(where * points[i])


const BOT := """shader_type spatial;
uniform float seconds = 0.0;
uniform float joy_gold = 0.0;
uniform float joy_blue = 0.0;
uniform float lights = 1.0;
uniform vec3 gold : source_color = vec3(1.0, 0.75, 0.34);
uniform vec3 blue : source_color = vec3(0.34, 0.85, 0.93);
varying float kind;
varying float crew;
varying float cheer;
varying float gloom;
varying float beat;
void vertex() {
	kind = UV2.x;
	beat = INSTANCE_CUSTOM.x;
	crew = INSTANCE_CUSTOM.y;
	cheer = mix(joy_gold, joy_blue, crew);
	gloom = mix(joy_blue, joy_gold, crew) * (1.0 - cheer);
	float t = seconds * (6.0 + 2.5 * fract(beat * 3.7)) + beat * 5.0;
	float bounce = abs(sin(t));
	float land = 1.0 - smoothstep(0.0, 0.35, bounce);
	vec3 v = VERTEX;
	if (UV2.y > 0.5) {
		// The raised arm and its light stick swing about the shoulder.
		vec3 pivot = vec3(0.25, 0.62, 0.0);
		float a = -0.2 + 0.22 * sin(seconds * 1.6 + beat * 9.0) + cheer * 0.75 * sin(t * 0.5) - gloom * 1.35;
		vec3 r = v - pivot;
		v = pivot + vec3(r.x * cos(a) - r.y * sin(a), r.x * sin(a) + r.y * cos(a), r.z);
	}
	// Squash on landing, stretch in the air, then the hop itself.
	float squash = cheer * land * 0.24;
	v.y *= (1.0 - squash) * INSTANCE_CUSTOM.z * (1.0 - 0.10 * gloom);
	v.xz *= 1.0 + squash * 0.6;
	v.y += cheer * 0.55 * bounce + 0.04 * sin(seconds * 2.1 + beat * 7.0);
	v.x += 0.035 * sin(seconds * 1.1 + beat * 4.0) * v.y;
	// A bot whose side has just been scored on slumps forward.
	float lean = gloom * 0.38;
	v.yz = vec2(v.y * cos(lean) - v.z * sin(lean), v.y * sin(lean) + v.z * cos(lean));
	VERTEX = v;
}
void fragment() {
	vec3 crew_tint = mix(gold, blue, crew);
	vec3 albedo = COLOR.rgb;
	vec3 emit = vec3(0.0);
	float metal = 0.15;
	float rough = 0.42;
	if (kind > 0.5 && kind < 1.5) {
		albedo = vec3(0.13, 0.16, 0.20);
		metal = 0.65;
		rough = 0.38;
	} else if (kind > 1.5 && kind < 2.5) {
		// A face on a screen: round eyes, happy arcs when cheering, flat lines when glum.
		albedo = vec3(0.02, 0.03, 0.05);
		vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
		p.x *= 1.35;
		float blink = step(0.955, fract(seconds * 0.23 + beat * 3.0));
		vec2 e = vec2(abs(p.x) - 0.52, p.y - 0.2);
		float glad = smoothstep(0.15, 0.55, cheer);
		float glum = smoothstep(0.15, 0.55, gloom);
		float round_eye = 1.0 - smoothstep(0.15, 0.2, length(e / vec2(1.0, mix(1.0, 0.14, blink))));
		float arc_eye = (1.0 - smoothstep(0.035, 0.07, abs(length(e + vec2(0.0, 0.12)) - 0.2))) * step(-0.12, e.y);
		float flat_eye = (1.0 - smoothstep(0.035, 0.07, abs(e.y + 0.35 * e.x))) * (1.0 - smoothstep(0.2, 0.25, abs(e.x)));
		float eyes = mix(mix(round_eye, arc_eye, glad), flat_eye, glum);
		float bend = mix(0.3, 1.0, glad) - 1.5 * glum;
		float curve = -0.48 + bend * (p.x * p.x - 0.12);
		float mouth = (1.0 - smoothstep(0.035, 0.075, abs(p.y - curve))) * (1.0 - smoothstep(0.4, 0.48, abs(p.x)));
		float lit = clamp(eyes + mouth, 0.0, 1.0);
		emit = mix(vec3(0.45, 0.95, 1.0), crew_tint, 0.3 + 0.6 * cheer) * lit * (1.8 + 1.6 * cheer) * (0.3 + 0.7 * lights);
	} else if (kind > 2.5) {
		albedo = crew_tint;
		float flick = 0.85 + 0.15 * sin(seconds * 9.0 + beat * 31.0);
		emit = crew_tint * (1.5 + 2.6 * cheer) * flick * lights * (1.0 - 0.7 * gloom);
	}
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
}
"""


## Bleachers behind the far rail, full of small hovering dock-bots with light sticks. The half by
## the gold ring cheers for gold, the other half for blue.
func crowd() -> void:
	var step_mat: Material = room.metal("bleacher", "#2c3943", .7, .3)
	var edge: float = Game.BOUNDS.y + 2.1
	var spots: Array = []
	for block in 2:
		var x0 := 1.6 if block == 0 else -Game.RING - .3
		var x1 := Game.RING + .3 if block == 0 else -1.6
		for row in 3:
			var z: float = -edge - row * .92
			var top: float = .09 + row * .26
			plain(room.box(self, Vector3((x0 + x1) * .5, top - .25, z), Vector3(x1 - x0 + .6, .5, .9), step_mat))
			var count := int((x1 - x0) / .82)
			for k in count:
				spots.append([Vector3(lerpf(x0, x1, (k + .5) / count) + (row % 2) * .2, top + .06, z), block])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = .2
	trunk.bottom_radius = .245
	trunk.height = .46
	trunk.radial_segments = 12
	trunk.rings = 1
	add_part(st, trunk, Transform3D(Basis.IDENTITY, Vector3(0, .43, 0)), 0.)
	var skirt := CylinderMesh.new()
	skirt.top_radius = .19
	skirt.bottom_radius = .1
	skirt.height = .13
	skirt.radial_segments = 12
	skirt.rings = 1
	add_part(st, skirt, Transform3D(Basis.IDENTITY, Vector3(0, .135, 0)), 1.)
	var jet := CylinderMesh.new()
	jet.top_radius = .09
	jet.bottom_radius = .05
	jet.height = .05
	jet.radial_segments = 10
	jet.rings = 1
	add_part(st, jet, Transform3D(Basis.IDENTITY, Vector3(0, .045, 0)), 3.)
	var head := BoxMesh.new()
	head.size = Vector3(.36, .27, .29)
	add_part(st, head, Transform3D(Basis.IDENTITY, Vector3(0, .86, 0)), 0.)
	var screen := QuadMesh.new()
	screen.size = Vector2(.3, .21)
	add_part(st, screen, Transform3D(Basis.IDENTITY, Vector3(0, .86, .147)), 2.)
	var mast := CylinderMesh.new()
	mast.top_radius = .012
	mast.bottom_radius = .012
	mast.height = .15
	mast.radial_segments = 5
	mast.rings = 1
	add_part(st, mast, Transform3D(Basis.IDENTITY, Vector3(.08, 1.07, 0)), 1.)
	var bulb := SphereMesh.new()
	bulb.radius = .04
	bulb.height = .08
	bulb.radial_segments = 8
	bulb.rings = 4
	add_part(st, bulb, Transform3D(Basis.IDENTITY, Vector3(.08, 1.17, 0)), 3.)
	var limb := CapsuleMesh.new()
	limb.radius = .04
	limb.height = .3
	limb.radial_segments = 6
	limb.rings = 2
	add_part(st, limb, Transform3D(Basis.IDENTITY, Vector3(-.28, .47, 0)), 1.)
	add_part(st, limb, Transform3D(Basis.IDENTITY, Vector3(.25, .77, 0)), 1., 1.)
	var stick := CapsuleMesh.new()
	stick.radius = .032
	stick.height = .5
	stick.radial_segments = 6
	stick.rings = 2
	add_part(st, stick, Transform3D(Basis.IDENTITY, Vector3(.25, 1.14, 0)), 3., 1.)
	bot_look.shader = Shader.new()
	bot_look.shader.code = BOT
	bot_look.set_shader_parameter("gold", CREW[0])
	bot_look.set_shader_parameter("blue", CREW[1])
	bots.transform_format = MultiMesh.TRANSFORM_3D
	bots.use_colors = true
	bots.use_custom_data = true
	bots.mesh = st.commit()
	bots.instance_count = spots.size()
	var paints := [
		Color("#ff5d8f"), Color("#ffb000"), Color("#18d4c9"), Color("#8a6bff"),
		Color("#9bea3a"), Color("#ff7a2f"), Color("#3fa9ff"), Color("#f4f0e6")
	]
	for n in spots.size():
		var tall := randf_range(.85, 1.2)
		bots.set_instance_transform(
			n, Transform3D(Basis(Vector3.UP, randf_range(-.25, .25)).scaled(Vector3.ONE * randf_range(.92, 1.12)), spots[n][0])
		)
		bots.set_instance_color(n, paints[randi() % paints.size()])
		bots.set_instance_custom_data(n, Color(randf() * TAU, float(spots[n][1]), tall, 0.))
	var stand := MultiMeshInstance3D.new()
	stand.multimesh = bots
	stand.material_override = bot_look
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lifts them off their spots, so give the engine room before it hides them.
	stand.extra_cull_margin = 2.
	add_child(stand)


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


## Spray for the whales and fireworks for the goals. All of it is made once and reused.
func effects() -> void:
	spark_look = StandardMaterial3D.new()
	spark_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_look.vertex_color_use_as_albedo = true
	spark_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var drop := SphereMesh.new()
	drop.radius = .11
	drop.height = .22
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = spark_look
	var mist := Gradient.new()
	mist.set_color(0, Color(1, 1, 1, .95))
	mist.add_point(.5, Color(.78, .93, 1., .8))
	mist.set_color(1, Color(.6, .85, 1., 0.))
	for n in 6:
		var jet := CPUParticles3D.new()
		add_child(jet)
		jet.mesh = drop
		jet.emitting = false
		jet.one_shot = true
		jet.amount = 90
		jet.lifetime = 1.7
		jet.explosiveness = .9
		jet.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		jet.direction = Vector3.UP
		jet.spread = 40.
		jet.gravity = Vector3(0, -9.8, 0)
		jet.color_ramp = mist
		sprays.append(jet)
	var ember := SphereMesh.new()
	ember.radius = .13
	ember.height = .26
	ember.radial_segments = 6
	ember.rings = 3
	ember.material = spark_look
	for n in 4:
		var shell := CPUParticles3D.new()
		add_child(shell)
		shell.mesh = ember
		shell.emitting = false
		shell.one_shot = true
		shell.amount = 80
		shell.lifetime = 1.6
		shell.explosiveness = .96
		shell.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		shell.emission_sphere_radius = .2
		shell.direction = Vector3.UP
		shell.spread = 180.
		shell.gravity = Vector3(0, -2.6, 0)
		shell.damping_min = 2.2
		shell.damping_max = 3.
		shell.initial_velocity_min = 6.
		shell.initial_velocity_max = 11.
		shell.scale_amount_min = .5
		shell.scale_amount_max = 1.3
		shells.append(shell)


## One firework shell over the water, in a crew's colour.
func firework(tint: Color) -> void:
	var shell: CPUParticles3D = shells[randi() % shells.size()]
	shell.position = Vector3(randf_range(-20., 20.), randf_range(3.5, 7.5), randf_range(-19., -30.))
	var key := tint.to_html()
	if not fire_ramps.has(key):
		var fire := Gradient.new()
		fire.set_color(0, Color(1, 1, 1, 1))
		fire.add_point(.18, tint.lightened(.25))
		fire.add_point(.7, tint)
		fire.set_color(1, Color(tint.r, tint.g, tint.b, 0.))
		fire_ramps[key] = fire
	shell.color_ramp = fire_ramps[key]
	shell.restart()
	shell.emitting = true
	heard.emit("firework", shell.position, 2.2)
	pulse = maxf(pulse, .5)
	pulse_tint = tint


## Run each burst once, small and early, so its first real use does not cost a frame.
func warm() -> void:
	for burst in sprays + shells + sparks:
		burst.scale = Vector3.ONE * .001
		burst.restart()
		burst.emitting = true
	# The foam rings too: each is drawn once, faint and small, out on the water.
	for mark in foam_rings:
		mark.ring.position = Vector3(0, SEA_LEVEL + .05, -40)
		mark.ring.scale = Vector3.ONE * .01
		mark.foam.albedo_color.a = .02
		mark.age = 2.3
		mark.ring.show()
	var back := create_tween()
	back.tween_interval(2.2)
	back.tween_callback(func():
		for burst in sprays + shells + sparks:
			burst.scale = Vector3.ONE
	)


## A goal: the sky flushes with that crew's colour, their fans jump, fireworks go up and the
## whales nearest the excitement leap.
func cheer(team: int) -> void:
	pulse = 1.
	pulse_tint = CREW[team]
	joy[team] = 1.
	sparks[team].restart()
	sparks[team].emitting = true
	var show := create_tween()
	for n in 3:
		show.tween_callback(firework.bind(CREW[team]))
		show.tween_interval(.28)
	var keen := 0
	for w in pod:
		if keen < 2 and str(w.state) in ["cruise", "glide"]:
			w.thrill = true
			keen += 1


## The final whistle: the lighthouse and the sky take the winner's colour. -1 is a shared light.
func finale(team: int) -> void:
	winner = team
	finale_clock = 5.
	if team >= 0:
		joy[team] = 1.
		pulse = 1.
		pulse_tint = CREW[team]


func restart() -> void:
	winner = -1
	finale_clock = 0.
	joy = [0., 0.]
	pulse = 0.


## `night` runs from sunset to dark. `out` is the robots taking the harbor lights with them.
func animate(dt: float, night: float, chill: float, out: float, still: bool) -> void:
	var step := dt * (.3 if still else 1.)
	seconds += step
	dusk = move_toward(dusk, clampf(maxf(night, out), 0., 1.), dt * .5)
	cold = move_toward(cold, chill, dt * .8)
	pulse = move_toward(pulse, 0., dt * .55)
	lights = move_toward(lights, 1. - .88 * out, dt * .8)
	for n in ripples.size():
		ripples[n].z += step
		sea.set_shader_parameter("ripple%d" % n, ripples[n])
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
	drift.speed_scale = .3 if still else 1.
	for w in pod:
		swim(w, step)
	for mark in foam_rings:
		mark.age += step
		mark.ring.visible = mark.age < 2.6
		if mark.ring.visible:
			var grown: float = mark.reach * (.3 + mark.age * 1.1)
			mark.ring.scale = Vector3(grown, .08, grown)
			mark.foam.albedo_color.a = .6 * (1. - mark.age / 2.6) * (1. - .5 * dusk)
	for ferry in ferries:
		ferry.at += step * ferry.pace
		var across: float = fposmod(ferry.at, 190.) - 95.
		var boat: Node3D = ferry.boat
		# A ferry rides the same swell the sea is drawn with: it heaves, pitches and rolls on it.
		var swell: float = .16 * sin(seconds * .55 + across * .09) + .1 * sin(seconds * .42 + ferry.lane * .12)
		boat.position = Vector3(across * ferry.way, SEA_LEVEL + .28 + swell, ferry.lane)
		boat.rotation = Vector3(
			.05 * cos(seconds * .42 + ferry.lane * .12), 0. if ferry.way > 0 else PI, .045 * cos(seconds * .55 + across * .09)
		)
	# The crowd moves in its shader. It only needs to know the time and who is happy.
	for side in 2:
		joy[side] = move_toward(joy[side], 1. if winner == side else 0., dt / 3.4)
	bot_look.set_shader_parameter("seconds", seconds)
	bot_look.set_shader_parameter("joy_gold", joy[0])
	bot_look.set_shader_parameter("joy_blue", joy[1])
	bot_look.set_shader_parameter("lights", lights)
	# Fireworks keep going for a few seconds after the final whistle.
	if finale_clock > 0.:
		var before := finale_clock
		finale_clock -= dt
		if int(before / .45) != int(finale_clock / .45):
			firework(CREW[winner] if winner >= 0 else CREW[randi() % 2])
