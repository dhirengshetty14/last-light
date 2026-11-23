extends Node3D
## Everything beyond the dock rail: Saturn with the sun slipping behind it, a sea that mirrors the
## sky, whales that fly and surface, a lighthouse, lanterns and the crowd behind the rail. The
## floating islands, jellyfish, airships, boats and big wheel are in `sky_carnival.gd`.
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
	// A small icy moon high on the left.
	vec3 moon_at = normalize(vec3(-0.52, 0.44, -0.73));
	float moon_dist = 40.0;
	float mb = dot(d, moon_at * moon_dist);
	float md = mb * mb - (moon_dist * moon_dist - 1.0);
	if (open_sky && md > 0.0 && mb > 0.0) {
		vec3 mn = normalize(d * (mb - sqrt(md)) - moon_at * moon_dist);
		float craters = vnoise(mn.xy * 9.0 + mn.z * 3.0) * 0.5 + vnoise(mn.yz * 23.0) * 0.5;
		float lit_side = smoothstep(-0.4, 0.6, dot(mn, sun) + 0.35);
		vec3 ice = mix(vec3(0.62, 0.78, 0.95), vec3(0.95, 0.98, 1.0), craters);
		col = mix(col, ice * (0.25 + 0.95 * lit_side), 0.97);
		open_sky = false;
	}
	if (open_sky) {
		if (fine) {
			// Clouds of glowing gas high over the sea, slowly turning, brighter as night comes.
			vec2 q = vec2(d.x * 1.9 + d.z * 0.6, up * 4.5 + d.z * 0.8);
			float gas = fbm(q + vec2(seconds * 0.004, 0.0));
			float fold = fbm(q * 2.1 + vec2(7.0 - seconds * 0.006, gas * 2.0));
			float veil = smoothstep(0.42, 0.85, gas + 0.25 * fold) * smoothstep(0.08, 0.32, up) * (1.0 - smoothstep(0.7, 0.95, up));
			vec3 nebula = mix(vec3(1.0, 0.28, 0.72), vec3(0.22, 0.8, 1.0), smoothstep(0.3, 0.7, fold));
			col += nebula * veil * (0.10 + 0.5 * dusk);
		}
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
## The carnival out on the water and in the sky lives in its own node.
var carnival = preload("res://game/sky_carnival.gd").new()
## The crowd is one mesh drawn many times. A shader does all of its movement.
var bots := MultiMesh.new()
var bot_look := ShaderMaterial.new()
var joy := [0., 0.]
var cheered := [99., 99.]
var focus := Vector3(0, 1, 0)
var ola_at := 999.
var ola_way := 1.
var ola_clock := 22.
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
	add_child(carnival)
	carnival.build(room)
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


## A closed skin through a run of oval sections, each [centre, half-axis, half-axis]. `marks` is
## stored on every vertex of a section so the shader can tell a flipper from the body.
func loft(st: SurfaceTool, sections: Array, around: int, marks: Array) -> void:
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
				st.set_color(marks[corner[0]])
				st.add_vertex(rows[corner[0]][corner[1]])


## One humpback, in units of its own length, nose at -x. Body, flukes, long flippers and the small
## fin on its back are each a smooth closed skin with real thickness, so nothing reads as a card.
func whale_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Body slices: where along, how far the back rises, how far the belly hangs, half the width.
	# The throat is deep, the widest point is a third of the way back and the tail stock is tall
	# and narrow, which is what makes the silhouette a whale and not an airship.
	var slices := [
		Vector4(-.5, .004, .005, .005),
		Vector4(-.487, .021, .03, .033),
		Vector4(-.45, .04, .058, .062),
		Vector4(-.39, .057, .088, .09),
		Vector4(-.31, .073, .108, .108),
		Vector4(-.21, .087, .116, .116),
		Vector4(-.1, .094, .11, .112),
		Vector4(0., .092, .096, .1),
		Vector4(.1, .082, .078, .082),
		Vector4(.2, .068, .058, .06),
		Vector4(.29, .052, .04, .04),
		Vector4(.36, .038, .028, .026),
		Vector4(.42, .026, .019, .016),
		Vector4(.455, .017, .012, .01),
		Vector4(.478, .007, .005, .005)
	]
	var body: Array = []
	var plain_marks: Array = []
	for n in 50:
		var f := float(n) / 49. * (slices.size() - 1)
		var k := mini(int(f), slices.size() - 2)
		var cut: Vector4 = slices[k].cubic_interpolate(
			slices[k + 1], slices[maxi(k - 1, 0)], slices[mini(k + 2, slices.size() - 1)], f - k
		)
		body.append([Vector3(cut.x, (cut.y - cut.z) * .5, 0), Vector3(0, 0, maxf(cut.w, .004)), Vector3(0, maxf((cut.y + cut.z) * .5, .004), 0)])
		plain_marks.append(Color(0, 0, 0))
	loft(st, body, 30, plain_marks)
	for side in [-1., 1.]:
		# Flukes: swept back to a point, with the notch between them.
		var fluke: Array = []
		var fluke_marks: Array = []
		for n in 11:
			var s := n / 10.
			var lead := .428 + .1 * pow(s, 1.25)
			var chord := .082 * pow(1. - s * s, .7) + .006
			var trail := lead + chord - .022 * (1. - smoothstep(0., .35, s))
			fluke.append([
				Vector3((lead + trail) * .5, .002, side * .168 * s), Vector3((trail - lead) * .5, 0, 0), Vector3(0, .011 * (1. - .78 * s) + .0015, 0)
			])
			fluke_marks.append(Color(0, 0, 1))
		loft(st, fluke, 12, fluke_marks)
		# Flippers: a third of the body long, knuckled along the leading edge, hung low behind the head.
		var root := Vector3(-.2, -.07, side * .095)
		var reach := Vector3(.5, -.42, side * .76).normalized()
		var across := (Vector3.RIGHT - reach * reach.x).normalized()
		var face := reach.cross(across).normalized()
		var flipper: Array = []
		var flipper_marks: Array = []
		for n in 12:
			var u := n / 11.
			var half := .04 * pow(1. - u, .6) * (.7 + .3 * smoothstep(0., .25, u)) + .004 + .003 * sin(u * 23.) * (1. - u)
			flipper.append([
				root + reach * .29 * u + Vector3(.07 * u * u, 0, 0), across * half, face * (.009 * (1. - .7 * u) + .002)
			])
			flipper_marks.append(Color(0, maxf(u, .03), 1))
		loft(st, flipper, 10, flipper_marks)
	var fin: Array = []
	var fin_marks: Array = []
	for n in 7:
		var u := n / 6.
		fin.append([
			Vector3(.12 + .06 * u + .04 * u * u, .066 + .032 * u, 0), Vector3(.05 * pow(1. - u, .65) + .004, 0, 0), Vector3(0, 0, .0075 * (1. - u) + .0015)
		])
		fin_marks.append(Color(0, 0, 1))
	loft(st, fin, 10, fin_marks)
	st.index()
	st.generate_normals()
	return st.commit()


const WHALE := """shader_type spatial;
render_mode cull_disabled;
uniform float seconds = 0.0;
uniform float stroke = 1.0;
uniform float beat = 0.0;
uniform float bend = 0.0;
uniform float arch = 0.0;
uniform float wing = 0.1;
uniform float glow = 0.0;
uniform vec3 glow_tint : source_color = vec3(0.35, 1.0, 0.85);
uniform vec3 back : source_color = vec3(0.05, 0.11, 0.16);
varying vec3 skin;
varying vec3 part;
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
	part = COLOR.rgb;
	vec3 v = VERTEX;
	if (COLOR.g > 0.001) {
		// A flipper rows about its shoulder, and its tip follows a moment behind the root.
		float side = sign(v.z);
		vec3 root = vec3(-0.2, -0.07, side * 0.095);
		float lift = wing * (0.3 + sin(beat * 0.5 - COLOR.g * 1.5)) + 0.05 * sin(seconds * 0.6 + side);
		vec3 r = v - root;
		float span = side * r.z;
		v = root + vec3(r.x, r.y * cos(lift) + span * sin(lift), side * (span * cos(lift) - r.y * sin(lift)));
	}
	// The stroke runs down the spine and grows towards the tail, so the flukes do the work.
	float along = clamp(v.x + 0.5, 0.0, 1.1);
	float wave = beat - along * 3.4;
	v.y += sin(wave) * along * along * 0.08 * stroke;
	v.y += cos(wave + 1.0) * (1.0 - along) * 0.012 * stroke;
	// The flukes trail the tail stock: going up they tip down, going down they tip up.
	v.y -= max(v.x - 0.43, 0.0) * cos(beat - 3.16) * 0.6 * stroke;
	// The spine takes the curve of the path, into a turn and over the top of a dive.
	float curve = v.x * v.x - 0.06;
	v.z += bend * curve;
	v.y += arch * curve;
	VERTEX = v;
}
void fragment() {
	float fine = grain(skin * 60.0);
	float mid = grain(skin * 19.0 + 3.1) * 0.65 + grain(skin * 41.0) * 0.35;
	float broad = grain(skin * 6.0 + 11.0) * 0.7 + grain(skin * 13.0 + 5.0) * 0.3;
	float fin = part.b;
	float flipper = step(0.001, part.g);
	// Dark above, pale below, and the edge between them wanders like it does on a real animal.
	float mouth = -0.03 - 0.16 * (skin.x + 0.5);
	float edge = mix(mouth, mix(-0.04, -0.13, smoothstep(-0.05, 0.3, skin.x)), smoothstep(-0.34, -0.16, skin.x));
	float belly = 1.0 - smoothstep(-0.012, 0.012, skin.y - edge + 0.03 * (broad - 0.5) + 0.012 * (mid - 0.5));
	belly *= 1.0 - fin;
	// Soft mottling, with faint streaks running the length of the body.
	float streak = grain(vec3(skin.x * 5.0, skin.y * 55.0, skin.z * 55.0));
	vec3 top = back * (1.1 + 0.6 * broad) * (0.9 + 0.2 * streak) + vec3(0.015, 0.022, 0.03) * mid;
	vec3 pale = vec3(0.80, 0.81, 0.76) * (0.82 + 0.18 * mid);
	// Throat grooves run back from the chin and fade out by the navel.
	float throat = belly * (1.0 - smoothstep(-0.05, 0.08, skin.x));
	float groove = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(atan(skin.z, -skin.y + 0.02) * 30.0));
	pale *= 1.0 - 0.3 * groove * throat;
	vec3 col = mix(top, pale, belly);
	// Flippers and the underside of the flukes are blotched white, each animal in its own pattern.
	float blotch = smoothstep(0.38, 0.6, broad + 0.25 * mid - 0.25 * part.g);
	col = mix(col, mix(pale, top, blotch), flipper);
	float under_fluke = fin * (1.0 - flipper) * smoothstep(0.43, 0.46, skin.x) * step(skin.y, 0.0);
	col = mix(col, mix(top, pale, smoothstep(0.45, 0.7, broad + 0.3 * mid)), under_fluke);
	// The line of the mouth and a small dark eye just behind it.
	float side = smoothstep(0.03, 0.06, abs(skin.z));
	float lip = (1.0 - smoothstep(0.002, 0.006, abs(skin.y - mouth))) * (1.0 - smoothstep(-0.34, -0.3, skin.x)) * side;
	col *= 1.0 - 0.5 * lip;
	float eye = length(vec2(skin.x + 0.345, (skin.y + 0.03) * 1.25));
	col = mix(col, top * 1.35 + 0.02, (1.0 - smoothstep(0.008, 0.013, eye)) * side);
	col = mix(col, vec3(0.012, 0.012, 0.016), (1.0 - smoothstep(0.005, 0.0075, eye)) * side);
	ALBEDO = col;
	// Wet skin: a soft highlight and a sheen where it turns away from us.
	ROUGHNESS = 0.36 + 0.1 * mid + 0.05 * fine;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	RIM = 0.3;
	RIM_TINT = 0.5;
	// After dark the back carries a scatter of living lights, like stars seen in the water.
	float sparks = smoothstep(0.93, 0.995, grain(skin * 110.0)) * (1.0 - belly) * (1.0 - flipper);
	float breath = 0.55 + 0.45 * sin(seconds * 1.1 + skin.x * 19.0 + broad * 6.0);
	EMISSION = glow_tint * glow * (sparks * breath * 5.0 + 0.03);
}
"""


func whales() -> void:
	var shape := whale_mesh()
	var code := Shader.new()
	code.code = WHALE
	for spec in [
		{"long": 14., "home": Vector2(6, -54), "roam": 30., "cruise": 4.6, "sky": 0., "tint": Color("#58ffe0"), "back": Color("#16242f")},
		{"long": 10., "home": Vector2(-17, -39), "roam": 15., "cruise": 4.1, "sky": 0., "tint": Color("#ff8be0"), "back": Color("#1b2534")},
		{"long": 5., "home": Vector2(-17, -39), "roam": 15., "cruise": 4.3, "sky": 0., "tint": Color("#ffe27a"), "back": Color("#27323e"), "lead": 1},
		{"long": 11.5, "home": Vector2(30, -43), "roam": 18., "cruise": 4.4, "sky": 0., "tint": Color("#7ab8ff"), "back": Color("#131f2e")},
		{"long": 12., "home": Vector2(-10, -62), "roam": 30., "cruise": 5.4, "sky": 13., "tint": Color("#9dff8a"), "back": Color("#1a2a33")},
		{"long": 8., "home": Vector2(24, -56), "roam": 24., "cruise": 5., "sky": 9.5, "tint": Color("#ffb86b"), "back": Color("#222a3a")}
	]:
		var look := ShaderMaterial.new()
		look.shader = code
		look.set_shader_parameter("glow_tint", spec.tint)
		look.set_shader_parameter("back", spec.back)
		look.set_shader_parameter("wing", .34 if spec.sky > 0. else .1)
		var body := plain(room.draw(self, shape, Vector3.ZERO, look))
		body.scale = Vector3.ONE * spec.long
		spec["body"] = body
		spec["look"] = look
		spec["seed"] = randf() * 100.
		var turn := randf() * TAU
		spec["heading"] = turn
		spec["at"] = Vector3(
			spec.home.x + cos(turn) * spec.roam * .5, spec.sky if spec.sky > 0. else SEA_LEVEL - spec.long * .2, spec.home.y + sin(turn) * spec.roam * .5
		)
		spec["turn"] = 0.
		spec["pace"] = spec.cruise
		spec["vel"] = Vector3(cos(turn), 0, sin(turn)) * spec.cruise
		spec["pitch"] = 0.
		spec["tilt"] = 0.
		spec["roll"] = 0.
		spec["spin"] = 0.
		spec["beat"] = randf() * TAU
		spec["stroke"] = 1.
		spec["state"] = "glide" if spec.sky > 0. else "travel"
		spec["clock"] = randf_range(1., 6.) if spec.sky == 0. else randf_range(18., 40.)
		spec["breaths"] = randi_range(2, 4)
		spec["leap"] = false
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


## The nose angle that takes a whale to a height, gently: steep when far off, level as it arrives.
func nose_for(w: Dictionary, height: float, steep: float, ease := .3) -> float:
	return clampf((height - w.at.y) / (w.long * ease), -1., 1.) * steep


## One whale for one frame. A whale only ever swims where its nose points. It steers by turning and
## tipping its nose a little at a time, so every rise, dive and turn is a curve and nothing snaps.
## Out of the water a sea whale is a thrown body until it lands.
func swim(w: Dictionary, dt: float) -> void:
	if dt <= 0.:
		return
	var t: float = seconds + w.seed
	var long: float = w.long
	var flat := Vector2(w.at.x, w.at.z)
	var flyer: bool = w.sky > 0.
	# Small whales are nimble and big ones take their time.
	var limber: float = 7. / (5. + long)
	var wander: float = .35 * sin(t * .13) + .28 * sin(t * .071 + 1.7) + .12 * sin(t * .31 + 4.)
	var want: float = w.heading + wander
	var target: Vector2 = w.home
	var leash: float = w.roam
	if w.has("lead"):
		# A calf keeps station off its mother's flank.
		var mother: Dictionary = pod[w.lead]
		var ahead := Vector2(cos(mother.heading), sin(mother.heading))
		target = Vector2(mother.at.x, mother.at.z) - ahead * mother.long * .55 + ahead.orthogonal() * 3.4
		leash = 2.5
	var away := target - flat
	var pull: float = clampf((away.length() - leash) / maxf(leash * .5, 4.), 0., 1.)
	# Whales read best side-on, so they mostly travel along the horizon, not towards us.
	if not w.has("lead"):
		want = lerp_angle(want, 0. if cos(w.heading) >= 0. else PI, .5 * (1. - pull))
	if pull > 0.:
		want = lerp_angle(want, away.angle(), pull)
	# Nothing swims or flies through the dock. The nearer it gets, the harder it turns away.
	var fence: float = -40. if flyer else -28.
	var shy: float = clampf((flat.y - fence) / 7., 0., 1.) * float(absf(flat.x) < 50.)
	if shy > 0.:
		want = lerp_angle(want, -PI * .5, shy)
	# And nothing swims through the lighthouse rock or the pier of the big wheel.
	for mark in [Vector3(LAMP.x, LAMP.z, 14.), Vector3(carnival.WHEEL_AT.x, carnival.WHEEL_AT.z, 19.)]:
		var rock := flat - Vector2(mark.x, mark.y)
		var reef: float = clampf((mark.z + long * .5 - rock.length()) / 8., 0., 1.)
		if reef > 0.:
			want = lerp_angle(want, rock.angle(), reef)
			shy = maxf(shy, reef)
	var agile: float = (.3 + .75 * limber) * (1. + 1.2 * shy)
	w.turn = lerpf(w.turn, clampf(angle_difference(w.heading, want), -1., 1.) * agile, 1. - exp(-dt * (1.1 + 2. * shy)))
	w.heading += w.turn * dt
	var top: float = SEA_LEVEL
	var nose_want := 0.
	var pace_want: float = w.cruise
	var quick := 1.
	var effort := 1.
	var bank: float = -w.turn * (1.5 if flyer else .5)
	var thrown := false
	match str(w.state):
		"travel":
			# Just under the surface, between breaths.
			nose_want = nose_for(w, top - long * .18, .4, .15)
			w.clock -= dt
			if w.thrill and flat.y < -25.:
				w.thrill = false
				w.leap = true
				w.state = "sound"
			elif w.clock <= 0.:
				w.state = "breathe"
				w.blown = false
				w.clock = 7.
		"breathe":
			# The back rolls up through the surface, it blows, and it rides there a moment.
			nose_want = nose_for(w, top - long * .04, .42, .1)
			pace_want = w.cruise * .8
			if not w.blown and w.at.y > top - long * .075:
				w.blown = true
				spout(w)
				w.clock = randf_range(1.5, 2.8)
			w.clock -= dt
			if w.clock <= 0.:
				w.breaths -= 1
				if w.breaths > 0:
					w.state = "travel"
					w.clock = randf_range(2.5, 5.)
				else:
					# After its last breath it goes straight down from the surface.
					w.leap = randf() < .3 and flat.y < -25.
					w.state = "sound"
		"sound":
			# The deep dive: it tips over slowly, and the flukes lift clear of the water as it goes.
			nose_want = -1.
			pace_want = w.cruise * (.6 if w.at.y > top - long * .3 else 1.)
			quick = 1.25
			if w.at.y < top - long * .75:
				w.state = "deep"
				w.clock = randf_range(3., 6.) if w.leap else randf_range(5., 11.)
		"deep":
			nose_want = nose_for(w, top - long * .85, .5)
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "rise" if w.leap else "travel"
				w.breaths = randi_range(2, 4)
				w.clock = 0.
				w.wet = true
				# How fast it has to be going to throw this much of itself out of the water.
				w["burst"] = sqrt(2. * LEAP_GRAVITY * long * randf_range(.3, .46)) / sin(1.)
		"rise":
			# A breach starts deep: it turns its nose up and drives for the surface.
			nose_want = 1.
			pace_want = w.burst
			quick = 1.9
			effort = 2.
			if w.at.y > top - long * .04:
				w.state = "air"
				w.leap = false
				w.wet = false
				w.spin = randf_range(.5, 1.5) * (1. if randf() < .5 else -1.) * limber
				splash(w, .7)
		"air":
			# Nothing to push against. It falls as it was thrown, turning onto its side.
			thrown = true
			effort = .25
			w.roll += w.spin * dt
			bank = w.roll
			if w.vel.y < 0. and w.at.y < top - long * .03:
				w.wet = true
				w.pace = maxf(Vector2(w.vel.x, w.vel.z).length(), w.cruise * .5)
				splash(w, 1.)
				w.state = "recover"
				w.clock = 2.6
		"recover":
			# The water takes the fall out of it and it rights itself.
			nose_want = nose_for(w, top - long * .22, .45)
			pace_want = w.cruise * .6
			effort = .6
			bank = 0.
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "travel"
				w.clock = randf_range(1.5, 3.)
		"glide":
			# A sky whale swims the air the same way, in long slow rises and falls.
			nose_want = nose_for(w, w.sky + 2.2 * sin(t * .23) + .9 * sin(t * .53), .42)
			pace_want = w.cruise * (1. - .12 * sin(t * .23))
			effort = .7
			w.clock -= dt
			if (w.clock <= 0. or w.thrill) and flat.y < -44.:
				w.thrill = false
				w.state = "stoop"
		"stoop":
			# Now and then one puts its nose down and dives into the sea.
			nose_want = -.85
			pace_want = w.cruise * 1.5
			quick = 1.6
			effort = .5
			if not w.wet and w.at.y < top:
				w.wet = true
				splash(w, 1.1)
			if w.at.y < top - long * .55:
				w.state = "under"
				w.clock = randf_range(2., 4.)
		"under":
			nose_want = nose_for(w, top - long * .7, .5)
			pace_want = w.cruise * 1.2
			effort = 1.4
			w.clock -= dt
			if w.clock <= 0.:
				w.state = "soar"
		"soar":
			# And comes back out on its own strength, shedding water as it climbs.
			nose_want = .9
			pace_want = w.cruise * 1.7
			quick = 1.6
			effort = 1.9
			if w.wet and w.at.y > top:
				w.wet = false
				splash(w, .8)
			if w.at.y > w.sky * .7:
				w.state = "glide"
				w.clock = randf_range(26., 55.)
	var before: float = w.pitch
	if thrown:
		w.vel.y -= LEAP_GRAVITY * dt
		w.vel.x *= 1. - .1 * dt
		w.vel.z *= 1. - .1 * dt
		# Its nose comes over as it falls, but slower than the fall itself: it lands on its side.
		var fall: float = atan2(w.vel.y, maxf(Vector2(w.vel.x, w.vel.z).length(), .5))
		w.pitch = move_toward(w.pitch, lerpf(w.pitch, fall, .75), dt * 1.1 * (.6 + limber))
	else:
		var rate: float = (.45 + 1.1 * limber) * quick
		w.pitch += clampf((nose_want - w.pitch) * 2.6, -rate, rate) * dt
		w.pace = lerpf(w.pace, pace_want, 1. - exp(-dt * 1.1 * quick))
		var nose_now := Vector3(cos(w.heading) * cos(w.pitch), sin(w.pitch), sin(w.heading) * cos(w.pitch))
		w.vel = w.vel.lerp(nose_now * w.pace, 1. - exp(-dt * (3. if str(w.state) == "recover" else 6.)))
	w.tilt = lerpf(w.tilt, (w.pitch - before) / dt, 1. - exp(-dt * 6.))
	w.at += w.vel * dt
	if absf(w.at.x) < 46.:
		w.at.z = minf(w.at.z, -19.)
	for mark in [Vector3(LAMP.x, LAMP.z, 7.5), Vector3(carnival.WHEEL_AT.x, carnival.WHEEL_AT.z, 15.)]:
		var off_rock := Vector2(w.at.x - mark.x, w.at.z - mark.y)
		if off_rock.length() < mark.z:
			off_rock = off_rock.normalized() * mark.z
			w.at.x = mark.x + off_rock.x
			w.at.z = mark.y + off_rock.y
	w.roll = lerp_angle(w.roll, bank, 1. - exp(-dt * (2.2 if not thrown else 30.)))
	# Faster swimming is a faster stroke. In the air the tail hardly moves.
	w.stroke = lerpf(w.stroke, effort, 1. - exp(-dt * 3.))
	w.beat += dt * (1.5 + w.pace * .5) * (10. / (6. + long)) * (.75 if flyer else 1.)
	var nose := Vector3(cos(w.heading) * cos(w.pitch), sin(w.pitch), sin(w.heading) * cos(w.pitch))
	var x := -nose
	var z := x.cross(Vector3.UP).normalized()
	var body: MeshInstance3D = w.body
	body.transform = Transform3D((Basis(x, z.cross(x).normalized(), z) * Basis(Vector3.RIGHT, w.roll)).scaled(Vector3.ONE * long), w.at)
	var look: ShaderMaterial = w.look
	var speed: float = maxf(w.pace, 1.5)
	look.set_shader_parameter("seconds", seconds)
	look.set_shader_parameter("beat", w.beat)
	look.set_shader_parameter("stroke", w.stroke)
	look.set_shader_parameter("bend", clampf(-w.turn / speed * long * .55, -.5, .5))
	look.set_shader_parameter("arch", clampf(w.tilt / speed * long * .4, -.3, .3))
	look.set_shader_parameter("glow", 1.7 * smoothstep(.62, 1., dusk) + 1.2 * (1. - lights))


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


## Copy a simple shape into the spectator mesh. `kind` picks its paint, `gate` says which
## spectators have it, and `joint` (1 an arm, 2 the head) with `pivot` says what moves it.
func add_part(
	st: SurfaceTool, shape: PrimitiveMesh, where: Transform3D, kind: float, gate: float, joint := 0., pivot := Vector3.ZERO
) -> void:
	var arrays := shape.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var turn := where.basis.inverse().transposed()
	for i in order:
		st.set_normal((turn * normals[i]).normalized())
		st.set_uv(uvs[i])
		st.set_uv2(Vector2(kind, gate))
		st.set_custom(0, Color(joint, pivot.x, pivot.y, pivot.z))
		st.add_vertex(where * points[i])


func round_part(top: float, bottom: float, height: float, sides := 12) -> CylinderMesh:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return shape


func ball_part(radius: float, sides := 12) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.
	shape.radial_segments = sides
	shape.rings = maxi(sides / 2, 4)
	return shape


func limb_part(radius: float, length: float) -> CapsuleMesh:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = length
	shape.radial_segments = 7
	shape.rings = 2
	return shape


const BOT := """shader_type spatial;
uniform float seconds = 0.0;
uniform float joy_gold = 0.0;
uniform float joy_blue = 0.0;
uniform float since_gold = 99.0;
uniform float since_blue = 99.0;
uniform float lights = 1.0;
uniform float wave_x = 999.0;
uniform vec3 focus = vec3(0.0, 1.0, 0.0);
uniform vec3 gold : source_color = vec3(1.0, 0.75, 0.34);
uniform vec3 blue : source_color = vec3(0.34, 0.85, 0.93);
varying float kind;
varying float crew;
varying float cheer;
varying float gloom;
varying float id;
varying float bot;
varying vec3 paint;
varying vec3 face;
float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}
// A value that wanders without ever repeating, between -0.5 and 0.5.
float drift(float t, float seed) {
	float i = floor(t), f = fract(t);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i + seed * 57.0), hash(i + 1.0 + seed * 57.0), f) - 0.5;
}
vec3 yaw(vec3 p, float a) {
	return vec3(p.x * cos(a) + p.z * sin(a), p.y, p.z * cos(a) - p.x * sin(a));
}
void vertex() {
	kind = UV2.x;
	id = INSTANCE_CUSTOM.x * 61.0 + 1.0;
	crew = INSTANCE_CUSTOM.y;
	float spirit = INSTANCE_CUSTOM.z;
	bot = INSTANCE_CUSTOM.w;
	paint = COLOR.rgb;
	face = vec3(VERTEX.x, VERTEX.y - 0.86, VERTEX.z) / 0.125;
	// Which hat, what is in the hand and whether there is a scarf differ from one to the next.
	float gate = UV2.y;
	float hat = hash(id * 7.31);
	float prop = hash(id * 3.17);
	float lefty = step(0.5, hash(id * 6.3));
	float show = 1.0;
	if (gate < 1.5) show = 1.0 - bot;
	else if (gate < 2.5) show = bot;
	else if (gate < 3.5) show = (1.0 - bot) * step(hat, 0.3);
	else if (gate < 4.5) show = (1.0 - bot) * step(0.3, hat) * step(hat, 0.45);
	else if (gate < 5.5) show = (1.0 - bot) * step(0.45, hat) * step(hat, 0.68);
	else if (gate < 6.5) show = (1.0 - bot) * step(prop, 0.3) * (1.0 - lefty);
	else if (gate < 7.5) show = (1.0 - bot) * step(0.3, prop) * step(prop, 0.45) * (1.0 - lefty);
	else if (gate < 8.5) show = (1.0 - bot) * step(hash(id * 11.3), 0.5);
	else if (gate < 9.5) show = bot * step(prop, 0.55) * (1.0 - lefty);
	else if (gate < 10.5) show = bot * step(hat, 0.5);
	else if (gate < 11.5) show = bot * step(0.5, hat);
	else if (gate < 12.5) show = (1.0 - bot) * step(prop, 0.3) * lefty;
	else if (gate < 13.5) show = (1.0 - bot) * step(0.3, prop) * step(prop, 0.45) * lefty;
	else show = bot * step(prop, 0.55) * lefty;
	float holds = mix(step(prop, 0.45), step(prop, 0.55), bot);
	// A goal reaches each of them a little late, and some keep it up longer than others.
	float mine = mix(joy_gold, joy_blue, crew);
	float theirs = mix(joy_blue, joy_gold, crew);
	float late = 0.03 + 0.6 * hash(id * 3.1);
	cheer = smoothstep(late, late + 0.3, mix(since_gold, since_blue, crew)) * smoothstep(0.0, 0.15 + 0.55 * (1.0 - spirit), mine);
	gloom = smoothstep(late, late + 0.5, mix(since_blue, since_gold, crew)) * smoothstep(0.0, 0.5, theirs);
	gloom *= (1.0 - cheer) * (0.35 + 0.65 * hash(id * 5.3));
	// Between goals each one is doing its own thing: a word to a neighbour, a look at the sky,
	// a wave to someone, a little dance. What and when is different for every one of them.
	float span = 3.0 + 5.0 * hash(id * 1.9);
	float clock = seconds / span + hash(id * 2.7) * 9.0;
	float pick = hash(floor(clock) * 1.713 + id);
	float part = fract(clock);
	float act = smoothstep(0.0, 0.15, part) * (1.0 - smoothstep(0.6, 0.9, part));
	float chat = step(pick, 0.22) * act;
	float skyward = step(0.22, pick) * step(pick, 0.31) * act;
	float hello = step(0.74, pick) * step(pick, 0.86) * act * (0.3 + 0.7 * spirit);
	float jig = step(0.86, pick) * act * spirit;
	vec3 here = MODEL_MATRIX[3].xyz;
	float ola = 1.0 - smoothstep(0.0, 2.6, abs(here.x - wave_x));
	ola *= ola;
	// They follow the star with their heads, and a little with their bodies.
	vec3 to = (focus - here) * mat3(MODEL_MATRIX);
	float watch = clamp(atan(to.x, to.z), -1.0, 1.0);
	float aside = hash(id * 8.3) > 0.5 ? 0.8 : -0.8;
	float body_turn = watch * 0.4 * (1.0 - chat) + chat * aside + 0.25 * drift(seconds * 0.3, id);
	float head_turn = watch * 0.5 * (1.0 - chat - skyward) + chat * aside * 0.5 + 0.5 * drift(seconds * 0.45, id * 1.7);
	float rate = 5.5 + 4.0 * hash(id * 9.1);
	float hop_t = seconds * rate + id * 40.0;
	float bounce = abs(sin(hop_t));
	float jumper = step(0.3, hash(id * 2.3));
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float joint = CUSTOM0.x;
	vec3 pivot = CUSTOM0.yzw;
	if (joint > 0.5 && joint < 1.5) {
		// An arm swings out and up about its shoulder.
		float right = step(0.0, pivot.x);
		// The hand they favour. Some hold what they carry up high, others let it hang.
		float handed = mix(right, 1.0 - right, lefty);
		float carry = mix(0.5, 2.35, step(0.42, hash(id * 5.9))) + 0.5 * hash(id * 4.1) + 0.3 * drift(seconds * 0.6, id * 1.3);
		float raise = 0.16 + 0.14 * drift(seconds * 0.4, id + right * 3.0);
		raise = mix(raise, carry, holds * handed);
		raise = mix(raise, 2.65 + 0.35 * sin(seconds * 9.0 + id * 50.0), hello * mix(handed, 1.0 - handed, holds));
		raise = mix(raise, 2.9, ola);
		float thrilled = jumper > 0.5 ? 2.55 + 0.3 * sin(hop_t * 2.0 + right * 1.7) : 1.5 + 1.3 * abs(sin(hop_t + right * 1.57));
		raise = mix(raise, thrilled, cheer);
		raise = mix(raise, 0.06 + 0.5 * holds * handed, gloom);
		float a = raise * (right * 2.0 - 1.0);
		vec3 r = v - pivot;
		v = pivot + vec3(r.x * cos(a) - r.y * sin(a), r.x * sin(a) + r.y * cos(a), r.z);
		n = vec3(n.x * cos(a) - n.y * sin(a), n.x * sin(a) + n.y * cos(a), n.z);
	} else if (joint > 1.5) {
		// The head tips and turns on the neck.
		float tip = skyward * 0.5 - gloom * 0.45 + 0.1 * drift(seconds * 0.5, id * 2.1) + cheer * 0.15;
		vec3 r = v - pivot;
		r = yaw(vec3(r.x, r.y * cos(tip) + r.z * sin(tip), r.z * cos(tip) - r.y * sin(tip)), head_turn);
		n = yaw(vec3(n.x, n.y * cos(tip) + n.z * sin(tip), n.z * cos(tip) - n.y * sin(tip)), head_turn);
		v = pivot + r;
	}
	// A jump squashes on landing. The bots, being springs, squash more.
	float land = 1.0 - smoothstep(0.0, 0.35, bounce);
	float squash = cheer * jumper * land * mix(0.08, 0.22, bot);
	v.y *= (1.0 - squash) * (1.0 - 0.07 * gloom);
	v.xz *= 1.0 + squash * 0.5;
	v = yaw(v, body_turn);
	n = yaw(n, body_turn);
	// Weight shifts from foot to foot.
	v.x += (0.1 * drift(seconds * 0.45, id * 3.3) + jig * 0.16 * sin(seconds * 6.5 + id)) * v.y;
	float lean = gloom * 0.3 - cheer * 0.05;
	v.yz = vec2(v.y * cos(lean) - v.z * sin(lean), v.y * sin(lean) + v.z * cos(lean));
	v.y += cheer * jumper * (0.1 + 0.42 * spirit) * bounce + jig * 0.09 * abs(sin(seconds * 6.5 + id)) + ola * 0.16;
	v.y += bot * (0.05 + 0.035 * sin(seconds * (1.5 + hash(id * 12.0)) + id * 7.0));
	VERTEX = v * show;
	NORMAL = n;
}
void fragment() {
	vec3 crew_tint = mix(gold, blue, crew);
	vec3 albedo = paint;
	vec3 emit = vec3(0.0);
	float metal = 0.25 * bot;
	float rough = mix(0.8, 0.42, bot);
	if (kind > 0.5 && kind < 1.5) {
		// Skin, anywhere from deep brown to pale, and a face on the front of the head.
		albedo = mix(vec3(0.30, 0.17, 0.11), vec3(0.96, 0.76, 0.62), hash(id * 13.7));
		albedo = mix(albedo, vec3(0.72, 0.5, 0.36), 0.25 * hash(id * 4.9));
		metal = 0.0;
		rough = 0.65;
		vec2 p = face.xy;
		float front = smoothstep(0.3, 0.6, face.z) * step(length(p), 1.2);
		float glad = smoothstep(0.2, 0.6, cheer);
		float glum = smoothstep(0.2, 0.6, gloom);
		float blink = step(0.955, fract(seconds * 0.21 + id * 0.37));
		vec2 e = vec2(abs(p.x) - 0.36, p.y - 0.06);
		float eye = 1.0 - smoothstep(0.09, 0.13, length(e / vec2(1.0, mix(1.3, 0.25, max(blink, glad * 0.7)))));
		vec2 m = vec2(p.x, p.y + 0.42);
		float smile = (1.0 - smoothstep(0.035, 0.075, abs(m.y - (0.9 - 2.2 * glum) * (p.x * p.x - 0.03))));
		smile *= 1.0 - smoothstep(0.2, 0.28, abs(p.x));
		float shout = 1.0 - smoothstep(0.75, 1.0, length(m / vec2(0.24, 0.2)));
		float cheek = 1.0 - smoothstep(0.1, 0.24, length(vec2(abs(p.x) - 0.56, p.y + 0.22)));
		albedo = mix(albedo, vec3(1.0, 0.42, 0.38), 0.3 * cheek * front);
		albedo = mix(albedo, vec3(0.07, 0.04, 0.04), max(eye, mix(smile, shout, glad)) * front);
	} else if (kind > 1.5 && kind < 2.5) {
		// Hair: black, brown, fair, grey, red, and now and then dyed in their crew's colour.
		float h = hash(id * 17.9);
		albedo = vec3(0.07, 0.05, 0.04);
		albedo = mix(albedo, vec3(0.30, 0.17, 0.08), step(0.3, h));
		albedo = mix(albedo, vec3(0.80, 0.60, 0.28), step(0.55, h));
		albedo = mix(albedo, vec3(0.72, 0.72, 0.76), step(0.7, h));
		albedo = mix(albedo, vec3(0.70, 0.24, 0.10), step(0.8, h));
		albedo = mix(albedo, crew_tint, step(0.9, h));
		metal = 0.0;
		rough = 0.6;
	} else if (kind > 2.5 && kind < 3.5) {
		albedo = crew_tint;
		float flick = 0.85 + 0.15 * sin(seconds * 9.0 + id * 31.0);
		emit = crew_tint * (1.3 + 2.6 * cheer) * flick * lights * (1.0 - 0.7 * gloom);
	} else if (kind > 3.5 && kind < 4.5) {
		albedo = mix(vec3(0.04, 0.06, 0.15), vec3(0.09, 0.09, 0.11), hash(id * 6.7));
		metal = 0.0;
		rough = 0.85;
	} else if (kind > 4.5 && kind < 5.5) {
		albedo = crew_tint * 0.9;
		emit = crew_tint * 0.12 * lights;
		metal = 0.0;
		rough = 0.8;
	} else if (kind > 5.5 && kind < 6.5) {
		// A bot's face on a screen: round eyes, happy arcs when cheering, flat lines when glum.
		albedo = vec3(0.02, 0.03, 0.05);
		vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
		p.x *= 1.35;
		float blink = step(0.955, fract(seconds * 0.23 + id * 0.41));
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
	} else if (kind > 6.5 && kind < 7.5) {
		albedo = vec3(0.13, 0.16, 0.20);
		metal = 0.65;
		rough = 0.38;
	} else if (kind > 7.5) {
		// A hat is in the crew's colour or in one that clashes with the coat.
		albedo = mix(crew_tint, paint.gbr, step(0.5, hash(id * 23.1)));
		metal = 0.0;
		rough = 0.85;
	}
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
}
"""


## The stands behind the far rail hold a mixed crowd: harbor folk in coats and hats, and small
## hovering dock-bots. No two are placed, dressed or timed alike. Most of each block follows the
## crew at its end of the court, with a few away fans among them.
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
			# People stand where they like: bunched up here, a gap there, a child tucked in beside.
			var x := x0 + randf_range(.15, .5)
			while x < x1 - .15:
				var small := randf() < .15
				spots.append([Vector3(x, top + .06, z + randf_range(-.2, .2)), block, small])
				x += randf_range(.5, .95) * (.75 if small else 1.) + (.7 if randf() < .1 else 0.)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var still := Basis.IDENTITY
	# Harbor folk: legs, a coat, a round head with hair, two arms.
	var neck := Vector3(0, .74, 0)
	for side in [-1., 1.]:
		add_part(st, round_part(.055, .05, .32, 8), Transform3D(still, Vector3(side * .075, .16, 0)), 4., 1.)
		var shoulder := Vector3(side * .165, .66, 0)
		add_part(st, limb_part(.04, .3), Transform3D(still, Vector3(side * .165, .53, 0)), 0., 1., 1., shoulder)
		add_part(st, ball_part(.043, 8), Transform3D(still, Vector3(side * .165, .36, 0)), 1., 1., 1., shoulder)
	add_part(st, round_part(.125, .185, .4), Transform3D(still, Vector3(0, .5, 0)), 0., 1.)
	add_part(st, ball_part(.126), Transform3D(still.scaled(Vector3(1, .5, 1)), Vector3(0, .7, 0)), 0., 1.)
	add_part(st, ball_part(.125, 14), Transform3D(still, Vector3(0, .86, 0)), 1., 1., 2., neck)
	add_part(st, ball_part(.131), Transform3D(still, Vector3(0, .89, -.03)), 2., 1., 2., neck)
	# One of: a bobble hat, a brimmed hat, a bun, or nothing.
	add_part(st, ball_part(.138), Transform3D(still.scaled(Vector3(1, .82, 1)), Vector3(0, .915, -.012)), 8., 3., 2., neck)
	add_part(st, ball_part(.042, 8), Transform3D(still, Vector3(0, 1.045, -.012)), 8., 3., 2., neck)
	add_part(st, round_part(.095, .125, .1), Transform3D(still, Vector3(0, .995, -.01)), 8., 4., 2., neck)
	add_part(st, round_part(.2, .2, .016), Transform3D(still, Vector3(0, .945, -.01)), 8., 4., 2., neck)
	add_part(st, ball_part(.06, 8), Transform3D(still, Vector3(0, 1., -.075)), 2., 5., 2., neck)
	# In one hand or the other: a light stick, a pennant, or nothing.
	var pennant := BoxMesh.new()
	pennant.size = Vector3(.22, .14, .01)
	for hand in [[1., 6., 7.], [-1., 12., 13.]]:
		var holding := Vector3(hand[0] * .165, .66, 0)
		add_part(st, limb_part(.028, .42), Transform3D(still, Vector3(hand[0] * .165, .16, 0)), 3., hand[1], 1., holding)
		add_part(st, round_part(.012, .012, .5, 5), Transform3D(still, Vector3(hand[0] * .165, .12, 0)), 7., hand[2], 1., holding)
		add_part(st, pennant, Transform3D(still, Vector3(hand[0] * .28, -.05, 0)), 5., hand[2], 1., holding)
	# A scarf in the crew's colour.
	add_part(st, round_part(.118, .132, .07), Transform3D(still, Vector3(0, .73, 0)), 5., 8.)
	var tail := BoxMesh.new()
	tail.size = Vector3(.06, .17, .025)
	add_part(st, tail, Transform3D(still, Vector3(.06, .63, .135)), 5., 8.)
	# Dock-bots: a tub that hovers on a jet, two arms, and a box or a dome for a head.
	var collar := Vector3(0, .72, 0)
	add_part(st, round_part(.2, .245, .46), Transform3D(still, Vector3(0, .43, 0)), 0., 2.)
	add_part(st, round_part(.19, .1, .13), Transform3D(still, Vector3(0, .135, 0)), 7., 2.)
	add_part(st, round_part(.09, .05, .05, 10), Transform3D(still, Vector3(0, .045, 0)), 3., 2.)
	for side in [-1., 1.]:
		add_part(st, limb_part(.04, .3), Transform3D(still, Vector3(side * .275, .47, 0)), 7., 2., 1., Vector3(side * .275, .6, 0))
	add_part(st, limb_part(.032, .46), Transform3D(still, Vector3(.275, .13, 0)), 3., 9., 1., Vector3(.275, .6, 0))
	add_part(st, limb_part(.032, .46), Transform3D(still, Vector3(-.275, .13, 0)), 3., 14., 1., Vector3(-.275, .6, 0))
	var box_head := BoxMesh.new()
	box_head.size = Vector3(.36, .27, .29)
	add_part(st, box_head, Transform3D(still, Vector3(0, .86, 0)), 0., 10., 2., collar)
	var screen := QuadMesh.new()
	screen.size = Vector2(.3, .21)
	add_part(st, screen, Transform3D(still, Vector3(0, .86, .147)), 6., 10., 2., collar)
	add_part(st, round_part(.012, .012, .15, 5), Transform3D(still, Vector3(.08, 1.07, 0)), 7., 10., 2., collar)
	add_part(st, ball_part(.04, 8), Transform3D(still, Vector3(.08, 1.17, 0)), 3., 10., 2., collar)
	add_part(st, ball_part(.2), Transform3D(still.scaled(Vector3(1, .86, 1)), Vector3(0, .85, 0)), 0., 11., 2., collar)
	var visor := QuadMesh.new()
	visor.size = Vector2(.27, .17)
	add_part(st, visor, Transform3D(still, Vector3(0, .855, .198)), 6., 11., 2., collar)
	for side in [-1., 1.]:
		add_part(st, round_part(.05, .05, .04, 8), Transform3D(Basis(Vector3.FORWARD, PI * .5), Vector3(side * .2, .85, 0)), 7., 11., 2., collar)
	add_part(st, ball_part(.035, 8), Transform3D(still, Vector3(0, 1.045, 0)), 3., 11., 2., collar)
	bot_look.shader = Shader.new()
	bot_look.shader.code = BOT
	bot_look.set_shader_parameter("gold", CREW[0])
	bot_look.set_shader_parameter("blue", CREW[1])
	bots.transform_format = MultiMesh.TRANSFORM_3D
	bots.use_colors = true
	bots.use_custom_data = true
	bots.mesh = st.commit()
	bots.instance_count = spots.size()
	var coats := [
		Color("#e9b23c"), Color("#2f8f8a"), Color("#e2674a"), Color("#2c4a7c"), Color("#efe6d2"), Color("#7b4b8f"),
		Color("#6f8f3a"), Color("#5fb4e6"), Color("#c93a3a"), Color("#f08fb0"), Color("#3c3f52"), Color("#f2843a")
	]
	var tubs := [
		Color("#ff5d8f"), Color("#ffb000"), Color("#18d4c9"), Color("#8a6bff"),
		Color("#9bea3a"), Color("#ff7a2f"), Color("#3fa9ff"), Color("#f4f0e6")
	]
	for n in spots.size():
		var machine := randf() < .34
		var small: bool = spots[n][2] and not machine
		var size := randf_range(.64, .78) if small else (randf_range(.86, 1.14) if machine else randf_range(.98, 1.24))
		var wide := randf_range(.9, 1.14)
		var turn := randf_range(-.4, .4)
		bots.set_instance_transform(
			n, Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(size * wide, size * randf_range(.9, 1.12), size * wide)), spots[n][0])
		)
		var paint: Color = tubs[randi() % tubs.size()] if machine else coats[randi() % coats.size()]
		paint.h = fposmod(paint.h + randf_range(-.025, .025), 1.)
		paint.v = clampf(paint.v * randf_range(.85, 1.08), 0., 1.)
		bots.set_instance_color(n, paint)
		# Most of a block follows the crew at its end. A few away fans stand among them.
		var fan: int = spots[n][1] if randf() < .84 else 1 - spots[n][1]
		bots.set_instance_custom_data(n, Color(randf(), float(fan), pow(randf(), .7), 1. if machine else 0.))
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
	cheered[team] = 0.
	carnival.cheer(CREW[team])
	sparks[team].restart()
	sparks[team].emitting = true
	var show := create_tween()
	for n in 3:
		show.tween_callback(firework.bind(CREW[team]))
		show.tween_interval(.28)
	var keen := 0
	for w in pod:
		if keen < 2 and str(w.state) in ["travel", "glide"]:
			w.thrill = true
			keen += 1


