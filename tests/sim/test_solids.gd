## Sim tests: solid things. Drones don't walk through tent walls or counters.
extends TestCase


func _tent_world() -> Array:
	var w := World.new()
	var keeper := w.add_vendor("tent", Vector2(0, 0), 30.0)
	var m := w.machine_of(keeper)
	m.front = Vector2(0, 1)  # the open end faces +y; the tent runs from y=+1.1 back to y=-1.85
	return [w, m]


## Walks `d` toward `goal` and reports {reached, inside_wall, steps}.
func _walk(w: World, d: Drone, goal: Vector2, wall_parts: Array, max_steps := 400) -> Dictionary:
	var inside_wall := false
	var steps := 0
	while d.pos.distance_to(goal) > 0.3 and steps < max_steps:
		w.walking.step(d, goal, 0.1)
		steps += 1
		for p in wall_parts:
			if p.contains(d.pos):
				inside_wall = true
	return {"reached": d.pos.distance_to(goal) <= 0.3, "inside_wall": inside_wall, "steps": steps}


func test_nobody_walks_through_a_tent_wall() -> void:
	var tw := _tent_world()
	var w: World = tw[0]
	var m: Machine = tw[1]
	var walls: Array = m.solid().parts.slice(0, 3)
	check(walls.size() == 3 and m.solid().enclosure != null, "a tent is three walls round an inside, open at the front")
	var d := w.add_drifter(Vector2(-4, -0.4), 5.0)
	var r := _walk(w, d, Vector2(4, -0.4), walls)
	check(r.reached, "a drifter heading straight at the tent's side gets round it and carries on (%d steps)" % r.steps)
	check(not r.inside_wall, "and was never in a wall on the way")
	var back := w.add_drifter(Vector2(0, -6), 5.0)
	var r2 := _walk(w, back, Vector2(0, 5), walls)
	check(r2.reached and not r2.inside_wall, "from behind the tent, the same: round it, never through it")


func test_a_sleeper_goes_in_by_the_door() -> void:
	var tw := _tent_world()
	var w: World = tw[0]
	var m: Machine = tw[1]
	var inside := m.pos
	var enc := m.solid().enclosure
	var from_side := w.add_drifter(Vector2(-5, 0), 5.0)
	var r := _walk(w, from_side, inside, m.solid().parts.slice(0, 3))
	check(r.reached and enc.contains(from_side.pos), "a drifter who wants a bed walks round to the front and in, from the side (%d steps)" % r.steps)
	check(not r.inside_wall, "without touching a wall")
	var behind := w.add_drifter(Vector2(0, -7), 5.0)
	var r2 := _walk(w, behind, inside, m.solid().parts.slice(0, 3), 600)
	check(r2.reached and enc.contains(behind.pos), "and from behind it too")
	check(m.solid().door.distance_to(m.pos) > 1.5 and m.solid().door.y > 1.0, "the door is outside the open front")


func test_counters_and_fires_are_solid_too() -> void:
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0), 10.0)
	w.machine_of(baker).front = Vector2(0, 1)
	var counter: Footprint.Part = w.machine_of(baker).solid().parts[0]
	var d := w.add_drifter(Vector2(0, 3), 5.0)
	var r := _walk(w, d, Vector2(0, -3), [counter])
	check(r.reached and not r.inside_wall, "walking at a counter, a drifter goes round it")
	var f := w.add_fire(Vector2(10, 0))
	var e := w.add_drifter(Vector2(7, 0), 5.0)
	var r2 := _walk(w, e, Vector2(13, 0), f.solid().parts)
	check(r2.reached and not r2.inside_wall, "and round a barrel fire")


func test_the_vendor_is_not_boxed_in_and_vehicles_ignore_footprints() -> void:
	var tw := _tent_world()
	var w: World = tw[0]
	var keeper := w.drones[0]
	keeper.pos = w.machine_of(keeper).post()
	var d_before := keeper.pos
	w.walking.step(keeper, Vector2(0, 8), 0.1)
	check(keeper.pos != d_before, "a keeper standing at the back of their own tent can still walk out")
	var h := w.add_hospital(Vector2(30, 0), Vector2(0, 1))
	var a := w.ambulances[0]
	a.pos = Vector2(30, -8)
	for i in 60:
		w.walking.step(a, Vector2(30, 8), 0.1)
	check(a.pos.distance_to(Vector2(30, 8)) < 0.5, "the ambulance drives on the street and isn't kept out by the tent it serves")
	check(h.solid().enclosure != null, "the medical tent has walls and an inside too")
