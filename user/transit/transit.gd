## The bus's journeys. The hero boards, the bus drives itself along a smooth path through the streets and stops
## where it is going, and the hero carries on from there. The world keeps running the whole time: nothing here
## pauses it. While the hero is aboard they are where the bus is.
class_name Transit
extends RefCounted

const ARRIVE_WITHIN := 0.1   # it has arrived this close to the end of its path
const SLOWEST := 0.15        # it always creeps at least this fast until it arrives, so it can never stall short
const TURN_RATE := 5.0       # how quickly its heading follows the path's direction

var _w: World


func _init(world: World) -> void:
	_w = world


## The bus, waiting at its stop. `facing` is the angle of the way it points (as Walking measures it). It is warm inside.
func add_bus(at: Vector2, facing: float) -> Bus:
	var bus := Bus.new(at, facing)
	bus.zone = _w.build_zone
	_w.mint(bus)
	_w.bus = bus
	_w.bus_stop = at
	_w.heating.vehicles.append(bus)
	return bus


## The shuttle, a golf cart waiting at `at` (at the gate), pointing `facing`. Slower than the bus, quicker off the mark, and it
## turns tighter. The bank's: its seats are heated, which matters, for its ride round to the entrance takes longer than the
## hero's warmth lasts in the open by day (Cold).
func add_shuttle(at: Vector2, facing: float) -> Bus:
	var cart := Bus.new(at, facing)
	cart.zone = _w.build_zone
	_w.mint(cart)
	cart.top_speed = 7.0
	cart.accel = 1.6
	cart.brake = 2.2
	cart.turn_radius = 5.0
	_w.shuttle = cart
	_w.heating.vehicles.append(cart)
	return cart


## The hero gets on and the bus sets off for `dest`; on arriving it sets quest flag `flag` ("" for none). `via` is any places it
## must pass on the way (the last of them is where it ends up pointing from). If its way starts behind it, it first turns round
## to the left in a half circle `uturn` metres across (into the other lane; 0: it doesn't, the way is never behind it). False if
## it is already out, or there is no bus.
func board(dest: Vector2, flag := "rode_bus", via: Array = [], vehicle: Bus = null, direct := false, uturn := 0.0) -> bool:
	var bus := vehicle if vehicle != null else _w.bus
	if bus == null or bus.state == Bus.State.DRIVING or not dest.is_finite():
		return false
	var route := PackedVector2Array([bus.pos])
	var legs: Array = via.duplicate()
	legs.append(dest)
	var at := bus.pos
	if uturn > 0.0:
		var first: Vector2 = legs[0]
		var ahead: Vector2 = first if direct else _route(at, first)[0]
		if (ahead - at).normalized().dot(Vector2.from_angle(bus.heading)) < UTURN_BEHIND:
			var round := u_turn(at, Vector2.from_angle(bus.heading), uturn * 0.5)
			route.append_array(round)
			at = round[round.size() - 1]
	for target in legs:
		if direct:
			route.append(target)  # (a route laid out by hand: not the streets)
		else:
			route.append_array(_route(at, target))
		at = target
	bus.aboard = true
	bus.dest = dest
	bus.flag = flag
	bus.path = BusPath.build(route, bus.top_speed, bus.accel, bus.brake, bus.turn_radius)
	bus.s = 0.0
	bus.speed = 0.0
	bus.state = Bus.State.DRIVING
	_w.events.append("t=%d the %s pulls out" % [_w.clock.time, "shuttle" if bus == _w.shuttle else "bus"])
	return true


## The hero gets off `vehicle` (or whatever they are on). It stays where it is.
func disembark(vehicle: Bus = null) -> void:
	for v in ([vehicle] if vehicle != null else [_w.bus, _w.shuttle]):
		if v != null:
			v.aboard = false


func step(dt: float) -> void:
	for v in [_w.bus, _w.shuttle]:
		if v != null:
			v.prev_pos = v.pos
			v.prev_heading = v.heading
			if v.state == Bus.State.DRIVING:
				_drive(v, dt)
	if _w.bus != null:
		for b in _w.bills:
			if b.aboard:
				b.pos = _w.bus.to_world(b.local)  # (money on the floor of the bus goes where the bus goes)


func _drive(bus: Bus, dt: float) -> void:
	# It aims at the speed the path allows a little way ahead, and gets there only as fast as it can speed up or
	# brake (so it never lurches), but keeps creeping until it is where it is going.
	var target := bus.path.speed_at(minf(bus.s + 1.0 + bus.speed * 0.4, bus.path.length))
	bus.speed = move_toward(bus.speed, target, (bus.accel if target > bus.speed else bus.brake) * dt)
	if bus.path.length - bus.s > ARRIVE_WITHIN:
		bus.speed = maxf(bus.speed, SLOWEST)
	bus.s = minf(bus.s + bus.speed * dt, bus.path.length)
	bus.pos = bus.path.pos_at(bus.s)
	var want := bus.path.dir_at(bus.s).angle()
	bus.heading = lerp_angle(bus.heading, want, clampf(TURN_RATE * dt, 0.0, 1.0))
	if bus.s >= bus.path.length - ARRIVE_WITHIN:
		bus.pos = bus.dest
		bus.speed = 0.0
		bus.state = Bus.State.ARRIVED
		if bus.flag != "":
			_w.quests.set_flag(bus.flag)
		_w.events.append("t=%d the %s has stopped" % [_w.clock.time, "shuttle" if bus == _w.shuttle else "bus"])
	if bus.aboard and _w.player != null:
		_w.player.pos = bus.pos


## A half circle to the left of radius `r`, from `at` going `fwd`, after a few metres straight on: it ends 2r to the left of
## where it began, pointing back the way it came. Not counting `at` itself.
static func u_turn(at: Vector2, fwd: Vector2, r: float) -> PackedVector2Array:
	var left := fwd.rotated(-PI * 0.5)  # (x east, y south: a quarter turn back from forward is to the left)
	var start := at + fwd * UTURN_RUN
	var centre := start + left * r
	var out := PackedVector2Array([start])
	for k in range(1, UTURN_POINTS + 1):
		var a := PI * float(k) / UTURN_POINTS
		out.append(centre - left * r * cos(a) + fwd * r * sin(a))
	return out


const UTURN_BEHIND := -0.3  # the way is behind it if it heads off more than about 107 degrees from where the vehicle points
const UTURN_RUN := 4.0      # metres straight on before it swings round
const UTURN_POINTS := 12


## The streets from `from` to `to`, not counting `from` itself, without a first stretch that doubles back: the nearest
## street corner to a bus can be behind it, and a bus cannot turn on the spot to go and fetch it.
func _route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var route := _w.roads.route(from, to) if _w.roads != null else PackedVector2Array([to])
	var at := from
	while route.size() > 1 and _turn(at, route[0], route[1]) > 1.75:  # more than about 100 degrees
		at = route[0]
		route.remove_at(0)
	return route


## How sharply the way turns at `b`, coming from `a` and going on to `c`, in radians.
func _turn(a: Vector2, b: Vector2, c: Vector2) -> float:
	var in_dir := (b - a).normalized()
	var out_dir := (c - b).normalized()
	return acos(clampf(in_dir.dot(out_dir), -1.0, 1.0))
