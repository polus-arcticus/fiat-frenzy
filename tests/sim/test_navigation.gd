## Sim tests: navigation. Paths round everything solid, built to change: things can be stamped on and off while the game runs,
## and walkers whose way was changed under them find a new one.
extends TestCase


func _walk(w: World, d: Drone, goal: Vector2, max_steps := 1500) -> int:
	var steps := 0
	while d.pos.distance_to(goal) > 0.6 and steps < max_steps:
		w.walking.step(d, goal, 0.1)
		steps += 1
	return steps


func test_a_clear_way_is_one_straight_line_and_a_blocked_one_goes_round() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 0))
	check(w.nav.path("district", Vector2(-10, 5), Vector2(10, 5)) == PackedVector2Array([Vector2(10, 5)]), "with nothing in the way it is one straight line")
	var round := w.nav.path("district", Vector2(-10, 0.05), Vector2(10, 0.05))
	check(round.size() >= 2 and round[round.size() - 1] == Vector2(10, 0.05), "with a fire in the way it goes round and ends where asked")
	var clean := true
	for p in round:
		clean = clean and not w.nav.blocked("district", p)
	check(clean, "and none of the points it walks through is in the fire's way")
	var length := 0.0
	var at := Vector2(-10, 0.05)
	for p in round:
		length += at.distance_to(p)
		at = p
	check(length < 21.5, "and it is pulled straight, not a staircase (%.2f m for a 20 m crossing)" % length)


func test_everything_is_cells_so_every_shape_is_walked_round_the_same_way() -> void:
	var w := World.new()
	w.add_vendor("bakery", Vector2(0, 0), 5.0)        # a box
	w.add_fire(Vector2(8, 0))                          # a circle
	w.add_vendor("tent", Vector2(-9, 0), 5.0)          # three walls
	var arrived := 0
	var tries := 0
	for goal in [Vector2(14, 0.2), Vector2(-14, 0.1), Vector2(4, -6), Vector2(-4, 6)]:
		for start in [Vector2(-4, 0.2), Vector2(4, 0.1), Vector2(0, 7), Vector2(12, -3)]:
			var d := w.add_drifter(start, 0.0)
			tries += 1
			if _walk(w, d, goal) < 1500:
				arrived += 1
	check(arrived == tries, "round a stand, a fire and a tent, from everywhere to everywhere (%d of %d)" % [arrived, tries])


func test_a_tents_open_end_is_just_free_cells() -> void:
	var w := World.new()
	var keeper := w.add_vendor("tent", Vector2(0, 0), 5.0)
	var m := w.machine_of(keeper)
	m.front = Vector2(0, 1)
	var inside := Vector2(0.3, -0.9)
	var behind := Vector2(0, -8)
	check(not w.nav.blocked("district", inside), "the inside of the tent is walkable")
	check(w.nav.blocked("district", Vector2(-0.95, -0.5)), "its side wall is not")
	var way := w.nav.path("district", inside, behind)
	check(not way.is_empty() and way[0].y > 0.8, "from inside to behind it, the way goes out of the open end first (via %s)" % str(way[0] if not way.is_empty() else null))
	var d := w.add_drifter(inside, 0.0)
	check(_walk(w, d, behind) < 1500, "and they get there")


func test_a_wall_can_be_built_and_taken_down_and_the_way_follows() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 30))  # (a solid somewhere, so the zone has a grid)
	var from := Vector2(-10, 0)
	var to := Vector2(10, 0)
	var v0 := w.nav.version("district")
	check(w.nav.path("district", from, to) == PackedVector2Array([to]), "an open lane: a straight line")
	w.nav.imprint("district", "wall", PackedVector2Array([Vector2(-0.4, -6), Vector2(0.4, -6), Vector2(0.4, 6), Vector2(-0.4, 6)]))
	check(w.nav.version("district") > v0, "building something changes the version: everyone's plans are out of date")
	var around := w.nav.path("district", from, to)
	var length := 0.0
	var at := from
	for p in around:
		length += at.distance_to(p)
		at = p
	check(around.size() >= 2 and length > 22.0, "with a wall across the lane, the way goes round the end of it (%.1f m)" % length)
	check(w.nav.blocked("district", Vector2(0, 0)) and not w.nav.blocked("district", Vector2(0, 9)), "the wall's cells are taken, the ground past its end is not")
	w.nav.release("district", "wall")
	check(w.nav.path("district", from, to) == PackedVector2Array([to]) and not w.nav.blocked("district", Vector2(0, 0)), "taking it down gives the straight line back")


