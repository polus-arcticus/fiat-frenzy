## CONTROLLER (construction only). The views of the story's own set pieces, laid out by the scenario: the bank's lift and the
## room it goes to, Mr. Nobody's house, the bank's security gate, and the dressing of the two shops. (Everything
## else in the world is drawn by WorldViews.)
class_name StoryViews
extends RefCounted


static func spawn(parent: Node, world: World, scenario: Scenario) -> void:
	for ring in world.portals.all:
		if ring.kind == "lift":
			parent.add_child(LiftView.new().setup(ring))
	if not scenario.lift.is_empty():
		parent.add_child(UpgradeRoomView.new().setup(scenario.lift))
	if not scenario.sage_house.is_empty():
		parent.add_child(SageHouseView.new().setup(scenario.sage_house))
	if not scenario.ecb_gate.is_empty():
		parent.add_child(SecurityGateView.new().setup(world, scenario.ecb_gate))
	if scenario.cast.has("skate_shop"):
		parent.add_child(SkateShopView.new().setup(scenario.skate_shop, world.machine_of(scenario.cast.skate_shop)))
	if scenario.cast.has("bike_shop"):
		parent.add_child(ShopView.new().setup(scenario.bike_shop, world.machine_of(scenario.cast.bike_shop)))
