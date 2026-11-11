## Runs the Red Cross van's timetable: it is in town for STAY seconds from each arrival time, and
## hands out its load as it arrives.
class_name Relief
extends RefCounted

var _w: World


func _init(world: World) -> void:
	_w = world


func run() -> void:
	var frac: float = _w.clock.fraction()
	for t in _w.relief_trucks:
		if not _w.is_active(t.zone):
			continue
		var here := false
		for a in ReliefTruck.ARRIVALS:
			if frac >= a and frac < a + ReliefTruck.STAY / Clock.DAY_SECONDS:
				here = true
		if here and not t.present:
			t.arrive(_w.machines.filter(func(m): return m.zone == t.zone))
			_w.events.append("t=%d the Red Cross van arrives and hands out %s" % [_w.clock.time, t.last_delivery])
		elif not here and t.present:
			t.depart()
