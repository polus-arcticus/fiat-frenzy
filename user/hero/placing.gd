## Putting things down in the street, as in Planet Crafter: a tent or a barrel fire from the hero's bag (ItemDef.use "place").
## These are the rules; the ghost that shows where it would go is PlacementController's.
##   a barrel fire   becomes a barrel fire there: anyone near it warms up (see Cold, Needs)
##   a tent          founds a tent city of its own at tier 0, with a newcomer who keeps it (Lodging.found)
## It goes only where someone could stand: on open ground (not in a wall or a stand: Navigation.blocked), within REACH of the
## hero, and not on top of anything else that stands in the street.
class_name Placing
extends RefCounted

const REACH := 6.0
## How much room each needs round its middle: the open ground it must have, and how far it must be from anything else.
const ROOM := {"barrel_fire": 0.6, "tent": 1.3}
const GAP := 1.2  # metres of clear ground between it and the next thing

var _w: World


func _init(world: World) -> void:
	_w = world


## Why `item` can't go at `at` just now, or "" if it can.
func why_not(item: String, at: Vector2) -> String:
	var p := _w.player
	if p == null or not Catalog.item(item).placeable:
		return "That can't be put down."
	if p.carry.count(item) < 1:
		return "You don't have one."
	if p.pos.distance_to(at) > REACH:
		return "Too far away."
	var r: float = ROOM[item]
	for off in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if _w.nav.blocked(p.zone, at + off):
			return "Not there: it needs open ground."
	for o in _things(p.zone):
		if _distance(o, at) < r + GAP + _size(o):
			return "Too close to the %s." % _name(o)
	return ""


func can_place(item: String, at: Vector2) -> bool:
	return why_not(item, at) == ""


## Puts `item` down at `at` (a tent's open end toward `front`). Returns {ok, text}.
func place(item: String, at: Vector2, front := Vector2(0, 1)) -> Dictionary:
	var no := why_not(item, at)
	if no != "":
		return {"ok": false, "text": no}
	var p := _w.player
	p.carry.take(item, 1)
	if item == "barrel_fire":
		var was := _w.build_zone
		_w.build_zone = p.zone
		var f := _w.add_fire(at)
		_w.build_zone = was
		_w.arrivals.append(f)
		_w.zones.invalidate()
		return {"ok": true, "text": "A barrel fire, lit: anyone near it warms up."}
	var city := _w.lodging.found(at, front, p.zone)
	return {"ok": true, "text": "A tent of your own in the street: %s has come to keep it. Put up more tents there and others will come." % _w.drone(city.owner).label}


## Everything that stands in the street in `zone`, which a thing put down must keep clear of.
func _things(zone: String) -> Array:
	var out: Array = []
	for list in [_w.machines, _w.fires, _w.food_banks, _w.hospitals, _w.welfare_offices, _w.scrap_piles]:
		for o in list:
			if o.zone == zone:
				out.append(o)
	return out


## How far `at` is from `o`: from its middle, or for a tent city from the line down the middle of its row of tents.
func _distance(o: Object, at: Vector2) -> float:
	if o is Machine and o.shelter != null:
		var last: Vector2 = o.bed_pos(maxi(0, o.tents - 1))
		return Geometry2D.get_closest_point_to_segment(at, o.bed_pos(0), last).distance_to(at)
	return o.pos.distance_to(at)


## Roughly how far `o` reaches from its middle (a tent city: from the line of its tents).
func _size(o: Object) -> float:
	if o is Machine and o.shelter != null:
		return Machine.TENT_WIDTH * 0.6
	if o is BarrelFire:
		return 0.6
	return 1.5


func _name(o: Object) -> String:
	if o is BarrelFire:
		return "barrel fire"
	if o is ScrapPile:
		return "pile of scrap"
	return o.display_name().to_lower() if o.has_method("display_name") else "stand"
