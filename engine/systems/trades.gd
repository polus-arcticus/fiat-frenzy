## Climbing a trade. Every business is a trade at a tier (Catalog.TRADES: the hot dog stand is the meat trade's tier 0, the
## burger bar its tier 1), and its owner builds it up a tier out of their own savings: at dawn, an owner who has the next
## tier's build cost (MachineDef.build) and still a float to live and restock on pays it, and the business becomes the next
## tier (Machine.retier). The money is sunk, like a repair (Ledger.sunk): it is what the builders were paid. Nothing else
## moves: no rent, no loan, no tax, and nothing comes back down.
##
## The build costs are set against what an owner saves (the welfare office's fountain at Welfare.DOLLARS_A_DAY puts a little
## money into the town, and it reaches the owners as takings), so a cluster climbs slowly: see tools/epoch.gd. The hero can
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


## Can `m`'s owner build it up now? Returns the next tier's id, or "".
func can_build(m: Machine) -> String:
	var up := Catalog.next_tier(m.kind)
	if up == "" or not m.working:
		return ""
	var scrap := Catalog.machine(up).build_scrap
	if scrap > 0:  # built of the scrap the runners have pooled into it
		return up if m.input.count("scrap") - m.per_craft("scrap") * Catalog.machine(m.kind).stock_crafts >= scrap else ""
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


## `m`'s owner pays to build it up into `up`.
func build(m: Machine, up: String) -> void:
	var was := m.display_name()
	var scrap := Catalog.machine(up).build_scrap
	if scrap > 0:
		m.input.take("scrap", scrap)
		m.retier(up)
		_w.events.append("t=%d the %s was built up into a %s (%d scrap)" % [_w.clock.time, was, m.display_name(), scrap])
		return
	var cost := Catalog.machine(up).build
	var owner := _w.drone(m.owner)
	owner.wallet -= cost
	_w.ledger.sunk += cost
	m.built_total += cost
	m.retier(up)
	_w.events.append("t=%d the %s was built up into a %s ($%.0f)" % [_w.clock.time, was, m.display_name(), cost])