## The final whistle: the lighthouse and the sky take the winner's colour. -1 is a shared light.
func finale(team: int) -> void:
	winner = team
	finale_clock = 5.
	if team >= 0:
		joy[team] = 1.
		cheered[team] = 0.
		pulse = 1.
		pulse_tint = CREW[team]


func restart() -> void:
	winner = -1
	finale_clock = 0.
	joy = [0., 0.]
	cheered = [99., 99.]
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
	carnival.animate(step, dusk, lights)
	# The crowd moves in its shader. It only needs to know the time and who is happy.
	for side in 2:
		joy[side] = move_toward(joy[side], 1. if winner == side else 0., dt / 3.4)
		cheered[side] += dt
	# Now and then a wave runs the length of the stands.
	ola_clock -= step
	if ola_clock <= 0.:
		ola_clock = randf_range(26., 50.)
		ola_way = 1. if randf() < .5 else -1.
		ola_at = -ola_way * (Game.RING + 4.)
	ola_at += ola_way * 6.5 * step
	bot_look.set_shader_parameter("seconds", seconds)
	bot_look.set_shader_parameter("joy_gold", joy[0])
	bot_look.set_shader_parameter("joy_blue", joy[1])
	bot_look.set_shader_parameter("since_gold", cheered[0])
	bot_look.set_shader_parameter("since_blue", cheered[1])
	bot_look.set_shader_parameter("wave_x", ola_at)
	bot_look.set_shader_parameter("focus", focus)
	bot_look.set_shader_parameter("lights", lights)
	# Fireworks keep going for a few seconds after the final whistle.
	if finale_clock > 0.:
		var before := finale_clock
		finale_clock -= dt
		if int(before / .45) != int(finale_clock / .45):
			firework(CREW[winner] if winner >= 0 else CREW[randi() % 2])
