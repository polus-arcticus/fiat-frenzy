## Where a drone can get what it needs: the open stand whose goods answer a demand at the best value,
## a bed or a free place at a fire, and the supplier a vendor should restock an input from.
class_name Supply
extends RefCounted

var _w: World


func _init(world: World) -> void:
	_w = world


## The open machine whose output answers `cls`, that this drone can afford: best value, which is
## dollars per unit of the bar plus a little for the walk. In its own zone, or in `zone` (Borders asks about the next tile).
func best_supply(d: Drone, cls: String, zone := "") -> Machine:
	var best: Machine = null
	var best_value := INF
	for m in _w.zones.machines_in(zone if zone != "" else d.zone):
		if m.owner == d.uid or Catalog.class_of(m.item) != cls or not m.offers(m.item) or m.price > d.wallet:
			continue
		var value: float = m.price / Catalog.restores(m.item) + Logistics.DISTANCE_COST * d.pos.distance_to(m.pos) + Queueing.WAIT_COST * _w.logistics.queues.length(m)
		if value < best_value:
			best_value = value
			best = m
	return best


## Their own bed, if they have one in a tent that is standing (it is free: see Lodging); otherwise the nearest barrel fire with
## a free spot.
func warmth_job(d: Drone) -> Dictionary:
	if d.bed != "":
		var home = _w.thing(d.bed)
		if home is Machine and home.working and home.zone == d.zone and home.shelter.has_room():
			return {"for": "warmth", "target": home, "item": ""}
	var best := {}
	var best_value := INF
	for f in _w.zones.fires_in(d.zone):
		var value: float = Logistics.DISTANCE_COST * d.pos.distance_to(f.pos)
		if f.shelter.has_room() and value < best_value:
			best_value = value
			best = {"for": "warmth", "target": f, "item": ""}
	return best


## Fetch the input the vendor's machine is shortest of, from whichever business offers it cheapest.
func restock_job(d: Drone) -> Dictionary:
	var m = _w.machine_of(d)
	var raw: String = _w.needs.short_input(m)
	var best = null
	var best_value := INF
	for s in _w.zones.machines_in(d.zone):
		if s == m or s.owner == d.uid or not s.offers(raw) or s.price_of(raw) > d.wallet - Needs.RESERVE:
			continue
		var value: float = s.price_of(raw) + Logistics.DISTANCE_COST * d.pos.distance_to(s.pos) + Queueing.WAIT_COST * _w.logistics.queues.length(s)
		if value < best_value:
			best_value = value
			best = s
	return {"for": "restock", "target": best, "item": raw} if best != null else {}
