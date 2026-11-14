## Unconsciousness, and who comes for you. Anyone (the player included) whose survival bar runs out
## collapses where they stand. An idle ambulance drives to the nearest of the collapsed, loads them, takes
## them to the hospital and puts them in a bed, where they are looked after until they are fit again.
## The ambulance only goes when there is a bed to take them to.
class_name Rescue
extends RefCounted

## What the hero lost to whoever went through their pockets while they were out cold (0 if nothing, or nothing yet).
var last_mugged := 0.0

const LOAD_RANGE := 3.0  # how close the ambulance gets to someone lying in the street
const LOAD_TIME := 2.0   # seconds to lift them in, and to lift them out
const HURRY_TRIP := 25.0

var _w: World


func _init(world: World) -> void:
	_w = world


func step(dt: float) -> void:
	_collapse()
	for a in _w.ambulances:
		if _w.is_active(a.hospital.zone):
			_drive(a, dt)
	for h in _w.hospitals:
		if not _w.is_active(h.zone):
			continue
		for d in h.step(dt):
			_w.events.append("t=%d %s up again" % [_w.clock.time, _who(d, "are", "is")])


## Everyone whose bar has run out goes down.
func _collapse() -> void:
	for d in _everyone():
		if d.care == "" and d.neediest() <= 0.0 and _w.is_active(d.zone):
			go_down(d)


func go_down(d: Drone) -> void:
	if d.sheltered_in != null:
		d.sheltered_in.release(d)
	d.care = "down"
	d.job = {}
	d.route = PackedVector2Array()
	_w.events.append("t=%d %s collapsed" % [_w.clock.time, "you" if d == _w.player else (d.label if d.label != "" else d.kind)])


## Someone goes through the hero's pockets while they are out: the cash they carry goes to a drifter nearby (or
## simply away, if there is nobody about). Money still adds up: it moves, it isn't made or lost.
func _mug_player() -> void:
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


## "you are" or "Edda is": how the town's news names someone.
func _who(d: Drone, you_verb: String, verb: String) -> String:
	return "you %s" % you_verb if d == _w.player else "%s %s" % [d.label if d.label != "" else d.kind, verb]


func _everyone() -> Array:
	var all: Array = []
	for z in _w.zones.running():
		all.append_array(_w.zones.drones_in(z))
	if _w.player != null:
		all.append(_w.player)
	return all


func _drive(a: Ambulance, dt: float) -> void:
	match a.job:
		Ambulance.Job.IDLE:
			var p := _next_patient(a)
			if p != null:
				a.patient = p
				_hurry(a, p.pos)
				a.job = Ambulance.Job.TO_PATIENT
			elif a.pos.distance_to(a.hospital.bay()) > 0.5:
				a.speed = Ambulance.SPEED
				_w.walking.step(a, a.hospital.bay(), dt)  # back to the bay to wait
		Ambulance.Job.TO_PATIENT:
			if a.pos.distance_to(a.patient.pos) > LOAD_RANGE:
				_w.walking.step(a, a.patient.pos, dt)
			else:
				a.route = PackedVector2Array()
				a.job = Ambulance.Job.LOADING
				a.wait = LOAD_TIME
		Ambulance.Job.LOADING:
			a.wait -= dt
			if a.wait <= 0.0:
				a.patient.care = "carried"
				_hurry(a, a.hospital.bay())
				a.job = Ambulance.Job.TO_HOSPITAL
		Ambulance.Job.TO_HOSPITAL:
			a.patient.pos = a.pos
			if a.pos.distance_to(a.hospital.bay()) > 0.5:
				_w.walking.step(a, a.hospital.bay(), dt)
			else:
				a.route = PackedVector2Array()
				a.job = Ambulance.Job.UNLOADING
				a.wait = LOAD_TIME
		Ambulance.Job.UNLOADING:
			a.wait -= dt
			if a.wait <= 0.0:
				a.hospital.admit(a.patient)
				if a.patient == _w.player:
					_mug_player()
				a.rescues += 1
				_w.events.append("t=%d %s in the medical tent" % [_w.clock.time, _who(a.patient, "are now", "is now")])
				a.patient = null
				a.job = Ambulance.Job.IDLE


## The nearest collapsed person nobody is coming for, if there will be a bed for them.
func _next_patient(a: Ambulance) -> Drone:
	var coming := 0
	for o in _w.ambulances:
		if o.patient != null:
			coming += 1
	if a.hospital.free_beds() - coming <= 0:
		return null
	var best: Drone = null
	var best_d := INF
	for d in _everyone():
		if d.care != "down" or d.zone != a.hospital.zone or _claimed(d):
			continue
		var dist := a.pos.distance_squared_to(d.pos)
		if dist < best_d:
			best_d = dist
			best = d
	return best


## Sirens: a trip is at the ambulance's usual pace in the market, but a long way off it goes fast enough to
## take about HURRY_TRIP seconds (the hero is in the dark the whole time). Set once, as the trip begins.
func _hurry(a: Ambulance, goal: Vector2) -> void:
	a.speed = clampf(a.pos.distance_to(goal) / HURRY_TRIP, Ambulance.SPEED, 150.0)


func _claimed(d: Drone) -> bool:
	for a in _w.ambulances:
		if a.patient == d:
			return true
	return false
