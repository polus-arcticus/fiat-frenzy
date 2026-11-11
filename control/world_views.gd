## CONTROLLER (construction only). Makes the views for everything the starting world contains, and adds them to a
## parent node. Views that turn up later (the bankers) come through `drone_view`. It builds and forgets: the views
## read the model themselves.
class_name WorldViews
extends RefCounted


static func spawn(parent: Node, world: World, scenario: Scenario) -> void:
	for d in world.drones:
		drone_view(parent, world, d)
	for m in world.machines:
		parent.add_child(MachineView.new().setup(m, world, scenario.facing.get(m, 0.0)))
	for fb in world.food_banks:
		parent.add_child(FoodBankView.new().setup(fb, scenario.facing.get(fb, 0.0)))
	for f in world.fires:
		parent.add_child(FireView.new().setup(f))
	for t in world.relief_trucks:
		parent.add_child(ReliefView.new().setup(t, scenario.facing.get(t, 0.0)))
	for h in world.hospitals:
		parent.add_child(HospitalView.new().setup(h, scenario.facing.get(h, 0.0)))
	for ring in world.portals.all:
		parent.add_child(PortalView.new().setup(ring))
	for a in world.ambulances:
		parent.add_child(AmbulanceView.new().setup(a, scenario.facing.get(a, 0.0)))
	if not scenario.sage_house.is_empty():
		parent.add_child(SageHouseView.new().setup(scenario.sage_house))
	if scenario.cast.has("skate_shop"):
		parent.add_child(SkateShopView.new().setup(scenario.skate_shop, world.machine_of(scenario.cast.skate_shop)))
	if scenario.cast.has("bike_shop"):
		parent.add_child(ShopView.new().setup(scenario.bike_shop, world.machine_of(scenario.cast.bike_shop)))


static func drone_view(parent: Node, world: World, d: Drone) -> DroneView:
	var v := DroneView.new().setup(d, world)
	parent.add_child(v)
	return v
