extends SceneTree
const Game = preload("res://game/star_match.gd")


func trial(cfg: Dictionary, k: int) -> int:
	var s = Game.new()
	s.setup(k * 113 + 17, false)
	s.pos[0] = Vector2(Game.RING - 3.62 + k * .063, (-1. if k % 2 else 1.) * (1.25 + k * .06))
	s.pos[2] = Vector2(Game.RING - 4.85, -.30)
	s.pos[3] = Vector2(Game.RING - 2.08, -signf(s.pos[0].y) * 1.72)
	s.pos[4] = Vector2(Game.RING - 5.18, signf(s.pos[0].y) * 1.15)
	s.ball = s.hand(0)
	while s.tick < 160:
		var c: Dictionary = {
			"move": Vector2(s.pos[0]).direction_to(s.goal(0)),
			"shoot": s.owner == 0 and s.pos[0].distance_to(s.goal(0)) * 100 <= int(cfg.shoot_cm),
			"dash": s.tick == int(cfg.dash_tick)
		}
		s.step([c, {}])
		for e in s.events:
			if e.kind == "action_grade" and e.type == "court_throw" and e.seat == 0:
				return int(e.points)
			if e.kind == "custody" and e.method == "steal" and e.seat >= 2:
				return 0
		s.events.clear()
	return 0


func bounded(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(v) and floor(v) == v and v >= lo and v <= hi


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var f := FileAccess.open(args[0], FileAccess.READ) if FileAccess.file_exists(args[0]) else null
	var cfg: Variant = JSON.parse_string(f.get_as_text()) if f and f.get_length() < 1024 else null
	var points := 0
	if (
		cfg is Dictionary
		and cfg.size() == 2
		and bounded(cfg.get("shoot_cm"), 80, 500)
		and bounded(cfg.get("dash_tick"), 0, 120)
	):
		for k in 5:
			points += trial(cfg, k)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	if not out:
		quit(2)
		return
	out.store_line(JSON.stringify({"score": points / 500., "all_pass": int(points == 500)}))
	out.close()
	quit()
