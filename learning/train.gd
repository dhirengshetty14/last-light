extends SceneTree
const Sim = preload("res://game/flight_sim.gd")
const Policy = preload("res://learning/response_policy.gd")


func _initialize() -> void:
	var learner = Policy.new()
	learner.exploration = .25
	var runs := 100
	var params := OS.get_cmdline_user_args()
	if not params.is_empty():
		runs = clampi(int(params[0]), 1, 5000)
	var samples := 0
	for n in runs:
		var sim = Sim.new(900 + n, false, n % 2)
		sim.policy = learner
		while sim.ending == "":
			if n % 3 != 0:
				drive_partner(sim, 0, n)
				drive_partner(sim, 1, n + 1)
			sim.step()
		for g in sim.grades:
			if g.type == "response":
				samples += 1
	var out := FileAccess.open("res://learning/checkpoint.json", FileAccess.WRITE)
	out.store_string(
		(
			JSON.stringify(
				{
					"schema": "response-policy-v1",
					"seeds": [900, 899 + runs],
					"responses": samples,
					"estimates": learner.estimates
				},
				"  "
			)
			+ "\n"
		)
	)
	out.close()
	print(
		"Training flights ",
		runs,
		" | verified responses ",
		samples,
		" | policy entries ",
		learner.estimates.size()
	)
	quit()


static func drive_partner(sim, who: int, style: int) -> void:
	if sim.tick % 30 == 0:
		var z: int = 1 if sim.phase == 0 else 2
		var p: Vector2i = sim.seats[who].pos
		var d: Vector2i = sim.PADS[z] - p
		sim.input_move(
			who, Vector2i(signi(d.x) if absi(d.x) > 70 else 0, signi(d.y) if absi(d.y) > 60 else 0)
		)
		if sim.near(who, z):
			if sim.seats[who].vote != z:
				sim.human_action(who, "vote")
			elif style % 3 == 0:
				sim.human_action(who, "cover")
		var id: int = sim.social.incoming(who)
		if id >= 0:
			var o: Dictionary = sim.social.offers[id]
			if o.status == "offered":
				sim.human_action(who, "agree")
			elif o.status == "accepted" and style % 2 == 0 and sim.tick - o.accepted >= 35:
				sim.human_action(who, "break")
