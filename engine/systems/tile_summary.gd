## A dormant zone, in summary. Nobody in it walks, queues or talks, but the town still lives: its businesses and food bank
## produce, its people get hungry and thirsty and buy what answers it, vendors repair and restock, and runners haul. Each
## errand is planned and carried out by the same rules as in full detail (Logistics.plan and Logistics.complete), only
## without the walk: so prices, takings, stakes and the books move exactly as they would, a little sooner.
##
## Warmth is the one thing summarised coarsely: in a zone with a barrel fire, people are taken to be by it (they do not cool);
## in a zone without one they cool as usual. Whoever collapses goes down, as in full detail, and the zone's medical tent takes
## them in without the ambulance's drive. Nobody walks, so when the hero arrives everyone is where they were left (or in a
## bed), and plans afresh.
class_name TileSummary
extends RefCounted

## Errands a summary carries out. (Warmth would move people into berths, and loose cash would have them walk to it.)
const ERRANDS := ["food", "drink", "repair", "restock", "haul"]
const MAX_ERRANDS := 6  # the most one person does in one coarse step

var _w: World


func _init(world: World) -> void:
	_w = world


## Runs `zone` forward by `dt` seconds, in one step.
func step(zone: String, dt: float) -> void:
	for m in _w.zones.machines_in(zone):
		m.step(dt)
	for fb in _w.zones.food_banks_in(zone):
		fb.step(dt)
	_w.needs.wake_sleepers([zone])
	var by_a_fire := not _w.zones.fires_in(zone).is_empty()
	var here: Array = _w.zones.drones_in(zone).duplicate()
	_w.shuffle(here)  # no one always gets first pick of a thin shelf
	for d in here:
		_drain(d, dt, by_a_fire)
		_errands(d)
	_rescue(zone, dt)


## The medical tent, in summary: it looks after its patients as usual, and takes in whoever has collapsed while it has beds
## (the ambulance's drive is skipped: they are simply in a bed).
func _rescue(zone: String, dt: float) -> void:
	for h in _w.zones.hospitals_in(zone):
		h.step(dt)
		for d in _w.zones.drones_in(zone):
			if h.free_beds() <= 0:
				break
			if d.care == "down":
				h.admit(d)


func _drain(d: Drone, dt: float, by_a_fire: bool) -> void:
	if d.unconscious() or d.needless:
		return
	if by_a_fire or d.sheltered_in != null:
		var warmth: float = d.bars.warmth
		_w.needs.decay(d, dt)
		d.bars.warmth = maxf(warmth, d.bars.warmth)  # by the fire: they keep what warmth they had
	else:
		_w.needs.decay(d, dt)
	if d.neediest() <= 0.0:
		_w.rescue.go_down(d)  # as in full detail; the ambulance waits for the hero's arrival, so they stay down till then


## Whatever this drone would go and do, done on the spot, until it has nothing more to do (or has done MAX_ERRANDS).
func _errands(d: Drone) -> void:
	if d.unconscious() or d.aloof or d.sheltered_in != null:
		return
	d.route = PackedVector2Array()
	for i in MAX_ERRANDS:
		d.job = {}
		var job := _w.logistics.plan(d)
		if job.is_empty() or not job["for"] in ERRANDS:
			break
		var before := _state(d)
		_w.logistics.complete(d, job)
		if job["for"] == "haul" and not d.job.is_empty():
			_w.logistics.complete(d, d.job)  # the pickup set up the drop: wheel it straight over
		if _state(d) == before:
			break  # it could not be done after all (it could not pay, the shelf was bare)
	d.job = {}


## Enough of a drone's state to tell whether an errand did anything.
func _state(d: Drone) -> Array:
	return [d.wallet, d.bars.hunger, d.bars.thirst, d.carry.counts.duplicate(), d.cart.counts.duplicate()]