func test_two_things_on_one_cell_keep_it_taken_until_both_are_gone() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 30))
	var square := func(c: Vector2) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(-1, -1), c + Vector2(1, -1), c + Vector2(1, 1), c + Vector2(-1, 1)])
	w.nav.imprint("district", "a", square.call(Vector2(0, 0)))
	w.nav.imprint("district", "b", square.call(Vector2(0.5, 0)))
	w.nav.release("district", "a")
	check(w.nav.blocked("district", Vector2(0.4, 0)), "with one gone the other still holds the cell")
	w.nav.release("district", "b")
	check(not w.nav.blocked("district", Vector2(0.4, 0)), "and when both are gone it is free")


func test_a_walker_whose_way_is_built_over_finds_another() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 30))
	var d := w.add_drifter(Vector2(-10, 0), 0.0)
	var goal := Vector2(10, 0)
	for i in 30:
		w.walking.step(d, goal, 0.1)  # a few steps along the open lane
	check(d.pos.x > -9.0 and d.pos.x < -2.0, "(under way: %s)" % str(d.pos))
	w.nav.imprint("district", "wall", PackedVector2Array([Vector2(-0.4, -6), Vector2(0.4, -6), Vector2(0.4, 6), Vector2(-0.4, 6)]))
	var steps := _walk(w, d, goal)
	check(steps < 1500 and d.pos.distance_to(goal) <= 0.6, "built over mid-walk, they replan and get there anyway")


func test_a_goal_with_no_way_gives_no_path_and_buildings_are_walked_round() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 30))
	# a walled yard: four thick walls all round a spot
	var yard := [
		PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, -3), Vector2(-5, -3)]),
		PackedVector2Array([Vector2(-5, 3), Vector2(5, 3), Vector2(5, 5), Vector2(-5, 5)]),
		PackedVector2Array([Vector2(-5, -5), Vector2(-3, -5), Vector2(-3, 5), Vector2(-5, 5)]),
		PackedVector2Array([Vector2(3, -5), Vector2(5, -5), Vector2(5, 5), Vector2(3, 5)]),
	]
	for k in yard.size():
		w.nav.imprint("district", "yard%d" % k, yard[k])
	check(w.nav.path("district", Vector2(-20, 0), Vector2(0, 0)).is_empty(), "no way into a closed yard: an empty path")
	w.nav.release("district", "yard3")
	check(not w.nav.path("district", Vector2(-20, 0), Vector2(0, 0)).is_empty(), "knock a wall down and there is")
	# a building told about once, off to one side of the fire
	var w2 := World.new()
	w2.add_fire(Vector2(0, 0))
	w2.nav.add_static("district", PackedVector2Array([Vector2(-6, 8), Vector2(6, 8), Vector2(6, 20), Vector2(-6, 20)]))
	check(w2.nav.blocked("district", Vector2(0, 14)), "a building's outline is solid")
	var way := w2.nav.path("district", Vector2(-12, 14), Vector2(12, 14))
	check(way.size() >= 3, "and the way across is round it, not through (%d points)" % way.size())


func test_zones_keep_their_own_grids() -> void:
	var w := World.new()
	w.add_fire(Vector2(0, 0))
	w.build_zone = "far"
	w.add_fire(Vector2(500, 0))
	check(not w.nav.blocked("district", Vector2(500, 0)) and w.nav.blocked("far", Vector2(500, 0)), "a fire is solid in its own zone and not in another")
