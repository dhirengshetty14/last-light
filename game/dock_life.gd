extends Node3D
## Ambient motion is presentation only. FlightSim never reads this node.

var trolley := Node3D.new()
var sling := Node3D.new()
var freight := Node3D.new()
var tugs: Array[Node3D] = []
var hatch_leaves: Array[Node3D] = []
var rail_signal: StandardMaterial3D
var plate: ShaderMaterial
var seconds := 0.0
var quiet := 1.0
var hatch_fraction := 0.0
var gravity_fraction := 0.0
var reduced := false
var ice := MultiMeshInstance3D.new()
var storm := false


func build(stage, backdrop: ShaderMaterial) -> void:
	plate = backdrop
	var gunmetal: Material = stage.mats.iron
	var brass: Material = stage.mats.brass
	var container: Material = stage.metal("freight enamel", "#776653", 0.67, 0.32)
	var fog_steel: Material = stage.metal("distant hulls", "#516273", 0.71, 0.18)
	var running_light: Material = stage.metal("navigation lights", "#c6a882", 0.48, 0.1, 0.36)
	# The far gantry occupies the right gallery, beyond the three player lanes.
	stage.tube(self, Vector3(5.2, 4.74, -6.3), Vector3(11.52, 4.74, -6.3), 0.052, gunmetal)
	add_child(trolley)
	stage.box(trolley, Vector3.ZERO, Vector3(0.54, 0.19, 0.33), gunmetal)
	stage.box(trolley, Vector3(0.02, -0.06, 0.18), Vector3(0.19, 0.042, 0.024), running_light)
	trolley.add_child(sling)
	for side in [-1, 1]:
		stage.tube(sling, Vector3(side * 0.17, 0, 0), Vector3(side * 0.23, -1, 0), 0.012, brass)
	trolley.add_child(freight)
	stage.box(freight, Vector3(0, -0.22, 0), Vector3(0.73, 0.43, 0.45), container)
	for side in [-1, 1]:
		stage.box(freight, Vector3(side * 0.24, -0.22, 0), Vector3(0.045, 0.47, 0.48), gunmetal)
		stage.box(freight, Vector3(side * 0.325, -0.22, 0.241), Vector3(0.032, 0.35, 0.015), brass)
	# Two tenders at different depths cross the upper gallery at different times.
	for i in 2:
		var tug := Node3D.new()
		tug.name = "RingTender%d" % i
		add_child(tug)
		stage.ball(tug, Vector3.ZERO, Vector3(0.69, 0.14, 0.18), fog_steel)
		stage.box(tug, Vector3(-0.06, 0.16, 0), Vector3(0.34, 0.12, 0.19), fog_steel)
		for side in [-1, 1]:
			stage.box(tug, Vector3(-0.37, -0.02, side * 0.20), Vector3(0.35, 0.10, 0.12), gunmetal)
		stage.box(tug, Vector3(0.12, 0.13, 0.10), Vector3(0.15, 0.042, 0.035), running_light)
		tugs.append(tug)
	# Physical shutters open outwards behind HATCH. Amber means closed, green means aligned.
	rail_signal = stage.metal("hatch pilot", "#b88a4b", 0.49, 0.22, 0.55)
	for side in [-1, 1]:
		var leaf := Node3D.new()
		add_child(leaf)
		stage.box(leaf, Vector3(0, 0.82, 0), Vector3(0.53, 0.76, 0.10), gunmetal)
		for j in 4:
			stage.box(leaf, Vector3(0, 0.56 + j * 0.16, 0.06), Vector3(0.48, 0.046, 0.052), brass)
		stage.box(leaf, Vector3(side * 0.17, 1.29, 0), Vector3(0.09, 0.15, 0.09), rail_signal)
		hatch_leaves.append(leaf)
	var crystal := SphereMesh.new()
	crystal.radius = 1.0
	crystal.height = 2.0
	crystal.radial_segments = 5
	crystal.rings = 2
	var ice_material: Material = stage.metal("ring ice", "#829ba9", .54, .09)
	var cluster := MultiMesh.new()
	cluster.transform_format = MultiMesh.TRANSFORM_3D
	cluster.mesh = crystal
	cluster.instance_count = 11
	ice.multimesh = cluster
	ice.material_override = ice_material
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ice.name = "Outer ring drift"
	add_child(ice)
	ice.hide()
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func update(dt: float, sim, tutorial: bool) -> void:
	# Fade motion speed during final approach and during induction. Integrating the clock avoids a jump.
	var reading_catch: bool = (
		not sim.dwell.is_empty() or (not sim.flight.is_empty() and sim.flight.end - sim.tick <= 100)
	)
	var target := 0.36 if reading_catch or tutorial else 1.0
	quiet = move_toward(quiet, target, dt * 0.95)
	if not reduced:
		seconds += dt * quiet
	plate.set_shader_parameter("seconds", seconds)
	plate.set_shader_parameter("strength", 0.0 if reduced else 1.0)
	# Cosine endpoints let the crane stop, lower its load, and reverse without teleporting.
	var trip := (1.0 - cos(seconds * TAU / 32.0 + 0.85)) * 0.5
	var cable := 0.52 + 0.62 * pow(absf(2.0 * trip - 1.0), 5.0)
	trolley.position = Vector3(lerpf(5.35, 10.85, trip), 4.69, -6.3)
	sling.scale.y = cable
	freight.position.y = -cable
	freight.rotation.z = 0.026 * sin(seconds * TAU / 32.0 + 0.85)
	for i in tugs.size():
		var phase := fposmod(seconds / (42.0 + i * 15.0) + 0.34 + i * 0.45, 1.0)
		var travel := smoothstep(0.08, 0.90, phase)
		var tug := tugs[i]
		# The return happens behind the ring station between visible passes.
		tug.visible = phase >= 0.08 and phase <= 0.90
		tug.position = Vector3(
			lerpf(22.0, 4.8, travel) + i * 3.8, 6.3 - travel * 1.8 + i * 0.85, -18.0 - i * 4.0
		)
		tug.scale = (
			Vector3.ONE
			* (1.0 - 0.45 * travel)
			* smoothstep(0.08, 0.15, phase)
			* (1.0 - smoothstep(0.81, 0.90, phase))
		)
	ice.visible = storm
	if storm:
		for n in ice.multimesh.instance_count:
			var arc := fposmod(seconds / (37.0 + n) + float(n) * .618034, 1.0)
			var size := .055 + .025 * float(n % 4)
			var fade := smoothstep(0.0, .13, arc) * (1.0 - smoothstep(.82, 1.0, arc))
			var basis := Basis(Vector3(.31, .79, .33).normalized(), float(n) + seconds * .12)
			basis = basis.scaled(Vector3(1.6, .68, 1.0) * size * maxf(.001, fade))
			var at := Vector3(
				8.5 + 7.5 * arc, 3.6 + 1.4 * arc + .23 * sin(float(n) * 3.7), -11.0 - n % 3
			)
			ice.multimesh.set_instance_transform(n, Transform3D(basis, at))
	var open: bool = sim.hatch_open(sim.tick) and not tutorial
	hatch_fraction = move_toward(hatch_fraction, 1.0 if open else 0.0, dt * 0.78)
	gravity_fraction = move_toward(gravity_fraction, 1.0 if sim.gravity == 1 else 0.0, dt * 1.3)
	for index in hatch_leaves.size():
		var side := -1.0 if index == 0 else 1.0
		hatch_leaves[index].position = Vector3(
			4.30 + side * (0.30 + smoothstep(0.0, 1.0, hatch_fraction) * 0.71), 0, -2.84
		)
	var signal_color := Color("#b88a4b").lerp(Color("#86bdad"), hatch_fraction)
	rail_signal.albedo_color = signal_color
	rail_signal.emission = signal_color
	rail_signal.emission_energy_multiplier = 0.46 + 0.48 * gravity_fraction
