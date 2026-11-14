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


## The hero gets on and the bus sets off for `dest`; on arriving it sets quest flag `flag`. `via` is any places it must
## pass on the way (the last of them is where it ends up pointing from). False if it is already out, or there is no bus.
func board(dest: Vector2, flag := "rode_bus", via: Array = []) -> bool:
	var bus := _w.bus
	if bus == null or bus.state == Bus.State.DRIVING or not dest.is_finite():
		return false
	var route := PackedVector2Array([bus.pos])
	var legs: Array = via.duplicate()
	legs.append(dest)
	var at := bus.pos
	for target in legs:
		route.append_array(_route(at, target))
		at = target
	bus.aboard = true
	bus.dest = dest
	bus.flag = flag
	bus.path = BusPath.build(route)
	bus.s = 0.0
	bus.speed = 0.0
	bus.state = Bus.State.DRIVING
	_w.events.append("t=%d the bus pulls out" % _w.clock.time)
	return true


## The hero gets off. The bus stays where it is.
func disembark() -> void:
	if _w.bus != null:
		_w.bus.aboard = false


func step(dt: float) -> void:
	var bus := _w.bus
	if bus == null:
		return
	bus.prev_pos = bus.pos
	bus.prev_heading = bus.heading
	if bus.state != Bus.State.DRIVING:
		return
	# It aims at the speed the path allows a little way ahead, and gets there only as fast as a bus can speed up or
	# brake (so it never lurches), but keeps creeping until it is where it is going.
	var target := bus.path.speed_at(minf(bus.s + 1.0 + bus.speed * 0.4, bus.path.length))
	bus.speed = move_toward(bus.speed, target, (BusPath.ACCEL if target > bus.speed else BusPath.BRAKE) * dt)
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
		_w.events.append("t=%d the bus has stopped" % _w.clock.time)
	if bus.aboard and _w.player != null:
		_w.player.pos = bus.pos


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
