## Shared builders for the sim tests: little towns, a clinic, and ways to run the clock.
class_name Fixtures
extends RefCounted


static func run(w: World, seconds: int, keep_fed := false) -> void:
	for i in seconds:
		if keep_fed:
			for d in w.drones:
				d.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
		w.tick(1.0)


## Ticks until `done` is true; returns the seconds it took, or -1.
static func until(w: World, done: Callable, max_seconds: int) -> int:
	for i in max_seconds:
		w.tick(1.0)
		if done.call():
			return i
	return -1


static func bars(h: float, t: float, wm: float) -> Dictionary:
	return {"hunger": h, "thirst": t, "warmth": wm}


# ---------------------------------------------------------------- the foundation


static func shop_world() -> Array:
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(3, 0))
	var p := w.add_player(Vector2(0, 0))
	p.carry.counts.clear()  # these tests are about buying; the starting kit has its own test
	return [w, baker, w.machine_of(baker), p]


static func spread(points: Array) -> float:
	var low := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			low = minf(low, (points[i] as Vector2).distance_to(points[j]))
	return low


static func runner_world(owner_wallet := 40.0, runner_wallet := 20.0) -> Array:
	var w := World.new()
	var keeper := w.add_food_bank(Vector2(0, 0), 0.0)
	var baker := w.add_vendor("bakery", Vector2(30, 0), owner_wallet)
	var bakery := w.machine_of(baker)
	bakery.input.take("flour", 4)  # its flour is out: 12 short
	var runner := w.add_runner(Vector2(2, 3), runner_wallet)
	for d in w.drones:
		d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	return [w, keeper, baker, bakery, runner]


static func l_road() -> RoadGraph:
	var g := RoadGraph.new()
	g.add_polyline(PackedVector2Array([Vector2(0, 0), Vector2(25, 0), Vector2(50, 0), Vector2(50, 25), Vector2(50, 50)]))
	return g


static func clinic() -> World:
	var w := World.new()
	w.add_hospital(Vector2(0, 20), Vector2(0, -1))  # a tent at (0,20), the street to its north
	return w


static func empty_shops(w: World) -> void:
	for m in w.machines:
		for raw in m.recipe:
			if raw not in Catalog.free_inputs():
				m.input.take(raw, 1000)


static func hungry_crowd(w: World, n: int) -> void:
	for i in n:
		var d := w.add_drifter(Vector2(randf_range(-10, 10), randf_range(5, 15)), 20.0)
		d.bars = Fixtures.bars(0.2, 1.0, 1.0)


## Bakery, hot dog stand, lemonade stand, tent, a barrel fire, the truck and ten drifters.
static func town(with_truck := true) -> World:
	var w := World.new()
	w.add_vendor("bakery", Vector2(0, 0), 30.0)
	w.add_vendor("hot_dog_stand", Vector2(8, 0), 30.0)
	w.add_vendor("lemonade_stand", Vector2(16, 0), 30.0)
	w.add_vendor("tent", Vector2(-8, 0), 30.0)
	w.add_fire(Vector2(-4, 6))
	if with_truck:
		w.add_relief_truck(Vector2(4, -8))
	for i in 10:
		w.add_drifter(Vector2(randf_range(-12, 12), randf_range(-12, 12)), 30.0)
	return w


## Three days of the basic gun: a little money sprayed at a random drifter once a minute.
static func basic_gun_days(w: World, days: int) -> void:
	for i in int(Clock.DAY_SECONDS * days):
		if i % 60 == 0:
			w.gun.gift(w.drones[4 + randi() % 10], 5.0)
		w.tick(1.0)


static func made(w: World) -> int:
	var n := 0
	for m in w.machines:
		n += m.crafted_total
	return n
