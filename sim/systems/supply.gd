## Where a drone can get what it needs: the open stand whose goods answer a demand at the best value,
## a bed or a free place at a fire, and the supplier a vendor should restock an input from.
class_name Supply
extends RefCounted

var _w: World


func _init(world: World) -> void:
	_w = world


## The open machine whose output answers `cls`, that this drone can afford: best value, which is
## dollars per unit of the bar plus a little for the walk.
func best_supply(d: Drone, cls: String) -> Machine:
	var best: Machine = null
	var best_value := INF
	for m in _w.zones.machines_in(d.zone):
		if m.owner_id == d.id or Catalog.class_of(m.item) != cls or not m.offers(m.item) or m.price > d.wallet:
			continue
		var value: float = m.price / Catalog.restores(m.item) + Logistics.DISTANCE_COST * d.pos.distance_to(m.pos)
		if value < best_value:
			best_value = value
			best = m
	return best


## A free spot at a barrel fire, or a bed in a tent, whichever costs less counting the walk.
func warmth_job(d: Drone) -> Dictionary:
	var best := {}
	var best_value := INF
	for f in _w.zones.fires_in(d.zone):
		var value: float = Logistics.DISTANCE_COST * d.pos.distance_to(f.pos)
		if f.shelter.has_room() and value < best_value:
			best_value = value
			best = {"for": "warmth", "target": f, "item": ""}
	for m in _w.zones.machines_in(d.zone):
		if m.owner_id == d.id or m.shelter == null or not m.offers(m.item) or m.price > d.wallet:
			continue
		var value: float = m.price + Logistics.DISTANCE_COST * d.pos.distance_to(m.pos)
		if value < best_value:
			best_value = value
			best = {"for": "warmth", "target": m, "item": m.item}
	return best


## Fetch the input the vendor's machine is shortest of, from whichever business offers it cheapest.
func restock_job(d: Drone) -> Dictionary:
	var m = _w.machine_of(d)
	var raw: String = _w.needs.short_input(m)
	var best = null
	var best_value := INF
	for s in _w.zones.machines_in(d.zone):
		if s == m or s.owner_id == d.id or not s.offers(raw) or s.price_of(raw) > d.wallet - Needs.RESERVE:
			continue
		var value: float = s.price_of(raw) + Logistics.DISTANCE_COST * d.pos.distance_to(s.pos)
		if value < best_value:
			best_value = value
			best = s
	return {"for": "restock", "target": best, "item": raw} if best != null else {}
