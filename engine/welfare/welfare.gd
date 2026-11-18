## The welfare office at work: a little money fountain. Now and then, at random, a dollar or few goes to a resident picked at
## random (the poorest of PICKS picked). It is there so nobody has to end up in the medical tent for want of a dollar, not to
## make anyone rich: the town's economy is its stands' supply and demand, and the fountain only keeps a trickle of money
## coming into it. No tax, no levy, no rent.
##   how much  about DOLLARS_A_DAY for every fit resident each day (more as the office levels up, from the hero's gifts to its
##             clerk).
##   whose     the food bank's takings go out first (the same charity: what it sells its donated goods for comes back out
##             here, or it would pile up in its keeper's till), then what the hero has given the clerk. Only when there is
##             neither is it new money, counted in Ledger.printed and Ledger.issued, so total_money == ledger.printed holds.
## Later, as an upgrade the hero can earn: a reservoir the hero funds, that the office draws on (not built).
class_name Welfare
extends RefCounted

const DOLLARS_A_DAY := 12.0  # given out for every fit resident, each day, on average
const PICKS := 3            # residents picked at random for each gift: the poorest of them gets it
const PER_LEVEL := 0.25     # this much more (as a fraction) for every office level above the first
const GIFT_MIN := 1         # dollars at a time, at the least...
const GIFT_MAX := 3         # ...and at the most
const TILL_FLOAT := 20.0    # dollars a food bank's keeper keeps for themselves: the rest of its takings are the fountain's

var _w: World


func _init(world: World) -> void:
	_w = world


## Those the welfare office serves: everyone fit who has needs, in a zone that is not asleep.
func residents() -> Array:
	return _w.drones.filter(func(d): return not d.needless and d.care == "" and not d.zone in _w.zones.asleep)


## The office's clerk, whose wallet holds what the hero has given the office.
func clerk(office: WelfareOffice) -> Drone:
	return _w.drone(office.owner)


## Dollars a day this office gives out, for `heads` residents shared between `offices` offices.
func rate(office: WelfareOffice, heads: int, offices := 1) -> float:
	return DOLLARS_A_DAY * heads / float(offices) * (1.0 + PER_LEVEL * (clerk(office).growth.level - 1))


## Who each zone's offices serve: the residents of that zone, and (the home town's) those of zones with no office of their own.
## zone -> [residents].
func _served() -> Dictionary:
	var offices := {}
	for o in _w.welfare_offices:
		offices[o.zone] = true
	var fallback: String = Zones.HOME if offices.has(Zones.HOME) else _w.welfare_offices[0].zone
	var out := {}
	for d in residents():
		var z: String = d.zone if offices.has(d.zone) else fallback
		if not out.has(z):
			out[z] = []
		out[z].append(d)
	return out


func step(dt: float) -> void:
	if _w.welfare_offices.is_empty():
		return
	var served := _served()
	var counts := {}
	for o in _w.welfare_offices:
		counts[o.zone] = int(counts.get(o.zone, 0)) + 1
	var mean := (GIFT_MIN + GIFT_MAX) / 2.0
	for office in _w.welfare_offices:
		var people: Array = served.get(office.zone, [])
		if people.is_empty():
			continue
		# How many gifts are due in `dt`, on average: the whole ones are given, and the rest is a chance. (In a 1 s tick it is
		# well under one, so just a chance; a coarse step, as tools/epoch.gd takes, can owe several.)
		var due := rate(office, people.size(), counts[office.zone]) / mean * dt / Clock.DAY_SECONDS
		var gifts := int(due) + (1 if _w.rng.randf() < due - int(due) else 0)
		for g in gifts:
			var lucky: Drone = people[_w.rng.randi() % people.size()]
			for i in PICKS - 1:
				var other: Drone = people[_w.rng.randi() % people.size()]
				if other.wallet < lucky.wallet:
					lucky = other
			_give(office, lucky)


func _give(office: WelfareOffice, lucky: Drone) -> void:
	var value := float(_w.rng.randi_range(GIFT_MIN, GIFT_MAX))
	var from := _source(office, value)
	if from != null:
		from.wallet -= value
	else:
		_w.ledger.printed += value
		_w.ledger.issued += value
	lucky.wallet += value
	office.given_out += value


## Whose money this is, if anyone's: the food bank's till first, then what the hero has given the office. Null: there is
## none, and it is new money.
func _source(office: WelfareOffice, value: float) -> Drone:
	for fb in _w.zones.food_banks_in(office.zone):  # (its own town's: money does not cross between zones on its own)
		var keeper := _w.drone(fb.owner)
		if keeper != null and keeper.wallet - value >= TILL_FLOAT:
			return keeper
	var c := clerk(office)
	return c if c.wallet >= value else null
