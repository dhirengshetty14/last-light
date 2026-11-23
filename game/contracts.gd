extends RefCounted
## Escrow and partner-specific memory. A promise binds one provider to one physical duty.

var balance := [2, 2, 2, 2, 2]
var trust: Array = []
var offers: Dictionary = {}
var next_id := 0
var memories: Array = []


func _init() -> void:
	for seat in 5:
		trust.append([0, 0, 0, 0, 0])


func propose(buyer: int, provider: int, duty: String, zone: int, now: int) -> int:
	if (
		buyer == provider
		or buyer < 0
		or provider < 0
		or buyer >= 5
		or provider >= 5
		or balance[buyer] < 1
	):
		return -1
	for offer in offers.values():
		if offer.buyer == buyer or offer.provider == provider:
			return -1
	next_id += 1
	balance[buyer] -= 1
	offers[next_id] = {
		"id": next_id,
		"buyer": buyer,
		"provider": provider,
		"duty": duty,
		"zone": zone,
		"price": 1,
		"status": "offered",
		"deadline": now + 390,
		"accepted": -1
	}
	return next_id


func incoming(seat: int) -> int:
	for id in offers:
		if offers[id].provider == seat:
			return id
	return -1


func counter(id: int, seat: int) -> bool:
	if not offers.has(id):
		return false
	var o: Dictionary = offers[id]
	if o.provider != seat or o.status != "offered" or balance[o.buyer] < 1:
		return false
	balance[o.buyer] -= 1
	o.price = 2
	o.status = "counter"
	return true


func accept(id: int, seat: int, now: int) -> bool:
	if not offers.has(id):
		return false
	var o: Dictionary = offers[id]
	if not (
		(o.status == "offered" and seat == o.provider)
		or (o.status == "counter" and seat == o.buyer)
	):
		return false
	o.status = "accepted"
	o.accepted = now
	o.deadline = now + 540
	return true


func close(id: int, outcome: String, now: int) -> Dictionary:
	if not offers.has(id):
		return {}
	var o: Dictionary = offers[id]
	if outcome == "kept" and o.status != "accepted":
		return {}
	if outcome == "broken" and o.status != "accepted":
		return {}
	offers.erase(id)
	balance[o.provider if outcome == "kept" else o.buyer] += o.price
	o["outcome"] = outcome
	o["tick"] = now
	if outcome in ["kept", "broken"]:
		var change := 1 if outcome == "kept" else -2
		trust[o.buyer][o.provider] = clampi(int(trust[o.buyer][o.provider]) + change, -4, 4)
		memories.append(
			{"offer": id, "who": o.buyer, "partner": o.provider, "outcome": outcome, "tick": now}
		)
	return o


func conserved() -> int:
	var total := 0
	for chips in balance:
		total += int(chips)
	for o in offers.values():
		total += int(o.price)
	return total
