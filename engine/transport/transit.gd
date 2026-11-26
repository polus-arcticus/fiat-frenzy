## The world's vehicles and their journeys (Vehicle): the bus, the bank's golf cart, a train. On a line (Line) a vehicle runs stop
## to stop when the hero rides it (`ride`), round and round or back and forth (Vehicle.wraps); off one it goes where it is sent (`board`). Either way it drives
## itself along a smooth path (DrivePath) and stops where it is going, and the hero carries on from there. The world keeps
## running the whole time: nothing here pauses it. While the hero is aboard they are where the vehicle is.
##
## It knows nothing of the story: arriving is told to whoever listens (`arrived`), with the vehicle's `flag` (the story's quests
## take it as done: World connects them).
class_name Transit
extends RefCounted

signal arrived(vehicle: Vehicle)

const ARRIVE_WITHIN := 0.1   # it has arrived this close to the end of its path
const SLOWEST := 0.15        # it always creeps at least this fast until it arrives, so it can never stall short
const TURN_RATE := 5.0       # how quickly its heading follows the path's direction
const SHORTEST_LEG := 1.0    # a stretch of line shorter than this is not worth driving

var _w: World


func _init(world: World) -> void:
	_w = world


## A vehicle of `kind` (Vehicle.SPECS) called `called`, standing at `at`, pointing `facing` (the angle of the way it points, as
## Walking measures it). Warm inside (Heating).
func add(called: String, kind: String, at: Vector2, facing: float) -> Vehicle:
	var v := Vehicle.new(at, facing, kind)
	v.name = called
	v.zone = _w.build_zone
	_w.mint(v)
	_w.vehicles.append(v)
	_w.heating.vehicles.append(v)
	return v


## A vehicle of `kind` called `called` on `line`, standing at its stop `at_stop`. Null if there is no line, or no two stops on it
## to run between.
func add_on(called: String, kind: String, line: Line, at_stop := 0) -> Vehicle:
	if line == null or line.stops.size() < 2:
		return null
	var v := add(called, kind, line.stops[at_stop].at, 0.0)
	v.run_on(line, at_stop)
	return v


## The vehicle called `called`, or null.
func vehicle(called: String) -> Vehicle:
	for v in _w.vehicles:
		if v.name == called:
			return v
	return null


## The hero gets on `v` and it sets off along its line for its next stop, or straight through to stop `to`. One that goes round runs off the line's end and comes
## on at its start for the first stop; one going back and forth turns in the road first if the stop is behind it. On arriving it
## says so with `flag`. False if it is out, or on no line.
func ride(v: Vehicle, flag := "", to := -1) -> bool:
	if v == null or v.line == null or v.state == Vehicle.State.DRIVING or to == v.stop or to >= v.line.stops.size():
		return false
	var next := to if to >= 0 else v.next_stop()
	var way := v.line.between(v.stop, next)
	var then := PackedVector2Array()
	if v.wraps and next <= v.stop:
		way = v.line.span(v.line.stops[v.stop].s, v.line.length)
		then = v.line.span(0.0, v.line.stops[next].s)
		if way[0].distance_to(way[way.size() - 1]) < SHORTEST_LEG:  # (the stop is at the very end: straight on from the start)
			_jump(v, then)
			way = then
			then = PackedVector2Array()
	var via: Array = Array(way.slice(1, way.size() - 1))
	if not board(v, way[way.size() - 1], via, true, 0.0 if v.wraps else float(v.spec().uturn), flag):
		return false
	v.going = next
	v.then = then
	return true


## Puts it at the start of `way`, pointing along it, without it having driven there: off one edge of the map and on at the other.
func _jump(v: Vehicle, way: PackedVector2Array) -> void:
	v.pos = way[0]
	v.prev_pos = v.pos
	v.heading = (way[1] - way[0]).angle()
	v.prev_heading = v.heading
	if v.aboard and _w.player != null:
		_w.player.pos = v.pos


