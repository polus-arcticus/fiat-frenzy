## Moving drones. With a road graph they follow the streets; without one (the headless tests) they walk straight. Each leg
## of the way is checked against the zone's navigation grid: if something solid is in the way, the leg is replaced by a path
## round it (see Navigation), and a walker whose way has been changed under it (something built, something removed) plans
## it again. Vehicles (the ambulance) just follow the street.
## Hills (World.landform) set the pace: a walker covers ground at `pace` of their speed on the flat, by Tobler's hiking rule
## (quickest on a gentle descent, slower up a slope and down a steep one). `effort` reckons a trip the same way, for those
## who plan one (Needs.would_last).
class_name Walking
extends RefCounted

const SPEED := 1.5         # metres a second, a drifter's pace
const SLOWEST := 0.15      # the least share of their flat pace anyone keeps, however steep (a scramble, not a stop)
## Metres between the points a trip's hills are read at. Trips are reckoned often (every job a drone weighs, every tick), and
## the land is smoothed over 40 m (Landform.SMOOTH): reading it more finely costs the sim more than it tells (measured:
## tools/bench_hills.gd, 8 m was 2 ms a game second of 14 for 200 walkers, with nobody walking differently).
const EFFORT_STEP := 32.0
## A walk no longer than this, straight, leaves the streets when they would make it more than DETOUR times as long (and
## DETOUR_FREE metres besides: round a corner is not worth leaving the pavement for).
const SHORT_HOP := 60.0
const DETOUR := 1.5
const DETOUR_FREE := 15.0

var _w: World


func _init(world: World) -> void:
	_w = world


## The share of their pace on the flat a walker keeps going up a `grade` (rise over run; negative is downhill): Tobler's
## hiking function, 6 e^(-3.5 |grade + 0.05|) km/h, over what it gives on the flat. 1 on the flat, about 1.19 at its best
## (a 5% descent), 0.70 up 10%, 0.35 up 30%, 0.5 down 30%.
static func pace(grade: float) -> float:
	return clampf(exp(-3.5 * (absf(grade + 0.05) - 0.05)), SLOWEST, 1.2)


## What walking through `points` in turn takes, in metres on the flat: its length, each stretch over its hills' pace. Exactly
## its length where the land is flat.
func effort(points: Array) -> float:
	var total := 0.0
	var land := _w.landform
	for k in points.size() - 1:
		var a: Vector2 = points[k]
		var b: Vector2 = points[k + 1]
		var length := a.distance_to(b)
		if land.flat or length < 0.01:
			total += length
			continue
		var n := maxi(1, ceili(length / EFFORT_STEP))
		var dir := (b - a) / length
		for s in n:
			var p := a.lerp(b, (s + 0.5) / n)
			total += length / n / pace(land.walk_grade(p, dir))
	return total


## The waypoints from `from` to `to`: along the streets, unless it is a short hop that the streets make a long way round
## (across a square with no street in it): then straight, round whatever stands in the way (_plan_leg).
func way(from: Vector2, to: Vector2) -> PackedVector2Array:
	var direct := PackedVector2Array([to])
	if _w.roads == null:
		return direct
	var streets := _w.roads.route(from, to)
	var straight := from.distance_to(to)
	if straight > SHORT_HOP:
		return streets
	var length := 0.0
	var at := from
	for p in streets:
		length += at.distance_to(p)
		at = p
	return direct if length > straight * DETOUR + DETOUR_FREE else streets


## `d` is anything with a position, route and speed: a drone, or the ambulance.
func step(d, goal: Vector2, dt: float) -> void:
	if d is Drone:
		var start: Vector2 = d.pos
		_walk(d, goal, dt)
		d.pos = _clip(_w.zones.solids_in(d.zone), start, d.pos)  # (a last guard: nobody ends up inside a wall)
	else:
		_follow_streets(d, goal, dt)  # the ambulance drives on the street, round nothing


## A move from `from` to `to`, kept out of everything solid.
func _clip(solids: Array, from: Vector2, to: Vector2) -> Vector2:
	if from == to:
		return to
	for s in solids:
		to = s.slide(from, to)
	return to


func _walk(d: Drone, goal: Vector2, dt: float) -> void:
	if d.pos.distance_to(goal) < 0.05:
		d.route = PackedVector2Array()
		return
	if d.route.is_empty() or d.route_goal.distance_to(goal) > 0.5:
		d.route = way(d.pos, goal)
		d.route_goal = goal
		d.route_nav = -1
	var budget: float = d.speed * dt
	var guard := 0
	while budget > 0.0 and not d.route.is_empty() and guard < 12:
		guard += 1
		while d.route.size() > 1 and _w.nav.inside_solid(d.zone, d.route[0]):
			d.route.remove_at(0)  # (a waypoint inside a stand: a street that ends in one. The way on is the next.)
			d.route_nav = -1
		var version := _w.nav.version(d.zone)
		if d.route_nav != version:
			_plan_leg(d)
			d.route_nav = version
		var next: Vector2 = d.route[0]
		var to: Vector2 = next - d.pos
		var dist: float = to.length()
		var keep := 1.0 if _w.landform.flat or dist < 0.01 else pace(_w.landform.walk_grade(d.pos, to / dist))  # (the hill here)
		if dist <= budget * keep:
			d.pos = next
			budget -= dist / keep
			d.route.remove_at(0)
			d.route_nav = -1  # a new leg: it has not been checked
		else:
			d.pos += to / dist * budget * keep
			d.heading = to.angle()
			budget = 0.0


## If something solid is in the way of the leg from here to the next waypoint, replace the waypoint with a way round. Someone
## inside a tent (the medic at the first aid post) goes out by its open front first: the way round is planned from outside.
func _plan_leg(d: Drone) -> void:
	var tent := _tent_around(d.zone, d.pos)
	if tent != null and not tent.enclosure.contains(d.route[0]) and d.pos.distance_to(tent.door) > 0.3:
		d.route.insert(0, tent.door)
		return
	var around := _w.nav.path(d.zone, d.pos, d.route[0])
	if around.is_empty():
		return  # no way (it should not happen): go straight, and the guard in step() keeps them out of the wall
	d.route.remove_at(0)
	for k in range(around.size() - 1, -1, -1):
		d.route.insert(0, around[k])


## The tent whose inside `p` is in, or null.
func _tent_around(zone: String, p: Vector2) -> Footprint:
	for s in _w.zones.solids_in(zone):
		if s.enclosure != null and s.enclosure.contains(p):
			return s
	return null


## A vehicle on the streets: along the route, nothing else.
func _follow_streets(d, goal: Vector2, dt: float) -> void:
	if d.pos.distance_to(goal) < 0.05:
		d.route = PackedVector2Array()
		return
	if _w.roads == null:
		var to: Vector2 = goal - d.pos
		var s: float = minf(d.speed * dt, to.length())
		d.pos += to.normalized() * s
		d.heading = to.angle()
		return
	if d.route.is_empty() or d.route_goal.distance_to(goal) > 0.5:
		d.route = _w.roads.route(d.pos, goal)
		d.route_goal = goal
	var budget: float = d.speed * dt
	while budget > 0.0 and not d.route.is_empty():
		var next: Vector2 = d.route[0]
		var to: Vector2 = next - d.pos
		var dist: float = to.length()
		if dist <= budget:
			d.pos = next
			budget -= dist
			d.route.remove_at(0)
		else:
			d.pos += to / dist * budget
			d.heading = to.angle()
			budget = 0.0
