## The hero: how they are moving about right now. One mode at a time (on foot, on the bike, on the board, in a seat), so
## "can I get on this?" is answered in one place and nothing can be riding and skating at once. The rules of each mode
## (the bike's reach, the board's tricks) stay with that mode's own feature; this only says which one the hero is in, and
## whether they are allowed to change.
##
## It also takes the hero's turn in the tick (first of the end-of-tick systems): their bars drain like anyone's, their zone
## follows where they are, and a zone asleep wakes when they walk into it. And when the medical tent takes them in, someone has
## been through their pockets (`last_mugged`). The engine knows none of this.
class_name Hero
extends RefCounted

enum Mode { ON_FOOT, RIDING, SKATING, SEATED }

const COLD_WARNING := 0.4  # the feed warns as the hero's warmth falls past this

var mode: Mode = Mode.ON_FOOT
var last_mugged := 0.0  # what was taken from the hero's pockets the last time they were carried to the medical tent

var _w: World


func _init(world: World) -> void:
	_w = world
	world.rescue.on_admitted = func(d: Drone): if d == _w.player: _mug()


func step(dt: float) -> void:
	var p := _w.player
	if p == null:
		return
	var was: float = p.bars.warmth
	_w.needs.decay(p, dt)
	if was >= COLD_WARNING and p.bars.warmth < COLD_WARNING:  # (the cold bites fast out here: see Cold)
		_w.events.append("t=%d you're getting cold: get to a barrel fire, or find a coat (the thrift stall)" % _w.clock.time)
	p.zone = _w.zones.zone_for(p.pos, p.zone)
	_w.zones.wake(p.zone)


## Someone goes through the hero's pockets while they are out: the cash they carry goes to a drifter nearby (or simply away, if
## there is nobody about). Money still adds up: it moves, it isn't made or lost.
func _mug() -> void:
	last_mugged = _w.ledger.player_cash
	if last_mugged <= 0.0:
		return
	_w.ledger.player_cash = 0.0
	var thief: Drone = null
	var best := INF
	for d in _w.drones:
		if d.kind == "drifter" and d.look == "" and d.care == "" and d.zone == _w.player.zone:
			var dist := d.pos.distance_squared_to(_w.player.pos)
			if dist < best:
				best = dist
				thief = d
	if thief != null:
		thief.wallet += last_mugged
	else:
		_w.ledger.sunk += last_mugged
	_w.events.append("t=%d you were mugged while you were out: $%.2f gone" % [_w.clock.time, last_mugged])


func is_on_foot() -> bool:
	return mode == Mode.ON_FOOT


## Why the hero can't switch to `to` right now, or "". (Going back on foot is always allowed.)
func why_not(to: Mode) -> String:
	if to == Mode.ON_FOOT:
		return ""
	if mode == to:
		return "You're already on it."
	if _w.player != null and _w.player.unconscious():
		return "You're out cold."
	match mode:
		Mode.RIDING:
			return "Get off the bike first."
		Mode.SKATING:
			return "Get off the skateboard first."
		Mode.SEATED:
			return "Stand up first."
	return ""


## Switches mode if allowed. Returns "" on success, else the reason.
func enter(to: Mode) -> String:
	var why := why_not(to)
	if why == "":
		mode = to
	return why


## Back on their own two feet, whatever they were doing.
func stand() -> void:
	mode = Mode.ON_FOOT
