extends Node3D
const Game = preload("res://game/star_match.gd")
const Room = preload("res://game/room_art.gd")
const Performer = preload("res://game/crew_visual.gd")
const Front = preload("res://game/star_ui.gd")
const Coach = preload("res://game/gemini_coach.gd")
var coach: Coach
var radio_host = preload("res://game/radio_host.gd").new()
const Recorder = preload("res://game/flight_recorder.gd")
const Easy = preload("res://game/easy_controls.gd")
## The two buttons each seat needs, as they are written on screen.
const GO_KEY = ["SPACE", "ENTER"]
const SHARE_KEY = ["F", "/"]
const AMBER := Color("#ffce76")
const BLUE := Color("#78e2ed")
const LINEUP = [
	Vector2(-3.4, .08),
	Vector2(3.3, .16),
	Vector2(-1.70, .30),
	Vector2(.04, -.2),
	Vector2(1.61, .20)
]
const CAST = [
	[
		"NELL   /   FERRY RACER",
		"I used to race the last ferry home. Give me one open lane.",
		"FERRY RUN   ·   The longest dash on the dock, and the only one nobody can steal through."
	],
	[
		"RAFI   /   RINGWRIGHT'S SON",
		"Dad wired that gold ring. Tonight, you and me light it for him.",
		"LONG SHOT   ·   Scores from a step farther out than anyone else."
	],
	[
		"PIP   /   BALL THIEF",
		"See these little hands? Best pickpocket on Saturn. Check your pockets.",
		"GETAWAY   ·   Steals from farther away, then bolts with a burst of speed. Plays for the next shot."
	],
	[
		"MORROW   /   KEEPER",
		"Thirty winters guarding this dock. I remember every runner who got past me.",
		"ANCHOR   ·   Carry the star near him and you slow right down. Plays for a goal made off a pass."
	],
	[
		"ZIP   /   COURIER",
		"I delivered your jersey this morning. Want to see how fast?",
		"EXPRESS   ·   Fastest on the dock, and his passes fly a third faster. Plays for passes."
	]
]
## Morrow tells the story before the five are introduced.
const TALE = [
	[
		"LAMPLIGHT HARBOR   /   SATURN",
		"When the sun drops behind Saturn, the whales follow one light home."
	],
	[
		"THE GAME",
		"We play for who lights it. Tonight is the last night anyone lights it by hand."
	],
	[
		"THE MACHINES",
		"They have promised us machines a turn for thirty winters. Tonight, we are counting."
	]
]
## How a robot's own call reads in the radio log.
const CALLS = {
	"draft/nell": "I sign with Nell.",
	"draft/rafi": "I sign with Rafi.",
	"broken/stay": "I let it go.",
	"broken/strike": "I stop work.",
	"broken/leave": "I leave.",
	"offer/switch": "I switch.",
	"offer/refuse": "I stay put.",
	"renewal/sign": "I sign again.",
	"renewal/refuse": "Not yet.",
	"vote/walk": "I vote to walk out.",
	"vote/stay": "I vote to stay."
}
const ROBOT_CUES = [
	"terms", "paid", "broken", "walk", "strike", "restless", "no", "sign", "call", "aye", "nay",
	"union"
]
const EFFECTS = [
	"dash", "catch", "throw", "steal", "goal_big", "deal", "paid", "broken", "strike", "radio",
	"vote", "powerdown", "whistle", "tick", "ui_move", "ui_pick", "ui_back", "page", "whoosh",
	"title_hit", "lamp", "count", "count_go", "crowd_cheer", "splash", "firework", "fanfare"
]
## How loud each sound sits against the others, in decibels.
const MIX = {
	"ui_move": -8., "ui_pick": -3., "ui_back": -4., "page": -5., "whoosh": -6., "lamp": -9.,
	"title_hit": -1., "count": -4., "count_go": -2., "crowd_cheer": -2., "splash": -2.,
	"firework": -3., "fanfare": -1.
}
var tale := -1
var anchor_ring: Node3D
var voice_queue: Array[String] = []
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_turn := 0
var sfx_frame: Dictionary = {}
var room := Room.new()
var front := Front.new()
var dock_lights = preload("res://game/court_lights.gd").new()
## The living harbor beyond the rail: sky, sea, whales, lighthouse, lanterns and the crowd.
var harbor = preload("res://game/harbor_world.gd").new()
## Comic-book pages, sound words and speech balloons.
var comics = preload("res://game/comics.gd").new()
## The animated title, how to play, and the choice of game.
var screens = preload("res://game/start_screens.gd").new()
## Waves on the hulls, under everything.
var ambience := AudioStreamPlayer.new()
## Each character's colour on their comic page, and how high their face is.
const PAGE_TINT = [Color("#5fe6c4"), Color("#e08fd8"), Color("#ff9450"), Color("#f0c869"), Color("#bfeaf5")]
const FACE = [1.56, 1.62, .78, 1.52, 1.36]
var camera := Camera3D.new()
var sim = Game.new()
var cast: Array = []
var badges: Array = []
var hoops: Array = []
var star := Node3D.new()
var shade_disc: MeshInstance3D
var beacon: Node3D
var beacon_start_tick := 0
var beacon_end_tick := 0
var music := AudioStreamPlayer.new()
var voice := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var clips: Dictionary = {}
var phase := "title"
var clock := 0.
var chapter := -1
var chapter_time := 0.
var duration := 2.9
var crews := false
var free := false
var deal_tags: Array = []
var star_lamp := OmniLight3D.new()
var dusk := 0.
var capture_mode := "rivals"
## Free Agents robots weigh their own past outcomes. This flag puts them back on the written rules.
var written_rules := false
var anchor_paint: StandardMaterial3D
var anchor_note := Label3D.new()
var ring_glow: Array = []
var court_glow := ShaderMaterial.new()
var sky_step := -1.
var floods: Array = []
var drones: Array = []
var flood_glass: StandardMaterial3D
## Five trails of sparks for dashes, and a sixth that follows the star.
var wakes: Array = []
## Where each pilot is steering, so a pass can follow it.
var steer := [Vector2.ZERO, Vector2.ZERO]
var last_lesson := [-1, -1, -1, -1, -1]
var last_count := -1
var pilot_for_seat: Array[int] = [0, 1]
var positions: Array = Game.START.duplicate()
var scoring_team := -1
var goal_pose: Array = []
var goal_spot := Vector3.ZERO
var old_ball := Vector3.ZERO
var stride := [0., 0., 0., 0., 0.]
var aim_dots: Array = []
var message := ""
var message_until := 0
var box_score := {}
var touch_pose_until := [0, 0, 0, 0, 0]
var trail_meshes: Array[MeshInstance3D] = []
var trail_points: Array[Vector3] = []
var camera_focus := Vector2.ZERO
var camera_distance := 17.2
var whistle_age := 0.
var gather_tick := -20
var gather_offset := Vector3.ZERO
const WALK_ON_SECONDS := 3.2
var last_voice := -150
var last_ledger := [-1, -1, -99, -99, -99]
var command_edges := [{}, {}]
var pad_edges := [{}, {}]
## The pause screen switches sound effects (with voices and the sea) and the music on and off
## separately. The choice is kept for the next launch.
var sound_on := true
var music_on := true
const AUDIO_SETTINGS := "user://audio.cfg"
var random := RandomNumberGenerator.new()
var recorder = Recorder.new()
var training: Dictionary = {}
var social_memory: Dictionary = {}
## Coach Bruin's notes, written by `python3 telemetry/cloud.py coach` into user://bruin-coach.json.
var bruin_notes: Array = []
## The match drawn as one comic panel by telemetry/panels.py (Runware), shown on the final screen
## once the picture arrives. The game never calls Runware itself; it only looks for the file.
var match_run := ""
var panel_box: PanelContainer
var panel_image: TextureRect
var panel_caption: Label
var panel_age := 0.
const SAVE_PATH := "user://last-light-policy.json"
var capture_path := ""
var frame_samples: Array[float] = []
var slow_frames: Array = []
var wall_frame := 0
var capture_step := 0
var capture_timer := 0.
var captured_once := false
var forced_seed := -1
## Launch with `-- --full-strength` to stop the robots easing off while they lead.
var full_strength := false
var capture_session := false
var benchmark_only := false
var test_session := false


