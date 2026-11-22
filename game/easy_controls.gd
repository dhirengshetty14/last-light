extends RefCounted
## Two buttons do everything. GO shoots when you are in range and dashes or steals otherwise.
## SHARE passes, calls for the star, or makes a robot an offer. This file turns each press into the
## court's own verb from what is happening at that moment, and says in words what a press will do.
##
## The court never sees these two buttons, only the verb, so recordings replay the same as before.


## The robot this captain owes a promise to, or -1.
static func owed(sim, i: int) -> int:
	if not sim.free_agents or sim.union:
		return -1
	for d in sim.deals:
		if d.state == "open" and d.human == i and sim.team[d.robot] == sim.team[i]:
			return int(d.robot)
	return -1


## The robot close enough to hear an offer, or -1.
static func beside(sim, i: int) -> int:
	var best := -1
	var reach := 1.95
	for k in range(2, 5):
		var d: float = sim.pos[k].distance_to(sim.pos[i])
		if d < reach:
			reach = d
			best = k
	return best


static func in_range(sim, i: int) -> bool:
	return sim.owner == i and sim.pos[i].distance_to(sim.goal(i)) <= sim.shot_range(i)


static func bidding(sim) -> bool:
	return sim.free_agents and not sim.union


## Who a pass would go to right now, or -1.
static func receiver(sim, i: int, stick: Vector2) -> int:
	if sim.owner != i:
		return -1
	var promised := owed(sim, i)
	if promised >= 0:
		return promised
	return sim.aimed(i, stick)


static func go(sim, i: int) -> String:
	return "shoot" if in_range(sim, i) else "dash"


static func share(sim, i: int, stick: Vector2) -> String:
	if sim.owner == i:
		if owed(sim, i) >= 0:
			return "ally_pass"
		# Outside Free Agents the court has one verb for the other pilot and one for a robot.
		if not bidding(sim) and receiver(sim, i, stick) >= 2:
			return "ally_pass"
		return "pass"
	if sim.owner >= 2 and sim.team[sim.owner] == sim.team[i]:
		return "pass"
	if bidding(sim) or sim.open_crews:
		return "invite"
	return "pass"


## What each button will do if pressed now, in two or three words.
static func words(sim, i: int, stick: Vector2) -> Array:
	var names: Array = sim.NAMES
	var act := "Dash"
	if in_range(sim, i):
		act = "Shoot!"
	elif sim.owner >= 0 and sim.team[sim.owner] != sim.team[i]:
		act = "Steal"
	var give := ""
	if sim.owner == i:
		var to := receiver(sim, i, stick)
		if to >= 0:
			give = "Pass to %s" % names[to]
			if to == owed(sim, i):
				give = "Pay %s" % names[to]
	elif sim.owner >= 2 and sim.team[sim.owner] == sim.team[i]:
		give = "Call %s" % names[sim.owner]
	elif bidding(sim) or sim.open_crews:
		var robot := beside(sim, i)
		if robot >= 0 and sim.open_crews:
			give = "Recruit %s" % names[robot]
		elif robot >= 0 and sim.open_deal_of(robot).is_empty():
			# A robot with a promise still open is not listening to offers.
			if sim.team[robot] == sim.team[i]:
				give = "New terms for %s" % names[robot]
			elif sim.crew_robots(sim.team[robot]) > 1:
				give = "Sign %s" % names[robot]
	return [act, give]
