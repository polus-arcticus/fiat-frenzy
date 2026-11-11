## Loose money in the street. The player picks it up by walking over it; idle NPCs notice it within a few
## metres and go and fetch it. Whoever gets it keeps it: the money does not remember who fired it.
class_name Cash
extends RefCounted

const SCAN := 14.0          # an idle drone notices loose money this close
const REACH := 1.0          # an NPC picks it up from this close
const PLAYER_REACH := 1.4   # the player picks it up from this close

var _w: World


func _init(world: World) -> void:
	_w = world


func nearest_loose(from: Vector2, within: float, zone: String) -> Bill:
	var best: Bill = null
	var best_d := within
	for b in _w.bills:
		if b.zone == zone and b.loose and b.pos.distance_to(from) <= best_d:
			best_d = b.pos.distance_to(from)
			best = b
	return best


## An NPC picks a bill up. It counts as a little gift to them, so they think a bit better of the player.
func collect(d: Drone, b: Bill) -> void:
	_w.bills.erase(b)
	d.wallet += b.value
	d.rep = minf(1.0, d.rep + randf() * b.value / (b.value + 25.0) * 0.1)
	_w.levels.award(d, b.value)
	_w.chatter.say(d, Lines.CASH)


## The player picks up everything within reach. Returns the total.
func collect_for_player() -> float:
	if _w.player == null:
		return 0.0
	var got := 0.0
	for b in _w.bills.duplicate():
		if b.loose and b.pos.distance_to(_w.player.pos) <= PLAYER_REACH:
			got += b.value
			_w.bills.erase(b)
	_w.ledger.player_cash += got
	return got