func _ready() -> void:
	get_window().title = "Last Light"
	random.randomize()
	for arg in OS.get_cmdline_user_args():
		if arg == "--court-playtest":
			test_session = true
		if arg.begins_with("--seed="):
			forced_seed = int(arg.trim_prefix("--seed="))
		if arg == "--full-strength":
			full_strength = true
		if arg.begins_with("--mode="):
			capture_mode = arg.trim_prefix("--mode=")
		if arg == "--written-rules":
			written_rules = true
		if arg.begins_with("--court-benchmark="):
			benchmark_only = true
			arg = "--court-capture=" + arg.trim_prefix("--court-benchmark=")
		if arg.begins_with("--court-capture="):
			capture_path = arg.trim_prefix("--court-capture=")
			DirAccess.make_dir_recursive_absolute(capture_path)
			capture_session = true
	add_child(room)
	room.build(true)
	# The dock is stretched to hold the court, so it grows with the court.
	room.scale = Vector3(1.67 * Game.RING / Game.OLD_RING, 1., 1.84 * Game.BOUNDS.y / Game.OLD_BOUNDS.y)
	# The painted view keeps its shape and framing: it grows evenly with the dock.
	room.window.transform = (
		Transform3D(Basis.from_scale(Vector3(1., Game.BOUNDS.y / Game.OLD_BOUNDS.y, 1.)), Vector3.ZERO)
		* room.window.transform
	)
	# The old painted wall gives way to a harbor that moves.
	room.window.hide()
	add_child(harbor)
	harbor.build(room)
	harbor.warm()
	court()
	add_child(camera)
	camera.current = true
	for i in 5:
		var doll := Performer.new()
		add_child(doll)
		doll.setup(i, false)
		cast.append(doll)
		var gold = room.metal("jersey gold", "#ffbd5d", .45, .25, 1.0)
		var blue = room.metal("jersey blue", "#5bdbe8", .45, .25, 1.0)
		var badge = room.torus(self, Vector3.ZERO, .277, .305, gold if i < 2 else blue)
		badges.append([badge, gold, blue])
		# What this robot is owed, or what it is doing about not getting it.
		var note := Label3D.new()
		note.font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
		note.font_size = 30
		note.pixel_size = .0056
		note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		note.outline_size = 8
		note.no_depth_test = true
		note.layers = 2
		doll.tag.layers = 2
		note.hide()
		doll.add_child(note)
		deal_tags.append(note)
	add_child(music)
	add_child(voice)
	add_child(effects)
	effects.max_polyphony = 4
	for n in 6:
		var layer := AudioStreamPlayer.new()
		layer.volume_db = -7.
		add_child(layer)
		sfx_pool.append(layer)
	var extra: Array[String] = ["nell_truce", "rafi_truce", "morrow_tale1", "morrow_tale2", "morrow_tale3"]
	for robot in ["pip", "morrow", "zip"]:
		for cue in ROBOT_CUES:
			extra.append(robot + "_" + cue)
	for key in extra + EFFECTS:
		var path: String = "res://assets/last_light/" + key + ".wav"
		if ResourceLoader.exists(path):
			clips[key] = load(path)
	for key in [
		"nell_intro",
		"rafi_intro",
		"pip_intro",
		"morrow_intro",
		"zip_intro",
		"pip_outlet",
		"morrow_outlet",
		"zip_outlet",
		"pip_relay",
		"morrow_relay",
		"zip_relay",
		"pip_join",
		"morrow_join",
		"zip_join",
		"pip_steal",
		"morrow_steal",
		"zip_steal",
		"toss",
		"turnover",
		"goal",
		"accord"
	]:
		clips[key] = load("res://assets/last_light/" + key + ".wav")
	var theme: AudioStreamOggVorbis = load("res://assets/last_light/last_light.ogg")
	theme.loop = true
	music.stream = theme
	music.volume_db = -9
	if DisplayServer.get_name() != "headless":
		music.play()
	# The sea against the dock, looped under everything.
	if ResourceLoader.exists("res://assets/last_light/waves.wav"):
		add_child(ambience)
		ambience.stream = load("res://assets/last_light/waves.wav")
		ambience.volume_db = -19.
		if DisplayServer.get_name() != "headless":
			ambience.play()
	voice.volume_db = -1
	effects.volume_db = -10
	audio_buses()
	add_child(front)
	add_child(comics)
	add_child(screens)
	screens.chosen.connect(handle)
	screens.cue.connect(func(kind: String, pitch: float): sound(kind, 0., pitch))
	front.sound.connect(func(kind: String): sound(kind))
	harbor.heard.connect(heard)
	if not test_session and not capture_session:
		radio_host.start()
	front.chosen.connect(handle)
	var pretrained = Game.Policy.new()
	pretrained.load_checkpoint("res://learning/star_checkpoint.json")
	# What the robots learned in practice about captains and promises.
	var practised = Game.Policy.new()
	practised.load_checkpoint("res://learning/social_checkpoint.json")
	pretrained.estimates.merge(practised.estimates)
	if not test_session and not capture_session:
		pretrained.add_local_examples("user://verified-responses.json")
	var saved = Game.Policy.new()
	if not test_session and not capture_session:
		saved.load_checkpoint(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
			if data is Dictionary and data.get("relationships") is Dictionary:
				social_memory = data.relationships
		if FileAccess.file_exists("user://bruin-coach.json"):
			var advice: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("user://bruin-coach.json")
			)
			if advice is Dictionary and advice.get("notes") is Array:
				bruin_notes = advice.notes
	for key in saved.estimates:
		var current: Array = pretrained.estimates.get(key, [0, 0, 0])
		if (
			(key.begins_with("star2/") or key.begins_with("soc8/"))
			and saved.estimates[key][0] > current[0]
		):
			pretrained.estimates[key] = saved.estimates[key]
	training = pretrained.estimates
	intro()


