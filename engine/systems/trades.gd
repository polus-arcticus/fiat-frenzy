## Climbing a trade. Every business is a trade at a tier (Catalog.TRADES: the hot dog stand is the meat trade's tier 0, the
## burger bar its tier 1), and its owner builds it up a tier out of their own savings: at dawn, an owner who has the next
## tier's build cost (MachineDef.build) and still a float to live and restock on pays it, and the business becomes the next
## tier (Machine.retier). The money is sunk, like a repair (Ledger.sunk): it is what the builders were paid. Nothing else
## moves: no rent, no loan, no tax, and nothing comes back down.
##
## The build costs are set against what an owner saves (the deposit on the town's bottles puts a little money into the town,
## Deposit, and it reaches the owners as takings), so a cluster climbs slowly: see tools/epoch.gd. The hero can
## hurry it, by giving an owner the money.
##
## It runs everywhere that is not asleep, dormant zones too (a cluster in summary grows as it would in full detail).
class_name Trades
extends RefCounted

const MERGE := {"day": "max"}  # (see Merge)

var day := 0  # the last day it looked (saved, so a loaded world builds on the same dawn the saved one would have)

var _w: World


func _init(world: World) -> void:
	_w = world


## What `m`'s owner must have on top of the build cost: the reserve every vendor keeps for groceries, and a full input store
## for the new tier at base prices (so the shop can open stocked).
static func float_for(kind: String) -> float:
	var d := Catalog.machine(kind)
	var stock := 0.0
	for raw in d.inputs:
		stock += d.inputs[raw] * Catalog.base_price(raw)
	return Drone.RESERVE + stock * d.stock_crafts


## A tier's build goods in words: "320 scrap", "60 scrap, 12 planks".
static func goods_text(goods: Dictionary) -> String:
	return ", ".join(goods.keys().map(func(g): return "%d %s" % [int(goods[g]), str(g).replace("_", " ")]))


## Can `m`'s owner build it up now? Returns the next tier's id, or "".
func can_build(m: Machine) -> String:
	var up := Catalog.next_tier(m.kind)
	if up == "" or not m.working:
		return ""
	var goods := Catalog.machine(up).build_goods
	if not goods.is_empty():  # built of the goods the runners have pooled into it (over what its own crafts keep in hand)
		for g in goods:
			if m.input.count(g) - m.per_craft(g) * Catalog.machine(m.kind).stock_crafts < int(goods[g]):
				return ""
		return up
	var owner := _w.drone(m.owner)
	if owner == null or owner.needless or owner.care != "":
		return ""
	return up if owner.wallet >= Catalog.machine(up).build + float_for(up) else ""


func step(_dt: float) -> void:
	if _w.clock.day() == day:
		return
	day = _w.clock.day()
	for m in _w.machines:
		if m.zone in _w.zones.asleep:
			continue
		var up := can_build(m)
		if up != "":
			build(m, up)
	for d in _w.drones:
		if d.runner != null and d.zone not in _w.zones.asleep and can_trade_up(d):
			trade_up(d)


## Can runner `d` buy the next rig now: has its price and the reserve everyone keeps, and is up and about?
func can_trade_up(d: Drone) -> bool:
	var next := d.runner.next_rig()
	return not next.is_empty() and d.care == "" and not d.needless and d.wallet >= float(next.cost) + Drone.RESERVE


## `d` pays for the next rig (the money sunk, as a build's), and the bins it brings within reach are there to be had.
func trade_up(d: Drone) -> void:
	var next := d.runner.next_rig()
	d.wallet -= float(next.cost)
	_w.ledger.sunk += float(next.cost)
	d.runner.tier += 1
	d.speed = next.speed
	var more := _w.open_round(d.zone, float(next.reach)) if float(next.reach) > 0.0 else []
	_w.events.append("t=%d %s bought a %s ($%.0f): faster, carrying %d%s" % [_w.clock.time, d.label, next.name, next.cost, next.load,
		", and %d bins further out are in reach" % more.size() if not more.is_empty() else ""])


## `m`'s owner pays to build it up into `up`.
func build(m: Machine, up: String) -> void:
	var was := m.display_name()
	var goods := Catalog.machine(up).build_goods
	if not goods.is_empty():
		for g in goods:
			m.input.take(g, int(goods[g]))
		m.retier(up)
		_w.events.append("t=%d the %s was built up into a %s (%s)" % [_w.clock.time, was, m.display_name(), Trades.goods_text(goods)])
		return
	var cost := Catalog.machine(up).build
	var owner := _w.drone(m.owner)
	owner.wallet -= cost
	_w.ledger.sunk += cost
	m.built_total += cost
	m.retier(up)
	_w.events.append("t=%d the %s was built up into a %s ($%.0f)" % [_w.clock.time, was, m.display_name(), cost])
