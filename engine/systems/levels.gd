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
	var what: String = d.label if d.label != "" else d.kind
	if m != null:
		m.set_level(d.growth.level)
		what = m.display_name()
	_w.events.append("t=%d the %s grew to level %d" % [_w.clock.time, what, d.growth.level])


## `d` is given `amount` of money that already exists (a bill that hit them): into their wallet, a little more regard for the
## giver, and experience.
func receive(d: Drone, amount: float) -> void:
	d.wallet += amount
	d.rep = minf(1.0, d.rep + _w.rng.randf() * amount / (amount + 25.0) * 0.1)
	award(d, amount)


## `d` is given `amount` of new money (printed, as the gun prints it): how a headless run funds someone with no hero about
## (Cluster.fund), and the core of the gun's gift.
func give(d: Drone, amount: float) -> void:
	_w.ledger.printed += amount
	receive(d, amount)