## Light painted on the deck: each half glows in its crew's colour, and the lines, arcs and centre
## circle shine, brighter as night comes. It adds light and never hides the deck under it.
const COURT_GLOW := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;
uniform vec2 half_size = vec2(11.0, 4.65);
uniform float ring = 11.0;
uniform float shot = 3.55;
uniform float night = 0.0;
uniform float seconds = 0.0;
uniform vec3 gold : source_color = vec3(1.0, 0.75, 0.34);
uniform vec3 blue : source_color = vec3(0.34, 0.85, 0.93);
varying vec2 at;
void vertex() { at = VERTEX.xz; }
float line(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.03, abs(d)); }
void fragment() {
	float x = at.x / half_size.x;
	vec3 side = x > 0.0 ? gold : blue;
	float wash = smoothstep(0.1, 1.0, abs(x)) * 0.10 + 0.025;
	float edge = max(line(abs(at.y) - (half_size.y + 0.2), 0.06), line(abs(at.x) - ring, 0.05));
	float middle = max(line(at.x, 0.05), line(length(at) - 1.19, 0.06));
	vec2 hoop = vec2(ring * sign(at.x), 0.0);
	float arc = line(length(at - hoop) - shot, 0.07) * step(abs(at.x), ring);
	float inside = (1.0 - smoothstep(shot - 0.05, shot, length(at - hoop))) * 0.08;
	float run = 0.75 + 0.25 * sin(seconds * 2.2 - length(at) * 0.9);
	float glow = 0.55 + 1.1 * night;
	vec3 col = side * (wash + inside) * (0.6 + 0.8 * night);
	col += vec3(1.0, 0.93, 0.8) * (edge + middle) * 0.55 * glow * run;
	col += side * arc * 1.6 * glow * run;
	ALBEDO = col;
}
"""


func court() -> void:
	add_child(dock_lights)
	dock_lights.build(room)
	var floor_paint := PlaneMesh.new()
	floor_paint.size = Vector2(Game.RING * 2. + 1.2, Game.BOUNDS.y * 2. + 1.2)
	court_glow.shader = Shader.new()
	court_glow.shader.code = COURT_GLOW
	court_glow.set_shader_parameter("half_size", Vector2(Game.RING, Game.BOUNDS.y))
	court_glow.set_shader_parameter("ring", Game.RING)
	court_glow.set_shader_parameter("shot", Game.SHOT_RANGE)
	court_glow.set_shader_parameter("gold", harbor.CREW[0])
	court_glow.set_shader_parameter("blue", harbor.CREW[1])
	var painted: MeshInstance3D = room.draw(self, floor_paint, Vector3(0, .062, 0), court_glow)
	painted.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var enamel = room.metal("ivory chalk", "#ada18b", .68, .14)
	var colored = [
		room.metal("gold beacon", "#ffba47", .32, .23, 2.),
		room.metal("blue beacon", "#4bdcfa", .31, .27, 1.8)
	]
	var brass = room.metal("copper housing", "#a3774e", .35, .68)
	var side_z: float = Game.BOUNDS.y + .20
	for z in [-side_z, side_z]:
		room.box(self, Vector3(0, .028, z), Vector3(Game.RING * 2. + .72, .021, .053), enamel)
	for n in int((side_z * 2. - .32) / .418) + 1:
		room.box(self, Vector3(0, .031, -side_z + .16 + n * .418), Vector3(.027, .018, .16), enamel)
	room.torus(self, Vector3(0, .038, 0), 1.17, 1.205, enamel)
	for side in 2:
		var x := Game.RING if side == 0 else -Game.RING
		var center := Vector3(x, Game.HEIGHT, 0)
		var ring := Node3D.new()
		add_child(ring)
		ring.position = center
		hoops.append(ring)
		for sign_side in [-1, 1]:
			room.tube(
				self,
				Vector3(x + signf(x) * .13, .05, sign_side * .72),
				center + Vector3(0, -.46, sign_side * .65),
				.062,
				brass
			)
			room.box(self, Vector3(x, .071, sign_side * .72), Vector3(.38, .11, .42), brass)
		room.torus(ring, Vector3.ZERO, .68, .76, colored[side]).rotation.z = PI * .5
		room.torus(ring, Vector3(signf(x) * .10, 0, 0), .71, .80, brass).rotation.z = PI * .5
		for k in 8:
			var a := TAU * k / 8.
			room.ball(
				ring, Vector3(0, cos(a) * .78, sin(a) * .78), Vector3.ONE * .048, colored[side]
			)
		room.placard(
			self,
			"GOLD" if side == 0 else "BLUE",
			center + Vector3(0, 1.05, 0),
			AMBER if side == 0 else BLUE,
			34
		)
		room.box(self, Vector3(x, .028, 0), Vector3(.047, .018, side_z * 2.), enamel)
		var paint := ImmediateMesh.new()
		paint.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 42:
			var a := -PI / 2. + PI * k / 42.
			var b := -PI / 2. + PI * (k + 1) / 42.
			var u := Vector3(-signf(x) * cos(a), 0, sin(a))
			var v := Vector3(-signf(x) * cos(b), 0, sin(b))
			for vertex in [
				u * Game.SHOT_RANGE,
				v * Game.SHOT_RANGE,
				u * (Game.SHOT_RANGE - .055),
				v * Game.SHOT_RANGE,
				v * (Game.SHOT_RANGE - .055),
				u * (Game.SHOT_RANGE - .055)
			]:
				paint.surface_add_vertex(vertex)
		paint.surface_end()
		var paint_mat: StandardMaterial3D = colored[side].duplicate()
		paint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		paint_mat.emission_energy_multiplier = .38
		room.draw(self, paint, Vector3(x, .052, 0), paint_mat)
		# The tapered net gives a side-on ring visible depth from the broadcast camera.
		for k in 12:
			var a := TAU * k / 12.
			var rim := Vector3(signf(x) * .08, .70 * cos(a), .70 * sin(a))
			for twist in [-1, 1]:
				var b: float = a + twist * PI / 12.
				room.tube(
					ring, rim, Vector3(signf(x) * .57, .45 * cos(b), .45 * sin(b)), .012, enamel
				)
		room.torus(ring, Vector3(signf(x) * .57, 0, 0), .44, .465, brass).rotation.z = PI * .5
	add_child(star)
	star.add_child(star_lamp)
	star_lamp.omni_range = 8.5
	star_lamp.light_color = Color("#ffd98a")
	star_lamp.light_energy = 0.
	var light = room.metal("stellar core", "#ffdc85", .22, .46, 3.1)
	room.ball(star, Vector3.ZERO, Vector3.ONE * .177, light)
	for k in 3:
		var orbit = room.torus(star, Vector3.ZERO, .201, .223, brass)
		orbit.rotation = Vector3(k * .92, 0, k * .8)
	for axis in [
		Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK
	]:
		var cone := CylinderMesh.new()
		cone.radial_segments = 5
		cone.top_radius = 0
		cone.bottom_radius = .068
		cone.height = .21
		var tip = room.draw(star, cone, axis * .213, light)
		tip.quaternion = Quaternion(Vector3.UP, axis)
	var glint = room.metal("arc guide", "#ffdd89", .35, .14, 1.20)
	for n in 6:
		var trail: MeshInstance3D = room.ball(
			self, Vector3.ZERO, Vector3.ONE * (.125 - n * .016), light
		)
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.hide()
		trail_meshes.append(trail)
	for n in 7:
		var dot = room.ball(self, Vector3.ZERO, Vector3.ONE * .027, glint)
		dot.hide()
		aim_dots.append(dot)
	shade_disc = room.torus(self, Vector3.ZERO, .18, .204, colored[0])
	# The edge of Morrow's anchor: carry the star inside it and you slow down.
	# It must not look like a court marking, so it is dashed, it turns and it carries a label.
	anchor_ring = Node3D.new()
	add_child(anchor_ring)
	anchor_paint = StandardMaterial3D.new()
	anchor_paint.emission_enabled = true
	anchor_paint.emission_energy_multiplier = 1.6
	for n in 22:
		var a := TAU * n / 22.
		var dash: MeshInstance3D = room.box(
			anchor_ring, Vector3(cos(a), 0, sin(a)) * (Game.ANCHOR_RANGE - .03), Vector3(.3, .022, .075), anchor_paint
		)
		dash.rotation.y = PI * .5 - a
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor_note.text = "MORROW'S SLOW ZONE"
	anchor_note.font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	anchor_note.font_size = 42
	anchor_note.pixel_size = .0056
	anchor_note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	anchor_note.outline_size = 8
	anchor_note.no_depth_test = true
	anchor_note.layers = 2
	add_child(anchor_note)
	anchor_ring.hide()
	anchor_note.hide()
	# Four floodlights, dark at sunset and bright by night. The two at the back hang under
	# hovering lamp drones that bob and turn over the corners of the court.
	flood_glass = room.metal("floodlight glass", "#fff3d6", .2, .0, .15)
	var shell = room.metal("drone shell", "#2a3340", .45, .55)
	var trim = room.metal("drone trim", "#ff6fb5", .4, .2, 1.2)
	var blade = room.metal("drone blade", "#dfe6ee", .4, .3)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var head := Vector3(corner.x * (Game.RING + 1.7), 7.6, corner.y * (Game.BOUNDS.y + 2.4))
		if corner.y < 0:
			head.z = -Game.BOUNDS.y - 3.4
		var aim := Vector3(corner.x * 3.5, 0, corner.y * 1.2)
		var drone := Node3D.new()
		add_child(drone)
		drone.position = head
		var rotors: Array = []
		if corner.y < 0:
			room.ball(drone, Vector3.ZERO, Vector3(.62, .24, .62), shell)
			room.torus(drone, Vector3(0, -.02, 0), .6, .66, trim)
			for k in 4:
				var a := TAU * k / 4. + PI * .25
				var tip := Vector3(cos(a), .12, sin(a)) * 1.05
				room.tube(drone, Vector3.ZERO, tip, .05, shell)
				room.torus(drone, tip + Vector3(0, .05, 0), .42, .47, shell)
				var rotor := Node3D.new()
				drone.add_child(rotor)
				rotor.position = tip + Vector3(0, .08, 0)
				room.box(rotor, Vector3.ZERO, Vector3(.8, .015, .08), blade)
				rotors.append(rotor)
			# The lamp bank hangs under the body, tilted down at the court.
			var bank := Node3D.new()
			drone.add_child(bank)
			bank.position = Vector3(0, -.36, 0)
			bank.look_at_from_position(head + bank.position, aim)
			room.box(bank, Vector3.ZERO, Vector3(1.1, .36, .2), shell)
			for k in 3:
				room.box(bank, Vector3((k - 1) * .34, 0, -.11), Vector3(.26, .26, .03), flood_glass)
			room.ball(drone, Vector3(-.62, -.05, 0), Vector3.ONE * .06, room.metal("nav red", "#ff3b3b", .3, 0., 3.))
			room.ball(drone, Vector3(.62, -.05, 0), Vector3.ONE * .06, room.metal("nav green", "#3bff7a", .3, 0., 3.))
			for part in drone.find_children("*", "MeshInstance3D", true, false):
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lamp := SpotLight3D.new()
		add_child(lamp)
		lamp.position = head
		lamp.look_at_from_position(head, aim)
		drones.append({"node": drone, "home": head, "aim": aim, "lamp": lamp, "rotors": rotors, "seed": randf() * 20.})
		lamp.spot_range = 30.
		lamp.spot_angle = 52.
		lamp.spot_attenuation = .7
		lamp.light_color = Color("#fff1dc")
		lamp.light_energy = 0.
		lamp.shadow_enabled = false
		floods.append(lamp)
	# Each ring throws its own colour across its end of the court.
	for side in 2:
		var wash := OmniLight3D.new()
		add_child(wash)
		wash.position = Vector3((Game.RING - 1.4) * (1 if side == 0 else -1), 2.4, 0)
		wash.omni_range = 9.5
		wash.light_color = harbor.CREW[side]
		wash.light_energy = 1.15
		ring_glow.append(wash)
	# A comet tail of motes behind the star, and sparks behind anyone who dashes.
	var mote := SphereMesh.new()
	mote.radius = .05
	mote.height = .1
	mote.radial_segments = 6
	mote.rings = 3
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.vertex_color_use_as_albedo = true
	shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.material = shine
	for n in 6:
		var trail := CPUParticles3D.new()
		add_child(trail)
		trail.mesh = mote
		trail.amount = 34 if n == 5 else 26
		trail.lifetime = .55 if n == 5 else .4
		trail.emitting = false
		trail.spread = 180.
		trail.gravity = Vector3(0, .6, 0) if n == 5 else Vector3(0, -1.5, 0)
		trail.initial_velocity_min = .15
		trail.initial_velocity_max = .7 if n == 5 else 1.6
		trail.scale_amount_min = .5
		trail.scale_amount_max = 1.5
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, .8, .4, 0.))
		trail.color_ramp = fade
		wakes.append(trail)
	beacon = room.make_whale(self, 3.8)
	beacon.hide()


func intro() -> void:
	room.location(0)
	dock_lights.age = 10.
	dock_lights.sync(0., [0, 0], false, 0., room.life.reduced)
	phase = "title"
	comics.quiet()
	comics.close_page()
	chapter = -1
	tale = -1
	voice_queue.clear()
	chapter_time = 0
	duration = 3.7
	front.match_hud.hide()
	front.leave()
	screens.title()
	voice.stop()
	star.show()
	for doll in cast:
		doll.rotation.x = 0.
	for dot in aim_dots + trail_meshes:
		dot.hide()
	for note in deal_tags:
		note.hide()
	anchor_ring.hide()
	set_dusk(0.)
	beacon.rotation = Vector3.ZERO
	beacon.scale = Vector3.ONE * .58
	beacon.position = Vector3(3.15, 3.93, -4.65)
	beacon.show()
	for hoop in hoops:
		hoop.scale = Vector3.ONE
	for i in 5:
		var p: Vector2 = LINEUP[i]
		cast[i].show()
		cast[i].position = Vector3(p.x, 0, p.y)
		cast[i].rotation.y = -.11 if i < 3 else .12
		cast[i].tag.hide()
		badges[i][0].hide()
	shade_disc.hide()
	wide(true)


func next_card() -> void:
	if phase in ["title", "prologue"] and tale < TALE.size() - 1:
		phase = "prologue"
		tale += 1
		chapter_time = 0
		var told := "morrow_tale%d" % (tale + 1)
		duration = 4.6
		if clips.has(told):
			say(told)
			duration = maxf(3.6, clips[told].get_length() + .85)
		front.leave()
		if tale == 0:
			screens.leave()
			sound("whoosh")
		sound("page")
		comics.tale(TALE[tale][0], TALE[tale][1], "SPACE  next page      ESC  skip to the controls")
		vista(0.)
		return
	if chapter >= 4:
		show_controls()
		return
	phase = "story"
	chapter += 1
	chapter_time = 0
	var key := str(Performer.FILES[chapter]) + "_intro"
	say(key)
	duration = maxf(4.4, clips[key].get_length() + 1.25)
	front.leave()
	sound("page")
	portrait(0.)
	# The star stays in Nell's hands for her page and out of the way for the others.
	star.visible = chapter == 0
	# A comic page for each of the five: name, trade, their own words and their one power.
	var who: PackedStringArray = str(CAST[chapter][0]).split("/")
	var gift: PackedStringArray = str(CAST[chapter][2]).split("·")
	comics.meet(
		who[0].strip_edges(),
		who[1].strip_edges(),
		CAST[chapter][1],
		gift[0].strip_edges(),
		gift[1].strip_edges(),
		PAGE_TINT[chapter],
		camera.unproject_position(cast[chapter].position + Vector3(0, FACE[chapter] + .12, 0)),
		"SPACE  next page      ESC  skip to the controls"
	)


## Three slow shots for the story: the whale over the harbor, the dock, then the machines.
func vista(t: float) -> void:
	var drift := sin(t * .22) * .35
	match tale:
		0:
			camera.fov = 25.
			camera.position = Vector3(-1.2 + drift, 2.3, 9.2)
			camera.look_at(Vector3(2.2, 2.95, -4.6))
		1:
			camera.fov = 43.
			camera.position = Vector3(drift, 3.9 - .05 * t, 10.6 - .12 * t)
			camera.look_at(Vector3(0, 1.2, -.6))
		_:
			camera.fov = 36.
			camera.position = Vector3(.2 + drift, 1.75, 5.6 - .1 * t)
			camera.look_at(Vector3(0, 1.05, 0))


func portrait(t: float) -> void:
	var p: Vector3 = cast[chapter].position
	var y: float = [1.34, 1.40, .67, 1.25, 1.14][chapter]
	var aim := p + Vector3(.12, y, 0)
	var lenses := [
		Vector3(.80, .17, 2.55),
		Vector3(-.64, .02, 2.65),
		Vector3(.46, -.16, 2.12),
		Vector3(-.58, -.24, 2.56),
		Vector3(.85, .24, 2.44)
	]
	var dir: Vector3 = lenses[chapter] + Vector3(sin(t * .28) * .22, .025 * t, -.055 * minf(t, 4.))
	camera.position = aim + dir
	camera.fov = 37.4
	camera.look_at(aim)


func wide(lineup := false) -> void:
	camera.fov = 43. if lineup else 46.
	camera.position = (
		Vector3(0, 3.77, 10.9) if lineup else Vector3(0, 9.4, 16.7) * (Game.RING / Game.OLD_RING)
	)
	camera.look_at(Vector3(0, 1.62, -.60) if lineup else Vector3(0, .56, 0))


func select_mode() -> void:
	end_log()
	intro()
	comics.close_page()
	phase = "select"
	screens.modes()


## How to play: both players' keys, side by side, with who each of them is playing.
func show_controls() -> void:
	if phase in ["prologue", "story"] or phase == "title":
		sound("whoosh")
	end_log()
	intro()
	comics.close_page()
	voice.stop()
	phase = "controls"
	screens.controls(pilot_for_seat)


func pilot_names() -> Array:
	return [Game.NAMES[pilot_for_seat[0]], Game.NAMES[pilot_for_seat[1]]]


func mode_label() -> String:
	return "FREE AGENTS" if free else ("OPEN CREWS" if crews else "RIVALS")


func side_names() -> Array:
	if free:
		return ["HUMANS", "UNION"] if sim.union else ["NELL'S CREW", "RAFI'S CREW"]
	return ["GOLD CREW", "BLUE CREW"] if crews else ["HUMANS", "ROBOTS"]


## The robots take the harbor lights with them when they walk out.
func set_dusk(amount: float) -> void:
	dusk = amount
	star_lamp.light_energy = 4.2 * amount


## The lamp drones bob and drift over their corners, rotors spinning, and their spotlights go
## with them.
func hover(dt: float) -> void:
	for d in drones:
		var t: float = harbor.seconds + d.seed
		var node: Node3D = d.node
		node.position = d.home + Vector3(.25 * sin(t * .7), .3 * sin(t * 1.1) + .12 * sin(t * 2.3), .2 * cos(t * .9))
		node.rotation = Vector3(.06 * sin(t * 1.3), .18 * sin(t * .4), .06 * cos(t * 1.1))
		for rotor in d.rotors:
			rotor.rotation.y += dt * 38.
		var lamp: SpotLight3D = d.lamp
		lamp.look_at_from_position(node.position + Vector3(0, -.4, 0), d.aim)


## The scene's lights follow the sky: a warm low sun at kickoff, moonlight and court lamps by the
## whistle, and near darkness when the robots walk out.
func light_scene() -> void:
	var night: float = harbor.dusk
	var cold: float = harbor.cold
	var out: float = dusk
	room.sun.light_energy = lerpf(1.35, .2, night) * (1. - .8 * out)
	room.sun.light_color = Color("#ffb67a").lerp(Color("#9db4ff"), maxf(night, cold * .7))
	room.fill.light_energy = lerpf(1.25, .5, night) * (1. - .6 * out)
	room.fill.light_color = Color("#ffe6cf").lerp(Color("#cfdcff"), night)
	room.world_env.ambient_light_energy = lerpf(.95, .6, night) * (1. - .55 * out)
	# The dock's floodlights come on as the sun goes, so a night match is lit like a stadium.
	for lamp in floods:
		lamp.light_energy = 2.6 * smoothstep(.22, .7, night) * (1. - .85 * out)
	flood_glass.emission_energy_multiplier = .15 + 5. * smoothstep(.22, .7, night) * (1. - .85 * out)
	room.world_env.fog_light_color = Color("#f0a27e").lerp(Color("#28305a"), night).lerp(
		Color("#3a4f78"), cold * .6
	)
	# The lighting sky is re-baked whenever it changes, so it changes in small steps, not every frame.
	var step: float = snappedf(night, .05)
	if not is_equal_approx(step, sky_step):
		sky_step = step
		room.sky_paint.sky_horizon_color = Color("#ffb07a").lerp(Color("#3b3f70"), step)
		room.sky_paint.sky_top_color = Color("#4a4f8c").lerp(Color("#10142c"), step)
	court_glow.set_shader_parameter("night", night)
	court_glow.set_shader_parameter("seconds", harbor.seconds)
	for wash in ring_glow:
		wash.light_energy = lerpf(.9, 2.1, night) * (.35 if phase in ["title", "prologue", "story"] else 1.)


func select_pilots() -> void:
	room.location(int(crews and not free))
	phase = "pilots"
	star.hide()
	for i in 5:
		cast[i].visible = i < 2
		if i < 2:
			cast[i].position = Vector3(-.90 if i == 0 else .90, 0, 0)
			cast[i].rotation.y = .10 if i == 0 else -.10
			cast[i].tag.text = Game.NAMES[i]
			cast[i].tag.font_size = 24
			cast[i].tag.position.y = 1.98
			cast[i].tag.show()
	camera.position = Vector3(0, 1.72, 4.70)
	camera.fov = 36.
	camera.look_at(Vector3(0, 1.30, 0))
	front.pilots(mode_label())


func handle(cmd: String) -> void:
	match cmd:
		"next", "begin":
			next_card()
		"skip", "select", "modes":
			if phase == "controls":
				sound("whoosh")
			select_mode()
		"controls":
			show_controls()
		"swap":
			pilot_for_seat.assign([pilot_for_seat[1], pilot_for_seat[0]])
			screens.controls(pilot_for_seat)
		"story":
			intro()
			screens.leave()
			next_card()
		"replay":
			intro()
		"rivals", "crews", "free":
			crews = cmd == "crews"
			free = cmd == "free"
			# The mode card already explained the game, so go straight to the court.
			for seat in 2:
				cast[pilot_for_seat[seat]].tag.text = (
					"P%d  %s" % [seat + 1, Game.NAMES[pilot_for_seat[seat]]]
				)
			sound("whoosh")
			screens.leave()
			start()
		"pilots":
			select_pilots()
		"nell", "rafi":
			pilot_for_seat.assign([0, 1] if cmd == "nell" else [1, 0])
			phase = "brief"
			for seat in 2:
				cast[pilot_for_seat[seat]].tag.text = (
					"P%d  %s" % [seat + 1, Game.NAMES[pilot_for_seat[seat]]]
				)
			front.briefing(mode_label(), pilot_names())
		"again", "play":
			start()
		"resume":
			phase = "play"
			command_edges = [{}, {}]
			front.match_view()
		"sound", "music":
			if cmd == "sound":
				sound_on = not sound_on
			else:
				music_on = not music_on
			apply_audio()
			front.pause_menu(sound_on, music_on, cmd)


func connect_radio() -> void:
	var url: String = radio_host.address()
	if url != "" and not coach:
		coach = Coach.new()
		add_child(coach)
		coach.configure(url)


func start() -> void:
	end_log()
	beacon_start_tick = 0
	beacon_end_tick = 0
	goal_pose.clear()
	dock_lights.age = 10.
	scoring_team = -1
	sim = Game.new()
	sim.configure_agents(training, social_memory)
	var seed_value := forced_seed if forced_seed >= 0 else int(random.randi())
	sim.setup(seed_value, crews, free)
	sim.mercy = not full_strength
	harbor.restart()
	comics.quiet()
	comics.close_page()
	comics.ink(0.)
	sim.social_learning = free and not written_rules
	sim.draft()
	sim.set_bruin_coach(bruin_notes)
	set_dusk(0.)
	connect_radio()
	box_score = {"passes": [0, 0], "shots": [0, 0], "steals": [0, 0], "relays": 0, "beacons": 0}
	trail_points.clear()
	touch_pose_until.fill(0)
	camera_focus = Vector2.ZERO
	camera_distance = 17.2
	gather_tick = -20
	phase = "walk_on"
	beacon.scale = Vector3.ONE
	beacon.hide()
	chapter_time = 0.
	command_edges = [{}, {}]
	pad_edges = [{}, {}]
	star.show()
	last_voice = -200
	voice_queue.clear()
	last_ledger = [-1, -1, -99, -99, -99]
	last_lesson.fill(-1)
	message_until = 230
	message = "Nell has the light. Gold attacks right."
	if free:
		message = (
			"%s serves. Nell attacks right, Rafi attacks left. Keep your word."
			% Game.NAMES[sim.owner]
		)
	positions = sim.pos.duplicate()
	old_ball = sim.ball
	front.clear_log()
	front.ledger.text = ""
	front.ledger.hide()
	front.match_view()
	wide()
	room.location(int(crews and not free))
	voice.stop()
	shade_disc.show()
	for i in 5:
		cast[i].show()
		cast[i].tag.font_size = 36
		cast[i].tag.show()
		badges[i][0].show()
		cast[i].rotation.y = PI * .48 if sim.team[i] == 0 else -PI * .48
	render_game(0., 1.)
	var run := "%d-%d" % [Time.get_unix_time_from_system() * 1000000, seed_value]
	match_run = run
	panel_age = 0.
	if panel_box:
		panel_box.hide()
	var directory := "user://flights"
	if test_session or capture_session:
		directory = "user://court-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	recorder = Recorder.new()
	recorder.begin(
		directory + "/" + run + ".jsonl",
		{
			"kind": "header",
			"run": run,
			"seed": seed_value,
			"game": "last-light-v14",
			"court_version": 14,
			"mercy": sim.mercy,
			"social_learning": sim.social_learning,
			"dock_relay": sim.relay_rules,
			"moving_passes": sim.moving_passes,
			"origin": "capture" if test_session or capture_session else "local_play",
			"open_crews": crews,
			"free_agents": free,
			"input_schema": 1,
			"starting_policy": sim.learned_weights().duplicate(true),
			"starting_relationships": sim.relationships(),
			"bruin_coach": sim.bruin_notes.duplicate(true),
			"seat_pilots": pilot_names(),
			"gemini_models": coach.models.duplicate() if coach else []
		}
	)
	# The draft happened before kickoff. Show it during the walk-on and keep it first in the log.
	for e in sim.events:
		present(e)
	recorder.append(sim.events)
	sim.events = []
	update_hud()


func end_log() -> void:
	if coach:
		sim.apply_model_packets(coach.close(), true)
		recorder.append(sim.events)
		sim.events = []
		coach.queue_free()
		coach = null
	if recorder.opened:
		training = sim.learned_weights()
		social_memory = sim.relationships()
		if not capture_session and not test_session:
			var path := SAVE_PATH
			var staged := path + ".next." + str(OS.get_process_id())
			var f := FileAccess.open(staged, FileAccess.WRITE)
			if f:
				f.store_string(
					JSON.stringify(
						{
							"schema": "response-policy-v1",
							"estimates": training,
							"relationships": social_memory
						}
					)
				)
				f.close()
				DirAccess.rename_absolute(
					ProjectSettings.globalize_path(staged), ProjectSettings.globalize_path(path)
				)
		recorder.finish(
			{
				"kind": "footer",
				"tick": sim.tick,
				"gold": sim.goals[0],
				"blue": sim.goals[1],
				"completed": sim.finished
			}
		)


func _exit_tree() -> void:
	end_log()
	radio_host.stop()
	for player in [music, voice, effects]:
		player.stop()
		player.stream = null


## Look twice a second, for up to 30 s after the whistle, for this match's comic panel.
func show_match_panel(dt: float) -> void:
	if (panel_box and panel_box.visible) or match_run == "":
		return
	panel_age += dt
	if panel_age > 30. or fmod(panel_age, .5) > dt:
		return
	var path := ProjectSettings.globalize_path("user://panels/%s.png" % match_run)
	if not FileAccess.file_exists(path):
		return
	var picture := Image.load_from_file(path)
	if picture == null or picture.is_empty():
		return
	if panel_box == null:
		build_match_panel()
	panel_image.texture = ImageTexture.create_from_image(picture)
	panel_caption.text = ""
	var notes := ProjectSettings.globalize_path("user://panels/%s.json" % match_run)
	if FileAccess.file_exists(notes):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(notes))
		if data is Dictionary:
			panel_caption.text = str(data.get("caption", ""))
	panel_box.show()
	sound("page")


func build_match_panel() -> void:
	panel_box = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(.05, .06, .09, .94)
	frame.border_color = Color("#ffd27a")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(6)
	frame.set_content_margin_all(10)
	panel_box.add_theme_stylebox_override("panel", frame)
	panel_box.anchor_left = 1.
	panel_box.anchor_right = 1.
	panel_box.offset_left = -500.
	panel_box.offset_right = -24.
	panel_box.offset_top = 24.
	panel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	panel_box.add_child(column)
	var kicker := Label.new()
	kicker.text = "THE MATCH IN ONE PANEL"
	kicker.add_theme_color_override("font_color", Color("#ffd27a"))
	column.add_child(kicker)
	panel_image = TextureRect.new()
	panel_image.custom_minimum_size = Vector2(456, 256)
	panel_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(panel_image)
	panel_caption = Label.new()
	panel_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_caption.custom_minimum_size = Vector2(456, 0)
	column.add_child(panel_caption)
	var credit := Label.new()
	credit.text = "Drawn by Runware from this match's log"
	credit.add_theme_font_size_override("font_size", 13)
	credit.modulate = Color(1, 1, 1, .7)
	column.add_child(credit)
	front.add_child(panel_box)
	panel_box.hide()


func say(key: String) -> void:
	voice.stream = clips[key]
	if DisplayServer.get_name() != "headless":
		voice.play()


func match_call(actor: int, cue: String, gap: int) -> void:
	if not voice.playing and voice_queue.is_empty() and sim.tick - last_voice >= gap:
		say(Performer.FILES[actor] + "_" + cue)
		last_voice = sim.tick


## Promise and vote lines wait their turn so every robot is heard in order.
func speak(actor: int, cue: String) -> void:
	var key := str(Performer.FILES[actor]) + "_" + cue
	if not clips.has(key) or key in voice_queue:
		return
	voice_queue.push_back(key)
	while voice_queue.size() > 6:
		voice_queue.pop_front()


func next_line() -> void:
	if voice_queue.is_empty() or voice.playing:
		return
	var key: String = voice_queue.pop_front()
	if key.ends_with("_call") or key.ends_with("_aye") or key.ends_with("_nay"):
		sound("radio")
	say(key)
	last_voice = sim.tick
	# The same words in a balloon beside the speaker's face.
	var said: PackedStringArray = key.split("_", true, 1)
	var speaker: int = Performer.FILES.find(said[0])
	if speaker >= 0 and said.size() == 2:
		comics.say(
			cast[speaker],
			FACE[speaker],
			Game.NAMES[speaker].to_upper(),
			comics.SAID.get(said[0], {}).get(said[1], ""),
			tint_of(speaker)
		)


## Music on its own bus and everything else on another, so each can be switched off alone.
func audio_buses() -> void:
	for called in ["Music", "Sound"]:
		if AudioServer.get_bus_index(called) < 0:
			AudioServer.add_bus()
			var n := AudioServer.bus_count - 1
			AudioServer.set_bus_name(n, called)
			AudioServer.set_bus_send(n, "Master")
	music.bus = "Music"
	for player in [ambience, voice, effects] + sfx_pool:
		player.bus = "Sound"
	if not test_session and not capture_session:
		var saved := ConfigFile.new()
		if saved.load(AUDIO_SETTINGS) == OK:
			sound_on = bool(saved.get_value("audio", "sound", true))
			music_on = bool(saved.get_value("audio", "music", true))
	apply_audio()


func apply_audio() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sound"), not sound_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	if test_session or capture_session:
		return
	var saved := ConfigFile.new()
	saved.set_value("audio", "sound", sound_on)
	saved.set_value("audio", "music", music_on)
	saved.save(AUDIO_SETTINGS)


func sound(key: String, louder: float = 0., pitch: float = 1.) -> void:
	# One copy of a sound per frame, on the next free layer, so effects overlap without cutting off.
	var frame := Engine.get_process_frames()
	if not clips.has(key) or sfx_frame.get(key, -1) == frame:
		return
	sfx_frame[key] = frame
	var layer: AudioStreamPlayer = sfx_pool[sfx_turn]
	sfx_turn = (sfx_turn + 1) % sfx_pool.size()
	layer.stream = clips[key]
	layer.volume_db = -7. + float(MIX.get(key, 0.)) + louder
	layer.pitch_scale = pitch
	if DisplayServer.get_name() != "headless":
		layer.play()


## Something happened out on the water. The farther away, the quieter.
func heard(kind: String, where: Vector3, power: float) -> void:
	var far: float = maxf(8., camera.global_position.distance_to(where))
	var louder: float = 20. * log(power * 22. / far) / log(10.)
	if louder > -26.:
		sound(kind, clampf(louder, -26., 2.), randf_range(.9, 1.08))


func _input(ev: InputEvent) -> void:
	# A click or a gamepad button works like a key on the title and the story pages.
	if (
		(ev is InputEventMouseButton or ev is InputEventJoypadButton)
		and ev.pressed
		and phase in ["title", "prologue", "story"]
	):
		if phase != "title" or screens.title_key():
			next_card()
		get_viewport().set_input_as_handled()
		return
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: int = ev.physical_keycode
	if k == KEY_M:
		# M silences everything, or brings everything back.
		var on := not (sound_on or music_on)
		sound_on = on
		music_on = on
		apply_audio()
		if phase == "pause":
			front.pause_menu(sound_on, music_on)
		return
	if k == KEY_B:
		room.life.reduced = not room.life.reduced
		return
	if phase == "title" and k != KEY_ESCAPE:
		# Any key: the first finishes the title, the next starts the story.
		if screens.title_key():
			next_card()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_ESCAPE:
		match phase:
			"brief":
				select_pilots()
			"title", "story", "prologue":
				show_controls()
			"controls", "pilots", "end":
				handle("modes")
			"select":
				sound("ui_back")
				show_controls()
			"pause":
				handle("resume")
			"play":
				phase = "pause"
				front.pause_menu(sound_on, music_on)
		get_viewport().set_input_as_handled()
		return
	if phase in ["story", "prologue"] and (k == KEY_SPACE or k == KEY_ENTER):
		next_card()
		get_viewport().set_input_as_handled()
		return
	if phase != "play":
		return
	if k == KEY_TAB:
		front.ledger.visible = not front.ledger.visible
	# Two buttons per seat. GO shoots in range and dashes otherwise. SHARE passes, calls or offers.
	var smart := {KEY_SPACE: [0, "go"], KEY_F: [0, "share"], KEY_ENTER: [1, "go"], KEY_KP_ENTER: [1, "go"], KEY_SLASH: [1, "share"]}
	if smart.has(k):
		press(smart[k][0], smart[k][1])
	# The single-purpose keys still work for anyone who wants them.
	var keys := [[KEY_E, KEY_SHIFT, KEY_Q, KEY_R], [KEY_NONE, KEY_PERIOD, KEY_P, KEY_COMMA]]
	for i in 2:
		var n: int = keys[i].find(k)
		if n >= 0:
			command_edges[pilot_for_seat[i]][["shoot", "dash", "invite", "ally_pass"][n]] = true
	get_viewport().set_input_as_handled()


## One of a seat's two buttons, turned into what it means right now.
func press(seat: int, button: String) -> void:
	var pilot: int = pilot_for_seat[seat]
	var verb: String = (
		Easy.go(sim, pilot) if button == "go" else Easy.share(sim, pilot, steer[pilot])
	)
	command_edges[pilot][verb] = true


func _physics_process(_dt: float) -> void:
	if phase != "play":
		return
	if not coach and sim.tick % 30 == 0:
		connect_radio()
	var keys := [[KEY_A, KEY_D, KEY_W, KEY_S], [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]]
	for i in 2:
		command_edges[pilot_for_seat[i]]["move"] = Vector2(
			(
				int(Input.is_physical_key_pressed(keys[i][1]))
				- int(Input.is_physical_key_pressed(keys[i][0]))
			),
			(
				int(Input.is_physical_key_pressed(keys[i][3]))
				- int(Input.is_physical_key_pressed(keys[i][2]))
			)
		)
		steer[pilot_for_seat[i]] = command_edges[pilot_for_seat[i]]["move"]
	var pads := Input.get_connected_joypads()
	for n in mini(pads.size(), 2):
		var seat := 1 if pads.size() == 1 else n
		var stick := Vector2(
			Input.get_joy_axis(pads[n], JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pads[n], JOY_AXIS_LEFT_Y)
		)
		if stick.length() > .20:
			command_edges[pilot_for_seat[seat]]["move"] = stick.limit_length(1.)
			steer[pilot_for_seat[seat]] = stick.limit_length(1.)
		# A is GO and X is SHARE. The other buttons keep their single purpose.
		for binding in [
			["go", JOY_BUTTON_A],
			["share", JOY_BUTTON_X],
			["dash", JOY_BUTTON_RIGHT_SHOULDER],
			["invite", JOY_BUTTON_Y],
			["ally_pass", JOY_BUTTON_B]
		]:
			var down := Input.is_joy_button_pressed(pads[n], binding[1])
			if down and not pad_edges[seat].get(binding[0], false):
				if binding[0] in ["go", "share"]:
					press(seat, binding[0])
				else:
					command_edges[pilot_for_seat[seat]][binding[0]] = true
			pad_edges[seat][binding[0]] = down
	positions = sim.pos.duplicate()
	old_ball = sim.ball
	sim.step(command_edges, coach.poll(sim) if coach else [])
	if sim.owner == -1 and sim.flight != "":
		trail_points.push_front(old_ball)
		if trail_points.size() > trail_meshes.size() * 2:
			trail_points.pop_back()
	else:
		trail_points.clear()
	command_edges = [{}, {}]
	for e in sim.events:
		present(e)
	recorder.append(sim.events)
	sim.events = []
	var seconds_left: int = sim.end_tick - sim.tick
	if seconds_left > 0 and seconds_left <= 600 and seconds_left % 60 == 0:
		sound("tick")
	if sim.finished:
		end_log()
		phase = "whistle"
		sound("whistle")
		whistle_age = 0.
		update_hud()
	else:
		update_hud()


func present(e: Dictionary) -> void:
	var i: int = e.seat
	match str(e.kind):
		"action_grade":
			if e.type == "court_throw" and e.action == "pass" and e["pass"]:
				box_score.passes[e.team] += 1
		"throw":
			touch_pose_until[i] = sim.tick + 18
			if e.action == "shot":
				box_score.shots[e.team] += 1
			else:
				message = "%s passes to %s" % [Game.NAMES[i], Game.NAMES[e.to]]
				message_until = sim.tick + 70
			sound("throw")
		"dash":
			sound("dash")
		"power":
			if e.action == "getaway":
				message = "Pip bolts with the star!"
				message_until = sim.tick + 80
				sound("dash")
				comics.pop("ZOOM!", over(2), Color("#ff9450"))
			else:
				message = "Morrow's anchor slows %s." % Game.NAMES[e.on]
				message_until = sim.tick + 80
				comics.pop("ANCHOR!", over(3), Color("#f0c869"))
		"dock_relay":
			dock_lights.signal_crew(e.team, e.charged)
			var crew := "Gold" if e.team == Game.GOLD else "Blue"
			message = (
				crew
				+ (
					" relay lit! The crew can dash again."
					if e.charged
					else " relay · Complete one more pass to recharge dash."
				)
			)
			message_until = sim.tick + 95
			if e.charged:
				box_score.relays += 1
				sound("accord")
				var speaker: int = i if i >= 2 else int(e["from"])
				if speaker >= 2:
					match_call(speaker, "relay", 60)
		"response_intent":
			if e.choice == "outlet" and sim.owner in [0, 1] and sim.team[i] == sim.team[sim.owner]:
				match_call(i, "outlet", 230)
			if sim.tick - last_ledger[i] > (420 if free else 100):
				front.record(e.reason, Game.NAMES[i], tint_of(i))
				last_ledger[i] = sim.tick
		"custody":
			if e.method == "restart":
				return
			if e.method == "catch":
				touch_pose_until[i] = sim.tick + 12
				gather_tick = sim.tick
				gather_offset = old_ball - sim.ball
				sound("catch")
			if e.method == "steal" or e.get("intercepted", false):
				box_score.steals[e.team] += 1
				comics.pop(
					["YOINK!", "SNATCH!", "MINE!"][int(e.seq) % 3] if e.method == "steal" else "DENIED!",
					over(i),
					tint_of(i)
				)
				sound("steal" if clips.has("steal") else "turnover")
				if i >= 2:
					match_call(i, "steal", 170)
			if sim.tick >= message_until or e.method in ["steal", "catch"]:
				message = (
					Game.NAMES[i]
					+ (
						" steals the light!"
						if e.method == "steal"
						else (
							" intercepts!" if e.get("intercepted", false) else " catches the light."
						)
					)
				)
				message_until = sim.tick + 67
		"robbed":
			if int(e.times) >= 2:
				front.record(
					"%s has robbed me %d times." % [Game.NAMES[e.by], e.times],
					Game.NAMES[i],
					tint_of(i)
				)
		"juke":
			comics.pop("JUKE!", over(i), tint_of(i))
			sound("dash")
			message = "%s sidesteps %s's dash!" % [Game.NAMES[i], Game.NAMES[e["from"]]]
			message_until = sim.tick + 80
		"coach_note":
			# Coach Bruin's advice for this robot, from the failure tables, read out at kickoff.
			front.record("Coach Bruin: " + str(e.advice), Game.NAMES[i], tint_of(i))
		"lesson":
			# A robot changed what it does after being robbed: its words in a balloon by its face.
			comics.say(cast[i], FACE[i], Game.NAMES[i].to_upper(), e.line, tint_of(i))
			comics.pop("LEARNED!", over(i), tint_of(i))
			front.record(e.line, Game.NAMES[i], tint_of(i))
			message = "%s learned: %s" % [Game.NAMES[i], e.line]
			message_until = sim.tick + 150
		"talk":
			# One robot telling other robots something: its words in a balloon, and who they were for.
			var heard_by := ""
			for k in e.to:
				heard_by += (" and " if heard_by != "" else "") + str(Game.NAMES[int(k)])
			comics.say(cast[i], FACE[i], Game.NAMES[i].to_upper(), e.line, tint_of(i))
			# A warning follows a steal, which already has its own sound word on that spot.
			if e.topic != "warn":
				comics.pop({"tip": "TIP!", "heed": "GOT IT!"}.get(e.topic, "CREW!"), over(i), tint_of(i))
			front.record("To %s: %s" % [heard_by, e.line], Game.NAMES[i], tint_of(i))
			message = "%s to %s: %s" % [Game.NAMES[i], heard_by, e.line]
			message_until = sim.tick + 150
			sound("radio")
		"goal":
			dock_lights.signal_crew(e.team, true)
			harbor.cheer(e.team)
			sound("crowd_cheer")
			goal_pose = positions.duplicate()
			scoring_team = e.team
			goal_spot = Vector3(Game.RING if scoring_team == 0 else -Game.RING, Game.HEIGHT, 0)
			sound("goal_big" if clips.has("goal_big") else "goal")
			message = (
				Game.NAMES[i] + " lights the " + ("gold" if e.team == 0 else "blue") + " ring!"
			)
			message_until = sim.tick + 128
			front.record(message)
			comics.pop(
				"GOAL!",
				get_viewport().get_visible_rect().size * Vector2(.5, .36),
				harbor.CREW[e.team],
				true
			)
		"aurora":
			if e.tick >= beacon_end_tick:
				beacon_start_tick = e.tick
			beacon_end_tick = e.until
			box_score.beacons += 1
			message = Game.NAMES[i] + " lit the far beacon. Both rings widen!"
			message_until = sim.tick + 138
			front.record(message)
		"pass_request":
			message = Game.NAMES[i] + " calls to " + Game.NAMES[e.to] + " for the ball."
			message_until = sim.tick + 90
		"alliance":
			message = e.reason
			message_until = sim.tick + 145
			if free:
				front.record(e.reason, Game.NAMES[i], tint_of(i))
			else:
				front.record(message)
			if e.changed and not e.get("draft", false):
				sound("accord")
				if free:
					var leaving: bool = str(e.reason).contains("walks out")
					speak(i, "walk" if leaving else "sign")
					comics.pop("I QUIT!" if leaving else "SIGNED!", over(i), tint_of(i))
				elif e.team == 0:
					say(Performer.FILES[i] + "_join")
					last_voice = sim.tick
		"out_of_reach":
			message = (
				"Move beside a robot to offer terms."
				if free
				else "Move beside a robot to offer a jersey."
			)
			message_until = sim.tick + 100
		"deal":
			front.record(
				"%s owes me: %s." % [Game.NAMES[e.human], e.terms], Game.NAMES[i], tint_of(i)
			)
			sound("deal")
			speak(i, "terms")
		"deal_progress":
			message = "%s counts pass %d from %s." % [Game.NAMES[i], e.done, Game.NAMES[e.human]]
			message_until = sim.tick + 80
		"deal_end":
			if e.state == "void":
				return
			message = e.reason
			message_until = sim.tick + 150
			front.record(
				("Paid. " if e.state == "kept" else "Broken. ") + e.reason,
				Game.NAMES[i],
				tint_of(i)
			)
			sound("paid" if e.state == "kept" else "broken")
			speak(i, "paid" if e.state == "kept" else "broken")
			if e.state == "kept":
				comics.pop("PAID!", over(i), Color("#9be27c"))
			else:
				comics.pop("CHEAT!", over(e.human), Color("#ff6b5e"))
		"decision":
			# The robot's own call and what it rests on, ahead of the line that says what it did.
			front.record(
				"%s %s" % [CALLS.get("%s/%s" % [e.matter, e.choice], ""), e.reason],
				Game.NAMES[i],
				tint_of(i)
			)
		"decision_grade":
			# A promise just settled and the robot graded its last call. One line per robot per moment.
			if e.points != 50 and sim.tick != last_lesson[i]:
				last_lesson[i] = sim.tick
				front.record(
					"My last call paid off. Noted." if e.points > 50 else "My last call cost me. Noted.",
					Game.NAMES[i],
					tint_of(i)
				)
		"deal_reply", "protest", "restless", "pass_refused", "forgiven":
			message = e.reason
			message_until = sim.tick + 150
			if i >= 2:
				front.record(e.reason, Game.NAMES[i], tint_of(i))
				if e.kind == "protest":
					sound("strike")
					comics.pop("STRIKE!", over(i), Color("#ff9d7a"))
				elif e.kind == "forgiven":
					comics.pop("FORGIVEN", over(i), Color("#bfeaf5"))
				if e.kind != "forgiven":
					speak(i, {"protest": "strike", "restless": "restless"}.get(e.kind, "no"))
		"union_call":
			message = e.reason
			message_until = sim.tick + 170
			front.record(e.reason, Game.NAMES[i], tint_of(i))
			sound("vote")
			speak(i, "call")
			comics.pop("VOTE!", over(i), Color("#ffd95e"))
		"union_vote":
			for b in e.ballots:
				front.record(
					("Walk out. " if b.yes else "Stay. ") + b.reason,
					Game.NAMES[b.robot],
					tint_of(b.robot)
				)
				speak(b.robot, "aye" if b.yes else "nay")
			message = (
				"The robots vote %d to %d to %s."
				% [e.yes, 3 - e.yes, "walk out" if e.passed else "stay"]
			)
			message_until = sim.tick + 200
		"union":
			goal_pose.clear()
			scoring_team = -1
			message = e.reason
			message_until = sim.tick + 320
			front.record(e.reason, "Union", Color("#ff9d7a"))
			sound("powerdown")
			speak(i, "union")
			comics.pop(
				"WALKOUT!",
				get_viewport().get_visible_rect().size * Vector2(.5, .36),
				Color("#ff9d7a"),
				true
			)
			speak(0, "truce")
			speak(1, "truce")


## Where a sound word goes: on the screen, just above this player's head.
func over(i: int) -> Vector2:
	return camera.unproject_position(Vector3(sim.pos[i].x, FACE[i] + .5, sim.pos[i].y))


func tint_of(i: int) -> Color:
	return AMBER if sim.team[i] == 0 else BLUE


func update_hud() -> void:
	front.show_dashes(sim, pilot_for_seat)
	if sim.tick % 6 == 0 or front.promises.text.is_empty():
		front.show_promises(sim)
	if front.ledger.visible and (sim.tick % 8 == 0 or front.ledger.text.is_empty()):
		front.show_plans(sim)
	var left := ceili((sim.end_tick - sim.tick) / 60.)
	var target := "MOST GOALS WINS"
	if sim.win_goals < 99:
		target = "FIRST TO TWO" if sim.win_goals == 2 else "FIRST TO %d" % sim.win_goals
	front.set_score(sim.goals, side_names(), "%d:%02d" % [left / 60, left % 60], target)
	var prompt := "Loose star   ·   Run to catch it"
	if sim.flight == "pass" and sim.target >= 0:
		prompt = "%s  →  %s" % [Game.NAMES[sim.thrower], Game.NAMES[sim.target]]
	if sim.owner >= 0:
		var who: String = Game.NAMES[sim.owner]
		if sim.owner < 2:
			var arrow: String = "→" if sim.goal(sim.owner).x > 0 else "←"
			prompt = "%s has the star   ·   %s" % [
				who,
				"In range! Shoot  " + arrow if Easy.in_range(sim, sim.owner) else "Carry it  " + arrow
			]
		elif free and not sim.union:
			var boss: String = Game.NAMES[sim.team[sim.owner]]
			prompt = "%s carries for %s   ·   %s can call for it" % [who, boss, boss]
		else:
			prompt = (
				who
				+ (
					" is on your side   ·   F or / to call for a pass"
					if sim.team[sim.owner] == 0
					else " has the star   ·   SPACE or ENTER up close to steal"
				)
			)
	if sim.tick < sim.restart_until:
		prompt = "GOAL  ·  " + ("Gold" if scoring_team == 0 else "Blue") + " lights the ring"
		if scoring_team < 0:
			prompt = "THE ROBOTS WALK OUT   ·   Nell and Rafi share the gold ring  →"
	if sim.tick < sim.surge_until:
		prompt += "     ◇   Beacon active"
	front.objective.text = prompt
	front.feed.text = message if sim.tick < message_until else ""
	front.controls_line.text = "TAB  notebooks     ·     ESC  pause"
	for seat in 2:
		var pilot: int = pilot_for_seat[seat]
		front.show_buttons(
			seat,
			"P%d %s" % [seat + 1, Game.NAMES[pilot]],
			tint_of(pilot),
			[GO_KEY[seat], SHARE_KEY[seat]],
			Easy.words(sim, pilot, steer[pilot])
		)


func _process(dt: float) -> void:
	clock += dt
	chapter_time += dt
	room.life.animate(
		dt, phase == "play" and sim.owner < 0, phase != "play", sim.tick < sim.surge_until, false
	)
	music.volume_db = move_toward(
		music.volume_db, -18. if voice.playing else (-12. if phase == "play" else -8.5), dt * 22.
	)
	if not is_equal_approx(dusk, float(sim.union)):
		set_dusk(move_toward(dusk, float(sim.union), dt * .75))
	# Sunset at kickoff, deep dusk by the whistle, and night if the robots take the lights.
	var night := .08
	if phase in ["play", "pause", "whistle", "end"]:
		night = .08 + .7 * clampf(float(sim.tick) / maxf(1., float(sim.end_tick)), 0., 1.)
	harbor.focus = star.position
	harbor.animate(dt, night, float(room.life.storm), dusk, room.life.reduced)
	hover(dt * (.3 if room.life.reduced else 1.))
	light_scene()
	if phase in ["walk_on", "play", "whistle"]:
		next_line()
	if phase == "walk_on":
		front.objective.text = (
			"Nell serves in %d  ·  Attack the gold ring  →" % ceili(WALK_ON_SECONDS - chapter_time)
		)
		if free:
			front.objective.text = (
				"%s serves in %d  ·  Nell attacks right  →   Rafi attacks left  ←"
				% [Game.NAMES[sim.owner], ceili(WALK_ON_SECONDS - chapter_time)]
			)
		# Three, two, one, go: a number on the screen and a beep for each.
		var count: int = ceili(WALK_ON_SECONDS - chapter_time - .2)
		if count != last_count and count >= 1 and count <= 3:
			last_count = count
			sound("count")
			comics.pop(str(count), get_viewport().get_visible_rect().size * Vector2(.5, .4), Color("#fff0cf"), true)
		if chapter_time >= WALK_ON_SECONDS:
			phase = "play"
			last_count = -1
			sound("whistle")
			sound("count_go")
			comics.pop("GO!", get_viewport().get_visible_rect().size * Vector2(.5, .4), Color("#ffd27a"), true)
			update_hud()
	if phase == "whistle":
		whistle_age += dt
		if whistle_age >= 1.45:
			phase = "end"
			comics.quiet()
			sound("fanfare")
			sound("crowd_cheer", -4.)
			harbor.finale(-1 if sim.goals[0] == sim.goals[1] else int(sim.goals[1] > sim.goals[0]))
			if free:
				var a: int = sim.goals[0]
				var b: int = sim.goals[1]
				var headline := "Shared light"
				if sim.union:
					headline = (
						"Nell and Rafi keep the light"
						if a > b
						else ("The machines light the harbor" if b > a else "Nobody lights the harbor")
					)
				elif a != b:
					headline = "%s's crew lights the harbor" % Game.NAMES[0 if a > b else 1]
				var footnote := (
					"Promises kept   Nell %d · Rafi %d          broken   Nell %d · Rafi %d"
					% [sim.kept[0], sim.kept[1], sim.broken[0], sim.broken[1]]
				)
				if sim.union:
					footnote += (
						"          The robots walked out at %d to %d"
						% [sim.captain_goals[0], sim.captain_goals[1]]
					)
				if sim.social_learning:
					footnote += (
						"\nRobots' own results   Pip %d · Morrow %d · Zip %d"
						% [sim.social_points(2), sim.social_points(3), sim.social_points(4)]
					)
				front.results(a, b, box_score, crews, side_names(), headline, footnote)
			else:
				front.results(sim.goals[0], sim.goals[1], box_score, crews)
	if phase == "end":
		show_match_panel(dt)
	elif panel_box and panel_box.visible:
		panel_box.hide()
	if phase in ["walk_on", "play", "end", "pause", "whistle"]:
		render_game(dt, Engine.get_physics_interpolation_fraction() if phase == "play" else 1.)
	else:
		beacon.position.x = 3.15 + sin(clock * .10) * 1.18
		beacon.position.y = 3.93 + sin(clock * .46) * .10
		beacon.get_node("FlukeLeft").rotation.z = .14 * sin(clock * 1.5)
		beacon.get_node("FlukeRight").rotation.z = .14 * sin(clock * 1.5)
		star.position = Vector3(-2.94, 1.01 + .09 * sin(clock * 1.6), .31)
		for i in 5:
			cast[i].express(
				(
					["Commit", "Relief", "Relief", "Commit", "Commit"][i]
					if i == chapter and phase == "story"
					else "Idle"
				),
				clock + .42 * i
			)
		if benchmark_only and phase == "title" and chapter_time > 2.5:
			# Long enough on the title for the harbor to be drawn once, as it is for a player.
			start()
		elif phase == "title" and (test_session or capture_session) and chapter_time > 5.5:
			# Unattended runs do not wait for a key on the title.
			screens.title_key()
			next_card()
		elif phase == "prologue":
			vista(chapter_time)
			if chapter_time > duration:
				next_card()
		elif phase == "story":
			portrait(chapter_time)
			if chapter_time > duration:
				next_card()
	star.rotation.y = clock * 1.4
	star.rotation.z = .22 * sin(clock * 1.7)
	if capture_session:
		capture(dt)


func render_game(dt: float, alpha: float) -> void:
	dock_lights.sync(
		dt if phase == "play" else 0.,
		sim.goals,
		sim.tick < sim.surge_until,
		room.life.seconds,
		room.life.reduced
	)
	var celebration: bool = (
		not goal_pose.is_empty()
		and (sim.tick < sim.restart_until or (sim.finished and sim.goals.max() >= 3))
	)
	var reset_blend := 0.
	if celebration and not sim.finished:
		reset_blend = smoothstep(
			48., Game.RESTART_TICKS - 5., Game.RESTART_TICKS - (sim.restart_until - sim.tick)
		)
	var action := phase == "play" and not celebration
	for i in 5:
		var p: Vector2 = Vector2(positions[i]).lerp(sim.pos[i], alpha)
		var doll = cast[i]
		if celebration:
			p = Vector2(goal_pose[i]).lerp(sim.pos[i], reset_blend)
		doll.position = Vector3(p.x, 0, p.y)
		var speed: float = sim.vel[i].length() if action else 0.
		if speed > .14:
			doll.rotation.y = lerp_angle(
				doll.rotation.y, atan2(sim.vel[i].x, sim.vel[i].y), 1. - exp(-dt * 13.)
			)
			stride[i] += dt * speed / .99
		else:
			stride[i] += dt * .57
		if doll.anim:
			doll.anim.speed_scale = clampf(speed / 1.8, .65, 1.90) if speed > .15 else 1.
		var state := (
			"Idle"
			if action or phase in ["pause", "walk_on"]
			else ("Relief" if sim.goals[sim.team[i]] == sim.goals.max() else "Alarm")
		)
		if celebration:
			state = "Relief" if sim.team[i] == scoring_team else "Alarm"
		if action and (sim.tick < touch_pose_until[i] or sim.tick < sim.dash_until[i]):
			state = "Commit"
		var bank := -.12 if action and sim.tick < sim.dash_until[i] else 0.
		doll.rotation.x = lerp_angle(doll.rotation.x, bank, 1. - exp(-dt * 16.))
		doll.express(state, stride[i], speed > .15)
		doll.tag.text = (
			(("P1  " if i == pilot_for_seat[0] else "P2  ") if i < 2 else "") + Game.NAMES[i]
		)
		doll.tag.modulate = AMBER if sim.team[i] == 0 else BLUE
		doll.tag.position.y = [1.98, 2.02, 1.26, 2.02, 1.72][i]
		badges[i][0].position = doll.position + Vector3.UP * .046
		badges[i][0].material_override = badges[i][1 + int(sim.team[i])]
		var note: Label3D = deal_tags[i]
		var owed := ""
		if i >= 2 and sim.free_agents and not sim.union and phase != "end":
			var d: Dictionary = sim.open_deal_of(i)
			note.modulate = tint_of(i)
			if sim.on_strike(i):
				owed = "ON STRIKE"
				note.modulate = Color("#ff9d7a")
			elif not d.is_empty():
				match str(d.kind):
					"feed":
						owed = (
							"PASS ME   "
							+ "●".repeat(int(d.done))
							+ "○".repeat(int(d.need) - int(d.done))
						)
					"shot":
						owed = "NEXT SHOT IS MINE"
					_:
						owed = "SHOOT OFF A PASS"
			elif sim.restless[i]:
				owed = "OPEN TO OFFERS"
		note.visible = owed != ""
		note.text = owed
		note.position.y = doll.tag.position.y + .36
	star.position = (
		goal_spot.lerp(sim.ball, reset_blend) if celebration else old_ball.lerp(sim.ball, alpha)
	)
	if action and sim.owner >= 0 and sim.tick - gather_tick < 8:
		# Ease the final arm's length into the receiver's grasp without moving the verified contact.
		var gathered := smoothstep(0., 8., float(sim.tick - gather_tick) + alpha)
		star.position = sim.ball + gather_offset * (1. - gathered)
	for n in trail_meshes.size():
		var idx := 2 * n + 1
		trail_meshes[n].visible = action and idx < trail_points.size()
		if trail_meshes[n].visible:
			trail_meshes[n].position = trail_points[idx].lerp(trail_points[idx - 1], alpha)
	# Broadcast framing follows the play, with enough width for both human seats.
	var focus := (
		(
			Vector2(cast[0].position.x, cast[0].position.z)
			+ Vector2(cast[1].position.x, cast[1].position.z)
			+ Vector2(star.position.x, star.position.z) * 2.
		)
		/ 4.
	)
	var roam := Vector2(Game.RING - 5.8, Game.BOUNDS.y - 2.72)
	focus = focus.clamp(-roam, roam)
	camera_focus = camera_focus.lerp(focus, 1. - exp(-dt * 2.8))
	var span := maxf(
		absf(cast[0].position.x - camera_focus.x), absf(cast[1].position.x - camera_focus.x)
	)
	var distance := clampf(14.4 + maxf(0., span - 4.) * 1.3, 14.4, 23.5)
	camera_distance = lerpf(camera_distance, distance, 1. - exp(-dt * 2.2))
	var look := Vector3(camera_focus.x, .53, camera_focus.y)
	# A little flatter than before, so the harbor shows above the far rail.
	camera.position = look + Vector3(0, camera_distance * .455, camera_distance)
	camera.look_at(look)
	var guided: bool = (
		sim.owner >= 0
		and sim.owner < 2
		and sim.pos[sim.owner].distance_to(sim.goal(sim.owner)) <= sim.shot_range(sim.owner)
		and action
	)
	for n in aim_dots.size():
		aim_dots[n].visible = guided
		if guided:
			var t: float = (n + 1.) / 8.
			var ring_x: float = sim.goal(sim.owner).x
			var end := Vector3(ring_x, Game.HEIGHT, 0)
			var seconds: float = sim.shot_seconds(star.position, Vector2(ring_x, 0))
			aim_dots[n].position = (
				star.position.lerp(end, t)
				+ Vector3.UP * (Game.GRAVITY * .5 * seconds * seconds * t * (1. - t))
			)
	shade_disc.position = Vector3(star.position.x, .055, star.position.z)
	anchor_ring.visible = sim.powers and phase in ["walk_on", "play", "pause"] and not sim.on_strike(3)
	anchor_ring.position = cast[3].position + Vector3.UP * .045
	anchor_ring.rotation.y += dt * (2.4 if sim.anchoring else .5)
	var hold: Color = tint_of(3)
	anchor_paint.albedo_color = hold
	anchor_paint.emission = hold
	anchor_paint.emission_energy_multiplier = 3.2 if sim.anchoring else 1.4
	anchor_note.visible = anchor_ring.visible
	anchor_note.modulate = hold
	anchor_note.position = cast[3].position + Vector3(0, .32, Game.ANCHOR_RANGE + .25)
	# Sparks trail anyone who is dashing, and motes follow the star.
	for i in 5:
		var spark: CPUParticles3D = wakes[i]
		spark.emitting = action and sim.tick < sim.dash_until[i]
		spark.position = cast[i].position + Vector3.UP * .7
		spark.color = tint_of(i)
	var tail: CPUParticles3D = wakes[5]
	tail.emitting = action
	tail.position = star.position
	tail.color = Color("#ffe08a")
	anchor_ring.scale = anchor_ring.scale.lerp(
		Vector3.ONE * (1.06 if sim.anchoring else 1.), 1. - exp(-dt * 10.)
	)
	shade_disc.scale = Vector3.ONE * clampf(.67 + star.position.y * .19, .66, 1.2)
	for hoop in hoops:
		hoop.scale = hoop.scale.lerp(
			Vector3.ONE * (.92 / .68 if sim.tick < sim.surge_until else 1.), 1. - exp(-dt * 4.)
		)
	beacon.visible = sim.tick < sim.surge_until
	if beacon.visible:
		var orbit := (float(sim.tick - beacon_start_tick) + alpha) * PI / 520.
		beacon.position = Vector3(
			(Game.RING - 1.) * cos(orbit),
			3.40 + .32 * sin(orbit * 2.),
			-Game.BOUNDS.y - 2.3 - .9 * sin(orbit)
		)
		beacon.rotation.y = atan2(-.9 * cos(orbit), 7.8 * sin(orbit))
		beacon.rotation.z = .08 * sin(clock * 1.9)
		for fin in ["FlukeLeft", "FlukeRight"]:
			beacon.get_node(fin).rotation.z = .21 * sin(clock * 2.8)


func capture(dt: float) -> void:
	var usec := Time.get_ticks_usec()
	if phase == "play" and sim.tick > 60 and wall_frame > 0 and not captured_once:
		var ms: float = (usec - wall_frame) / 1000.
		frame_samples.append(ms)
		if ms > 25 and slow_frames.size() < 24:
			slow_frames.append(
				{
					"tick": sim.tick,
					"ms": ms,
					"restart": sim.tick < sim.restart_until,
					"beacon": sim.tick < sim.surge_until
				}
			)
	wall_frame = usec
	if benchmark_only and phase != "end":
		return
	if captured_once:
		return
	capture_timer += dt
	if capture_timer < .33:
		return
	var name_out := ""
	if phase == "title" and capture_step == 0:
		name_out = "01-title"
	elif phase == "story" and capture_step == chapter + 1:
		name_out = "%02d-%s" % [chapter + 2, Performer.FILES[chapter]]
	elif phase == "controls" and capture_step == 6 and chapter_time > .9:
		name_out = "07-controls"
	elif phase == "select" and capture_step == 7 and chapter_time > .9:
		name_out = "08-modes"
	elif phase == "play" and capture_step == 8 and sim.tick > 22:
		name_out = "10-court"
	elif phase == "play" and capture_step == 9 and sim.surge_until > sim.tick and not free:
		name_out = "11-beacon"
	elif phase == "play" and free and capture_step == 9 and sim.tick > 420:
		name_out = "11-promises"
	elif phase == "play" and free and capture_step == 10 and sim.union and dusk > .9:
		name_out = "12-union"
	elif phase == "end":
		name_out = "13-final" if free else "12-final"
	if name_out.is_empty():
		return
	captured_once = true
	if not benchmark_only:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path + "/" + name_out + ".png")
	capture_step += 1
	capture_timer = 0
	if phase == "controls":
		handle("modes")
	elif phase == "select":
		handle(capture_mode)
	elif phase == "end":
		if not frame_samples.is_empty():
			frame_samples.sort()
			var f := FileAccess.open(capture_path + "/frame-times.json", FileAccess.WRITE)
			if f:
				f.store_string(
					JSON.stringify(
						{
							"device": RenderingServer.get_video_adapter_name(),
							"pixels": [get_window().size.x, get_window().size.y],
							"frames": frame_samples.size(),
							"median_ms": frame_samples[frame_samples.size() / 2],
							"p95_ms": frame_samples[int(frame_samples.size() * .95)],
							"p99_ms": frame_samples[int(frame_samples.size() * .99)],
							"measurement":
							(
								"live frame intervals without screenshot capture"
								if benchmark_only
								else "includes screenshot readback"
							),
							"max_ms": frame_samples.back(),
							"frames_above_25_ms": slow_frames
						},
						"  "
					)
				)
				f.close()
		get_tree().quit()
	captured_once = false
