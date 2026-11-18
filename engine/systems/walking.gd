## Moving drones. With a road graph they follow the streets; without one (the headless tests) they walk straight. Each leg
## of the way is checked against the zone's navigation grid: if something solid is in the way, the leg is replaced by a path
## round it (see Navigation), and a walker whose way has been changed under it (something built, something removed) plans
## it again. Vehicles (the ambulance) just follow the street.
class_name Walking
extends RefCounted

const SPEED := 1.5         # metres a second, a drifter's pace
const RUNNER_SPEED := 1.9  # a cart runner is a little quicker

var _w: World


func _init(world: World) -> void:
	_w = world


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
		d.route = _w.roads.route(d.pos, goal) if _w.roads != null else PackedVector2Array([goal])
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
		if dist <= budget:
			d.pos = next
			budget -= dist
			d.route.remove_at(0)
			d.route_nav = -1  # a new leg: it has not been checked
		else:
			d.pos += to / dist * budget
			d.heading = to.angle()
			budget = 0.0


## If something solid is in the way of the leg from here to the next waypoint, replace the waypoint with a way round.
func _plan_leg(d: Drone) -> void:
	var around := _w.nav.path(d.zone, d.pos, d.route[0])
	if around.is_empty():
		return  # no way (it should not happen): go straight, and the guard in step() keeps them out of the wall
	d.route.remove_at(0)
	for k in range(around.size() - 1, -1, -1):
		d.route.insert(0, around[k])


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
