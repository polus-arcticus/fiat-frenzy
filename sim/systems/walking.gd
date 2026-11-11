## Moving drones. With a road graph they follow the streets; without one (the headless tests) they
## walk straight.
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
		var solids := _w.zones.solids_in(d.zone)
		goal = _approach(solids, d.pos, goal)
		var start: Vector2 = d.pos
		_move(d, goal, dt)
		d.pos = _clip(solids, start, d.pos)
	else:
		_move(d, goal, dt)  # the ambulance drives on the street, round nothing


## Where to head for `goal`: the door of a tent if the goal is inside it, and the corner of anything solid
## that is in the way.
func _approach(solids: Array, from: Vector2, goal: Vector2) -> Vector2:
	for s in solids:
		goal = s.approach(from, goal)
	for pass_ in 2:
		for s in solids:
			goal = s.detour(from, goal)
	return goal


## A move from `from` to `to`, kept out of everything solid.
func _clip(solids: Array, from: Vector2, to: Vector2) -> Vector2:
	if from == to:
		return to
	for s in solids:
		to = s.slide(from, to)
	return to


func _move(d, goal: Vector2, dt: float) -> void:
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
