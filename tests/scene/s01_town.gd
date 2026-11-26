## Scene suite section: The town as found, the city, the views, the first tutorial step; and then the town grown, as the hero
## grows it: a tent at a time, its founders coming in their order (Lodging.FOUNDERS), each with a view of their own. The sections
## after this one play in the grown town.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var city: Node3D = game.city
	var walls: MeshInstance3D = city.get_node("Walls")
	check(walls.mesh.get_surface_count() == 1 and walls.mesh.surface_get_array_len(0) > 5000, "the city has walls (%d vertices)" % walls.mesh.surface_get_array_len(0))
	check((city.get_node("Windows") as MeshInstance3D).mesh.surface_get_array_len(0) > 10000, "and windows, and lit windows for the night")
	check(city.get_node("Collision").get_child_count() == 1 and city.get_node("GroundCollision").get_child_count() == 1, "and collision for the walls, and a slab of ground of its own")
	var w: World = game.world
	var sc: Scenario = game.scenario
	check(w.roads != null and w.roads.point_count() > 500, "the street graph has %d points" % w.roads.point_count())
	var market: Machine = sc.market
	var home_kinds := w.zones.machines_in(Zones.HOME).map(func(m): return m.kind)
	check(market.working and w.lodging.housed(market).size() == 1 and market.residence.tents == 1, "the first market is an atom as found: its tent city standing, its keeper in its one tent")
	check(home_kinds.size() == 3 and home_kinds.has("bike_shop") and home_kinds.has("skate_shop"), "and beside it only the story's two shops (%s)" % [home_kinds])
	check(w.lodging.housed(sc.ecb_market).size() == Atom.size() and w.zones.machines_in(Scenario.ECB_ZONE).filter(func(m): return m.residence == null).all(func(m): return not m.working), "the bank's market is an atom grown at once, its stands wrecked")
	check(w.hospitals.size() == 2 and w.ambulances.size() == 1 and w.relief_trucks.is_empty(), "the story's medical tent with its ambulance, and the bank's first aid post; no van")
	check(w.fires.size() == 3 and w.bottle_depots.size() == 1, "three barrel fires (the market's, the bank's market's, the bank's plaza) and the bank's market's bottle depot")
	check(w.vehicles.size() == 3 and w.transit.vehicle("tram_east").line != null and w.transit.vehicle("tram_west").line != null and w.transit.vehicle("shuttle").line != null, "tram 11 both ways, the golf cart on its own line; no bus")
	check(_views() == _things(w), "a view for each thing in the model (%d of %d)" % [_views(), _things(w)])
	var tent_view: MachineView = game.get_children().filter(func(c): return c is MachineView and c.machine == market)[0]
	var tent_solid: StaticBody3D = tent_view.get_node("Solid")
	check(tent_solid.get_child_count() == 3 and tent_solid.collision_layer == 1, "the field tent has walls the player and bills run into: three wall colliders")
	var hospital_view: HospitalView = game.get_children().filter(func(c): return c is HospitalView and c.hospital == sc.hospital)[0]
	check(hospital_view.get_node("Solid").get_child_count() == 3, "the medical tent has its three walls too")
	var organics: WasteBin = w.bins.filter(func(b): return b.kind == "organics" and b.zone == Zones.HOME)[0]
	check(organics.pos.distance_to(sc.start) > 5.0 and market.pos.distance_to(sc.start) < 70.0, "the tent city is a short walk from where the player begins")
	check(game.player.global_position.distance_to(Vector3(sc.start.x, 0, sc.start.y)) < 1.0, "the player starts on the street")

	for i in 30:
		await tree.physics_frame
	check(game.tutorial.index == 0, "the tutorial starts at step 1")
	var keeper: Drone = sc.cast.tent
	game.player.teleport(Vector3(keeper.pos.x + 3, 0.1, keeper.pos.y))
	for i in 5:
		await tree.physics_frame
	check(game.tutorial.index == 1, "walking to the tent keeper advances it")
	check(game.tutorial.text().contains("put up a tent") and game.tutorial.text().contains("bottle depot"), "and it asks for a tent, saying who comes next")

	# The town grown: a tent put up for each founder, and a while for each to come (the hero kept warm meanwhile: this is not
	# about the cold).
	w.player.needless = true
	var came: Array = []
	for i in Lodging.FOUNDERS.size():
		w.lodging.add_tent(market)
		game.advance(Lodging.ARRIVE_EVERY + 1.0)
		await tree.process_frame
		came.append(w.lodging.role_of(w.lodging.housed(market).back()))
	w.player.needless = false
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	# (The hero feels the cold as anyone in the street does, from here on: the street's fires went with the hand-made market, and
	# the hero's own cold (Cold) lasts about a block from the market's one fire. These sections are about everything else.)
	w.player.cold_spans = Vector2.ZERO
	check(came == Lodging.FOUNDERS.map(func(f): return f.role), "the founders came, one for each tent, in their order (%s)" % [came])
	check(["depot", "medic", "runners", "lemonade", "bakery", "thrift", "camp", "hot_dog"].all(func(k): return sc.cast.has(k)), "and the story knows them by name (Scenario.cast)")
	check(_views() == _things(w), "each with a view as they came (%d of %d)" % [_views(), _things(w)])
	var runner_views := game.get_children().filter(func(c): return c is DroneView and c.drone.kind == "runner")
	check(runner_views.size() == w.drones.filter(func(d): return d.kind == "runner").size() and runner_views.all(func(v): return v._cart != null and v._cart.slots() == 4), "every cart runner has a cart to push, with room for cargo (%d)" % runner_views.size())
	check(w.zones.machines_in(Zones.HOME).filter(func(m): return m.residence == null and not m.kind in ["bike_shop", "skate_shop"]).all(func(m): return not m.working), "every stand came wrecked")
	game.tutorial.update(game.player.ground_pos())
	var ids: Array = game.tutorial.open_goals().map(func(g): return g.id)
	check(ids.has("lemonade") and ids.has("bakery") and ids.has("hot_dog") and not ids.has("tent"), "and the tutorial has the stands to fund (%s)" % [ids])


func _views() -> int:
	var n := 0
	for c in game.get_children():
		if c is DroneView or c is MachineView or c is FireView or c is ReliefView or c is HospitalView or c is AmbulanceView or c is BottleDepotView or c is WasteBinView:
			n += 1
	return n


func _things(w: World) -> int:
	return w.drones.size() + w.machines.size() + w.fires.size() + w.relief_trucks.size() + w.hospitals.size() + w.ambulances.size() + w.bottle_depots.size() + w.bins.size()
