## Handing out experience. Every dollar the player gives someone (a gift, an investment, a bill they pick up)
## is experience for them; when it adds up to a new level their business expands with them.
class_name Levels
extends RefCounted

var _w: World


func _init(world: World) -> void:
	_w = world


func award(d: Drone, amount: float) -> void:
	if amount <= 0.0 or d.growth.add(amount) == 0:
		return
	var m = _w.machine_of(d)
	var fb = _w.food_bank_of(d)
	var what: String = d.label if d.label != "" else d.kind
	if m != null:
		m.set_level(d.growth.level)
		what = m.display_name()
	elif fb != null:
		fb.set_level(d.growth.level)
		what = fb.display_name()
	_w.events.append("t=%d the %s grew to level %d" % [_w.clock.time, what, d.growth.level])


## Money the player gives away is experience for the player too: a gift delivered, or a contract accepted
## (only the dollars that were taken). Bills they pick up, or that others pick up, are not.
func credit_player(amount: float) -> void:
	if _w.player == null or amount <= 0.0:
		return
	var gained := _w.player.growth.add(amount)
	if gained > 0:
		_w.events.append("t=%d you reached level %d" % [_w.clock.time, _w.player.growth.level])