## The way on from where it jumped to: the same ride, its flag still to say.
func _carry_on(v: Vehicle) -> void:
	var way := v.then
	v.then = PackedVector2Array()
	_jump(v, way)
	v.dest = way[way.size() - 1]
	var sp := v.spec()
	v.path = DrivePath.build(way, sp.top, sp.accel, sp.brake, sp.radius)
	v.s = 0.0


## The hero gets on `v` and it sets off for `dest`; on arriving it says so with `flag` ("" for nothing to say). `via` is any places
## it must pass on the way (the last of them is where it ends up pointing from); `direct`: straight through them, a route laid out
## by hand (else along the streets). If its way starts behind it, it first turns round to the left in a half circle `uturn` metres
## across (into the other lane; 0: it doesn't, the way is never behind it). False if it is already out, or there is none.
func board(v: Vehicle, dest: Vector2, via: Array = [], direct := false, uturn := 0.0, flag := "") -> bool:
	if v == null or v.state == Vehicle.State.DRIVING or not dest.is_finite():
		return false
	var route := PackedVector2Array([v.pos])
	var legs: Array = via.duplicate()
	legs.append(dest)
	var at := v.pos
	if uturn > 0.0:
		var first: Vector2 = legs[0]
		var ahead: Vector2 = first if direct else _route(at, first)[0]
		if (ahead - at).normalized().dot(Vector2.from_angle(v.heading)) < UTURN_BEHIND:
			var round := u_turn(at, Vector2.from_angle(v.heading), uturn * 0.5)
			route.append_array(round)
			at = round[round.size() - 1]
	for target in legs:
		if direct:
			route.append(target)
		else:
			route.append_array(_route(at, target))
		at = target
	var sp := v.spec()
	v.aboard = true
	v.dest = dest
	v.flag = flag
	v.then = PackedVector2Array()
	v.path =DrivePath.build(route, sp.top, sp.accel, sp.brake, sp.radius)
	v.s = 0.0
	v.speed = 0.0
	v.state = Vehicle.State.DRIVING
	_w.events.append("t=%d the %s pulls out" % [_w.clock.time, v.name])
	return true


## The hero gets off `v` (or whatever they are on). It stays where it is.
func disembark(v: Vehicle = null) -> void:
	for x in ([v] if v != null else _w.vehicles):
		x.aboard = false


func step(dt: float) -> void:
	for v in _w.vehicles:
		v.prev_pos = v.pos
		v.prev_heading = v.heading
		if v.state == Vehicle.State.DRIVING:
			_drive(v, dt)
		v.settle()
	for b in _w.bills:
		if b.aboard:
			var under := vehicle(b.ride)
			if under != null:
				b.pos = under.to_world(b.local)  # (money on a vehicle's floor goes where it goes)


func _drive(v: Vehicle, dt: float) -> void:
	# It aims at the speed the path allows a little way ahead, and gets there only as fast as it can speed up or
	# brake (so it never lurches), but keeps creeping until it is where it is going.
	var sp := v.spec()
	var target := v.path.speed_at(minf(v.s + 1.0 + v.speed * 0.4, v.path.length))
	v.speed = move_toward(v.speed, target, (sp.accel if target > v.speed else sp.brake) * dt)
	if v.path.length - v.s > ARRIVE_WITHIN:
		v.speed = maxf(v.speed, SLOWEST)
	v.s = minf(v.s + v.speed * dt, v.path.length)
	v.pos = v.path.pos_at(v.s)
	var want := v.path.dir_at(v.s).angle()
	v.heading = lerp_angle(v.heading, want, clampf(TURN_RATE * dt, 0.0, 1.0))
	if v.s >= v.path.length - ARRIVE_WITHIN and not v.then.is_empty():
		_carry_on(v)
		return
	if v.s >= v.path.length - ARRIVE_WITHIN:
		v.pos = v.dest
		v.speed = 0.0
		v.state = Vehicle.State.ARRIVED
		_w.events.append("t=%d the %s has stopped" % [_w.clock.time, v.name])
		arrived.emit(v)
	if v.aboard and _w.player != null:
		_w.player.pos = v.pos


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
