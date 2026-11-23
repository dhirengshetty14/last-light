extends RefCounted
## Scripted captains for Free Agents fixtures and training. An honest captain pays what was
## promised before playing for the score. The other kind plays for themselves. `crewed` adds the
## habits in between, which is what the robots practise against.
const Game = preload("res://game/star_match.gd")


static func inputs(s, honest: Array) -> Array:
	return [captain(s, 0, honest[0]), captain(s, 1, honest[1])]


## A captain's habit with promises. Robots never see this, only what the captain does.
##   honest     always pays
##   liar       never pays
##   late       pays through the first half, then plays for themselves
##   reformed   cheats until one broken promise, then pays
##   favourite  pays one robot and no other
##   coin       pays some promises and not others
static func pays(s, i: int, style: Dictionary) -> bool:
	match str(style.get("kind", "honest")):
		"liar":
			return false
		"late":
			return s.tick * 100 < s.end_tick * 55
		"reformed":
			return s.broken[i] >= 1
		"favourite", "coin":
			for d in s.deals:
				if d.state == "open" and d.human == i and s.team[d.robot] == s.team[i]:
					if style.kind == "favourite":
						return int(d.robot) == int(style.get("robot", 2))
					var roll := (int(d.id) * 7919 + int(style.get("salt", 0))) % 100
					return roll < int(style.get("percent", 50))
	return true


## What a verifier may use and a robot may not: how likely this captain is to pay the next promise
## it makes to this robot, from 0 to 1.
static func faith(s, i: int, style: Dictionary, robot: int) -> float:
	match str(style.get("kind", "honest")):
		"liar":
			return 0.
		"late":
			# A promise made close to the turn runs out after it.
			return 1. if s.tick * 100 < s.end_tick * 45 else 0.
		"reformed":
			return 1. if s.broken[i] >= 1 else 0.
		"favourite":
			return 1. if robot == int(style.get("robot", 2)) else 0.
		"coin":
			return int(style.get("percent", 50)) / 100.
	return 1.


static func sample(rng: RandomNumberGenerator, kinds: Array) -> Dictionary:
	return {
		"kind": kinds[rng.randi() % kinds.size()],
		"robot": 2 + rng.randi() % 3,
		"salt": rng.randi() % 1000,
		"percent": 50,
		"poach": rng.randf() < .6,
		"lure": rng.randf() < .5
	}


## Both captains for one tick, each with its own habit. A captain without the star may walk over
## to a rival's robot that is open to offers and ask it to switch. One who is not paying may still
## go back to a robot on strike and ask it to sign again.
static func crewed(s, styles: Array) -> Array:
	var paying := [pays(s, 0, styles[0]), pays(s, 1, styles[1])]
	var c: Array = inputs(s, paying)
	if s.union:
		return c
	for i in 2:
		if s.owner == i:
			continue
		var want := -1
		for k in range(2, 5):
			if (
				styles[i].get("lure", false)
				and not paying[i]
				and s.team[k] == s.team[i]
				and s.on_strike(k)
			):
				want = k
				break
			if (
				styles[i].get("poach", false)
				and s.team[k] != s.team[i]
				and s.restless[k]
				and s.crew_robots(s.team[k]) > 1
			):
				want = k
				break
		if want >= 0:
			var to: Vector2 = Vector2(s.pos[want]) - Vector2(s.pos[i])
			c[i]["move"] = to.normalized() if to.length() > 1.2 else Vector2.ZERO
			c[i]["invite"] = to.length() < 1.7 and s.tick % 20 == 0
			c[i]["dash"] = false
	return c


static func captain(s, i: int, honest: bool) -> Dictionary:
	var c := {}
	var p: Vector2 = s.pos[i]
	var dest: Vector2 = s.floor_ball()
	var ring: Vector2 = s.goal(i)
	var reach: float = p.distance_to(ring)
	var in_range: bool = reach <= s.shot_range(i) - .12
	var owed := {}
	if honest and not s.union:
		for d in s.deals:
			if d.state == "open" and d.human == i and s.team[d.robot] == s.team[i]:
				owed = d
				break
	if s.owner == i:
		dest = ring
		var shoot := in_range
		if not owed.is_empty():
			var gap: float = p.distance_to(s.pos[owed.robot])
			var clear: bool = gap > 1.2 and gap < 7.5 and s.tick % 10 == 0
			match str(owed.kind):
				"feed":
					c["ally_pass"] = clear
				"shot":
					shoot = false
					c["ally_pass"] = clear and reach < Game.SHOT_RANGE + 3.2
					if in_range:
						dest = p
				_:
					shoot = in_range and s.fed[i]
					c["ally_pass"] = clear and not s.fed[i] and reach < Game.SHOT_RANGE + 2.6
					if in_range and not s.fed[i]:
						dest = p
		elif s.union and not in_range:
			c["pass"] = s.tick % 49 == i
		c["shoot"] = shoot
		# Dash when a defender closes in, the way a person would, not on a timer.
		var threat := INF
		for j in 5:
			if s.team[j] != s.team[i]:
				threat = minf(threat, p.distance_to(s.pos[j]))
		c["dash"] = not in_range and threat < 1.5
	elif s.owner >= 0 and s.team[s.owner] == s.team[i]:
		var holder: Vector2 = s.pos[s.owner]
		dest = Vector2(
			clampf(holder.x + signf(ring.x) * 2.6, -Game.BOUNDS.x + .5, Game.BOUNDS.x - .5),
			2.2 if holder.y < 0 else -2.2
		)
		if not owed.is_empty() and s.owner >= 2 and s.tick % 30 == 0:
			# Ask for it back to finish a run of passes, or to shoot off a pass as promised.
			if owed.kind == "feed" and s.owner == owed.robot:
				c["pass"] = true
			elif owed.kind == "assist" and reach < Game.SHOT_RANGE + .8:
				c["pass"] = true
	elif s.owner < 0 and s.target == i:
		dest = s.reception_point
	elif s.owner >= 0:
		dest = Vector2(s.pos[s.owner]) + Vector2(s.vel[s.owner]) * .15
		c["dash"] = p.distance_to(s.pos[s.owner]) < .8
	if honest and not s.union:
		# A robot that downed tools gets new terms before anything else.
		for j in range(2, 5):
			if s.team[j] == s.team[i] and s.on_strike(j):
				dest = s.pos[j]
				c["invite"] = p.distance_to(dest) < 1.7 and s.tick % 20 == 0
				break
	c["move"] = p.direction_to(dest) if p.distance_to(dest) > .14 else Vector2.ZERO
	return c
