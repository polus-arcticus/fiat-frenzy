## The money gun, as the player uses it. Two modes for now (lines of credit come later):
##   gift    money for nothing, sprayed as bills; whoever it reaches keeps it, and thinks better of the player
##   invest  a charged shot that spits an investment contract: a share of a vendor's business. The money goes
##           to the vendor and the player gets that share of the machine's takings on every sale, forever.
##           At most 49% of any business.
## All the money the player hands over, either way, is experience for whoever gets it (see Growth).
##
## Firing a bill prints it: it exists in the world straight away. If it hits someone it is delivered (hit);
## if it misses it lands in the street as loose cash (land) for anyone to pick up. A contract is not money
## and is never left lying about: it buys a stake if it reaches a business (hit_contract), and otherwise
## it is void (discard), with nothing printed. `gift` and `invest` do the whole thing in one go, for scripted use.
class_name Gun
extends RefCounted

const MERGE := 0.9  # bills landing this close to each other make one pile

var _w: World


func _init(world: World) -> void:
	_w = world


## Prints a bill and puts it in the world, in flight. `mode` is "gift" for a bill meant for someone.
func fire(value: float, mode: String) -> Bill:
	var b := Bill.new(value, mode)
	b.zone = _w.player.zone if _w.player != null else _w.build_zone
	_w.ledger.printed += value
	_w.bills.append(b)
	return b


## The bill hit `d`. Returns {result, amount, stake, overflow}:
##   "gift"     their wallet (and experience, and rep)
##   "dropped"  anything else: it falls at their feet as loose cash
func hit(b: Bill, d: Drone) -> Dictionary:
	if b.mode == "gift":
		_w.bills.erase(b)
		_deliver_gift(d, b.value)
		return {"result": "gift", "amount": b.value, "stake": 0.0, "overflow": 0.0}
	land(b, d.pos)
	return {"result": "dropped", "amount": b.value, "stake": 0.0, "overflow": 0.0}


## The bill came down at `pos`. It becomes loose cash, joining a pile if one is right there. Returns
## the bill that is now lying there.
func land(b: Bill, pos: Vector2) -> Bill:
	for o in _w.bills:
		if o != b and o.loose and o.pos.distance_to(pos) <= MERGE:
			o.value += b.value
			_w.bills.erase(b)
			return o
	b.loose = true
	b.mode = "cash"
	b.pos = pos
	if not _w.bills.has(b):
		_w.bills.append(b)
	return b


## Spits a contract for `value`. Nothing is printed yet.
func fire_contract(value: float) -> Contract:
	return Contract.new(value)


## The contract reached `d`. Returns {result, amount, stake, voided}:
##   "invest"  a stake in their business, `amount` of it, which is printed now; if the 49% cap meant only
##             part fitted, the rest, `voided`, is void
##   "void"    nothing to buy into (no business, or already at the cap): all of it is void
## `stake` is the player's share afterwards, or -1 if they have no business.
func hit_contract(c: Contract, d: Drone) -> Dictionary:
	var m = _w.machine_of(d)
	if m == null:
		return {"result": "void", "amount": 0.0, "stake": -1.0, "voided": c.value}
	var accepted := _invest_core(d, m, c.value)
	_w.ledger.printed += accepted
	return {"result": "invest" if accepted > 0.0 else "void", "amount": accepted, "stake": m.equity.stake, "voided": c.value - accepted}


## The contract missed: it is void. Nothing was printed, so there is nothing to account for.
func discard(_c: Contract) -> void:
	pass


func gift(d: Drone, amount: float) -> void:
	_w.ledger.printed += amount
	_deliver_gift(d, amount)


## Spends `amount` buying into `d`'s business, as much as fits under the 49% cap, printing only what is
## spent. Returns {accepted, stake}: the dollars that went in, and the player's stake afterwards; stake is -1
## if there is no business to buy into.
func invest_ex(d: Drone, amount: float) -> Dictionary:
	var m = _w.machine_of(d)
	if m == null:
		return {"accepted": 0.0, "stake": -1.0}
	var accepted := _invest_core(d, m, amount)
	_w.ledger.printed += accepted
	return {"accepted": accepted, "stake": m.equity.stake}


## The player's stake afterwards, or -1 if the target has no business to buy into.
func invest(d: Drone, amount: float) -> float:
	return invest_ex(d, amount).stake


func _deliver_gift(d: Drone, amount: float) -> void:
	d.wallet += amount
	d.rep = minf(1.0, d.rep + randf() * amount / (amount + 25.0) * 0.1)
	_w.levels.award(d, amount)
	_w.levels.credit_player(amount)
	_w.chatter.say(d, Lines.GIFT)


## Buys the stake (priced before this money counts as experience, so the valuation is "pre-money"), hands
## the vendor what was accepted, and counts it as experience for them. Returns the dollars accepted.
func _invest_core(d: Drone, m: Machine, amount: float) -> float:
	var accepted: float = m.equity.buy(amount, m.repair_cost, m.growth.xp)
	if accepted > 0.0:
		d.wallet += accepted
		_w.levels.award(d, accepted)
		_w.levels.credit_player(accepted)
		_w.chatter.say(d, Lines.INVEST)
	return accepted
