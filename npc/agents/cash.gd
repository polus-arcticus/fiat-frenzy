## Loose money in the street. Idle NPCs notice it within a few metres and go and fetch it (the hero picks it up by walking over
## it: Commerce). Whoever gets it keeps it: the money does not remember who fired it.
class_name Cash
extends RefCounted

const SCAN := 14.0          # an idle drone notices loose money this close
const REACH := 1.0          # an NPC picks it up from this close

var _w: World


func _init(world: World) -> void:
	_w = world


func nearest_loose(from: Vector2, within: float, zone: String) -> Bill:
	var best: Bill = null
	var best_d := within
	for b in _w.bills:
		if b.zone == zone and b.loose and not b.aboard and b.pos.distance_to(from) <= best_d:
			best_d = b.pos.distance_to(from)
			best = b
	return best


## An NPC picks a bill up. It counts as a little gift to them, so they think a bit better of the player.
func collect(d: Drone, b: Bill) -> void:
	_w.bills.erase(b)
	_w.levels.receive(d, b.value)
	_w.chatter.say(d, Lines.CASH)
