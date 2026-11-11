## Moving drones. With a road graph they follow the streets; without one (the headless tests) they
## walk straight.
class_name Walking
extends RefCounted

const SPEED := 1.5         # metres a second, a drifter's pace
const RUNNER_SPEED := 1.9  # a cart runner is a little quicker
const KEEP_UNTIL := 0.5     # a chosen corner or door counts as reached this close (see _steer)

var _w: World


func _init(world: World) -> void:
	_w = world


## `d` is anything with a position, route and speed: a drone, or the ambulance.
func step(d, goal: Vector2, dt: float) -> void:
	if d is Drone:
		var solids := _w.zones.solids_in(d.zone)
		goal = _steer(d, solids, goal)
		var start: Vector2 = d.pos
		_move(d, goal, dt, solids)
		d.pos = _clip(solids, start, d.pos)
	else:
		_move(d, goal, dt)  # the ambulance drives on the street, round nothing


## Where `d` heads for `goal`, with the way round whatever is in the way kept once it is chosen: a drone that has
## picked a corner (or a tent's door) goes there and only then looks again. Worked out afresh every step, two plans
## that each undo the other (round the corner, or along the street the other way first) can trade places for ever.
func _steer(d: Drone, solids: Array, goal: Vector2) -> Vector2:
	if d.steer_to.is_finite():
		var kept := d.steer_for.distance_to(goal) <= 0.5 and d.pos.distance_to(d.steer_to) >= KEEP_UNTIL
		if kept:
			for s in solids:
				if not s.clear(d.pos, d.steer_to):  # something has got in the way of it: think again
					kept = false
					break
		if kept:
			return d.steer_to
		d.steer_to = Vector2(INF, INF)
	var head := _approach(solids, d.pos, goal)
	if head != goal:
		d.steer_to = head
		d.steer_for = goal
	return head


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


func _move(d, goal: Vector2, dt: float, solids := []) -> void:
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
	var guard := 0
	while budget > 0.0 and not d.route.is_empty() and guard < 8:
		guard += 1
		# The street route ignores solid things, so each leg of it is steered round them too (not just the last
		# goal): a waypoint on the far side of a tent would otherwise pull the walker into its wall for ever.
		var waypoint: Vector2 = d.route[0]
		var next := waypoint
		for pass_ in 2:
			for s in solids:
				next = s.detour(d.pos, next)
		var to: Vector2 = next - d.pos
		var dist: float = to.length()
		if dist <= budget:
			d.pos = next
			budget -= dist
			if next == waypoint:
				d.route.remove_at(0)  # (reaching a corner on the way is not reaching the waypoint)
		else:
			d.pos += to / dist * budget
			d.heading = to.angle()
			budget = 0.0
