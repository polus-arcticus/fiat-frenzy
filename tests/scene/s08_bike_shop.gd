## Scene suite section: The bike shop: a door, a room, walls, and a bike to ride.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# the bike shop: a door you can walk through into a room, walls you can't, and a bike you can get on
	var shop: Dictionary = game.scenario.bike_shop
	var door: Vector2 = shop.door
	var inward: Vector2 = shop.inward
	var along: Vector2 = shop.along
	var owner: Drone = game.scenario.cast.bike_shop
	check(Geometry2D.is_point_in_polygon(owner.pos, shop.poly) and w.machine_of(owner).working, "the bike shop owner stands inside the building, at an open shop")
	check(owner.pos.distance_to(door) > 5.0 and Geometry2D.is_point_in_polygon(w.machine_of(owner).pos, shop.poly), "and so does his counter, well in from the door")
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var through_door := PhysicsRayQueryParameters3D.create(Vector3(door.x, 1.2, door.y) - Vector3(inward.x, 0, inward.y) * 3.0, Vector3(door.x, 1.2, door.y) + Vector3(inward.x, 0, inward.y) * 6.0, 1)
	var through_wall := PhysicsRayQueryParameters3D.create(Vector3(door.x, 1.2, door.y) + Vector3(along.x, 0, along.y) * 5.0 - Vector3(inward.x, 0, inward.y) * 3.0, Vector3(door.x, 1.2, door.y) + Vector3(along.x, 0, along.y) * 5.0 + Vector3(inward.x, 0, inward.y) * 6.0, 1)
	check(space.intersect_ray(through_door).is_empty(), "a ray goes straight in through the doorway")
	check(not space.intersect_ray(through_wall).is_empty(), "but one aimed at the wall beside it is stopped")
	var outside := door - inward * 3.0
	game.player.teleport(Vector3(outside.x, 0.1, outside.y), atan2(-inward.x, -inward.y))
	Input.action_press("move_forward")
	for i in 150:
		await tree.physics_frame
	Input.action_release("move_forward")
	var ground: Vector2 = game.player.ground_pos()
	check(Geometry2D.is_point_in_polygon(ground, shop.poly) and ground.distance_to(door) > 3.0, "the player walks in through the door and is inside (%.1f m past it)" % ground.distance_to(door))
	var back := door - along * 4.0 - inward * 0.2
	game.player.teleport(Vector3(back.x, 0.1, back.y), atan2(-inward.x, -inward.y))
	Input.action_press("move_forward")
	for i in 90:
		await tree.physics_frame
	Input.action_release("move_forward")
	check(not Geometry2D.is_point_in_polygon(game.player.ground_pos(), shop.poly), "but walking at the wall beside the door, they can't get through it")
	w.ledger.player_cash += Catalog.bike_price()
	w.ledger.printed += Catalog.bike_price()
	var at_counter: Vector2 = w.machine_of(owner).pos + w.machine_of(owner).front * 2.0
	game.player.teleport(Vector3(at_counter.x, 0.1, at_counter.y), 0.0)
	game.advance(0.2)
	var bought := w.commerce.buy(w.machine_of(owner), "bicycle")
	game.advance(0.2)
	check(bought.ok and w.bike != null and game.bike_controller._view != null, "buying the bike parks one outside, with a view of it in the street")
	var gun_visible_before: bool = game.gun.visible
	game.bike_controller.toggle()
	check(w.riding.riding() and game.player.speed_scale > 2.0 and not game.gun.visible and game.bike_controller._rig.visible, "F gets on: faster, the gun is put away and the handlebars show")
	game.player.teleport(Vector3(outside.x + 20.0, 0.1, outside.y), 0.0)
	game.advance(0.2)
	check(w.bike.pos.distance_to(game.player.ground_pos()) < 0.5, "the bike goes where you go")
	w.player.bars.hunger = 0.0
	game.advance(0.5)
	check(not w.riding.riding() and game.player.speed_scale == 1.0, "and if you pass out you are taken off it")
	for i in 400:
		game.advance(1.0)
		if w.player.care == "":
			break
	check(game.gun.visible == gun_visible_before and not game.bike_controller._rig.visible, "and when you wake the gun is back and the handlebars are gone")


	# the shops are warm inside, and the street outside them is not
	for layout in [game.scenario.bike_shop, game.scenario.skate_shop]:
		var warm_spot: Vector2 = (layout.door as Vector2) + (layout.inward as Vector2) * 4.0
		var cold_spot: Vector2 = (layout.door as Vector2) + (layout.out as Vector2) * 4.0
		check(game.world.heating.is_warm(warm_spot) and not game.world.heating.is_warm(cold_spot), "inside the shop is warm, outside it is not")
