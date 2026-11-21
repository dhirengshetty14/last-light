extends RefCounted
## Guided cargo trajectory in centimetres. Fixed-point time preserves position when a towline changes speed.
const ONE := 65536
const RAILS := [Vector3i(-430, 120, 30), Vector3i(0, 120, -155), Vector3i(430, 120, 30)]


static func progress(c: Dictionary, now: int) -> int:
	var span := maxi(1, int(c.end) - int(c.anchor_tick))
	var elapsed := clampi(now - int(c.anchor_tick), 0, span)
	return int(c.anchor_u) + int((ONE - int(c.anchor_u)) * elapsed / span)


static func advance(c: Dictionary, now: int) -> void:
	var u := progress(c, now)
	var a: Vector3i = RAILS[c.from]
	var b: Vector3i = RAILS[c.to]
	# Constant acceleration along the launch arch. The kickplate bends the lateral component after contact.
	var arch := int(4 * 225 * u * (ONE - u) / (ONE * ONE))
	var next := Vector3i(
		a.x + int((b.x - a.x) * u / ONE), a.y + arch, a.z + int((b.z - a.z) * u / ONE)
	)
	var drift: Vector2i = c.get("drift", Vector2i.ZERO)
	var wake := clampi((u - ONE / 3) * 3 / 2, 0, ONE)
	next.x += int(drift.x * wake / ONE)
	next.z += int(drift.y * wake / ONE)
	if c.banked:
		var v := clampi(int((u - int(c.bank_u)) * ONE / maxi(1, ONE - int(c.bank_u))), 0, ONE)
		next.z += int(4 * 48 * v * (ONE - v) / (ONE * ONE))
	c.velocity = next - Vector3i(c.pos)
	c.pos = next
	c.u = u


static func slow(c: Dictionary, now: int, ticks: int) -> void:
	c.anchor_u = progress(c, now)
	c.anchor_tick = now
	c.end += ticks
	c.slow = true
