## CONTROLLER (construction only). Makes the views for everything the starting world contains that is not the story's own
## set pieces (those are StoryViews'), and adds them to a parent node. `facing` is the yaw each thing faces, from whoever laid
## it out. Things that turn up later come through `add` (see World.arrivals). It builds and forgets: the views read the model
## themselves.
class_name WorldViews
extends RefCounted


static func spawn(parent: Node, world: World, facing: Dictionary) -> void:
	for d in world.drones:
		drone_view(parent, world, d)
	for m in world.machines:
		parent.add_child(MachineView.new().setup(m, world, facing.get(m, 0.0)))
	for fb in world.food_banks:
		parent.add_child(FoodBankView.new().setup(fb, facing.get(fb, 0.0)))
	for f in world.fires:
		parent.add_child(FireView.new().setup(f))
	for p in world.scrap_piles:
		parent.add_child(ScrapPileView.new().setup(p))
	for t in world.relief_trucks:
		parent.add_child(ReliefView.new().setup(t, facing.get(t, 0.0)))
	for h in world.hospitals:
		parent.add_child(HospitalView.new().setup(h, facing.get(h, 0.0)))
	for o in world.welfare_offices:
		parent.add_child(WelfareOfficeView.new().setup(o, world))
	for ring in world.portals.all:
		if ring.kind != "lift":  # (the bank's lift is a story set piece)
			parent.add_child(PortalView.new().setup(ring))
	for a in world.ambulances:
		parent.add_child(AmbulanceView.new().setup(a, facing.get(a, 0.0)))


## A view for one thing that turned up after the start (see World.arrivals: a block's cluster found, things a save had). It
## faces the way the model says it does (its `front`, or the way it is parked). Bills draw themselves (BillsView).
static func add(parent: Node, world: World, thing: Object) -> void:
	var yaw := func(dir: Vector2) -> float: return atan2(-dir.x, -dir.y)
	if thing is Drone:
		if thing in world.drones:
			drone_view(parent, world, thing)
	elif thing is Machine:
		parent.add_child(MachineView.new().setup(thing, world, yaw.call(thing.front)))
	elif thing is FoodBank:
		parent.add_child(FoodBankView.new().setup(thing, yaw.call(thing.front)))
	elif thing is BarrelFire:
		parent.add_child(FireView.new().setup(thing))
	elif thing is ScrapPile:
		parent.add_child(ScrapPileView.new().setup(thing))
	elif thing is ReliefTruck:
		parent.add_child(ReliefView.new().setup(thing, -(thing.heading as Vector2).angle() + PI / 2.0))
	elif thing is Hospital:
		parent.add_child(HospitalView.new().setup(thing, yaw.call(thing.front)))
	elif thing is Ambulance:
		var f: Vector2 = thing.hospital.front if thing.hospital != null else Vector2(0, 1)
		parent.add_child(AmbulanceView.new().setup(thing, yaw.call(Vector2(-f.y, f.x))))
	elif thing is WelfareOffice:
		parent.add_child(WelfareOfficeView.new().setup(thing, world))


static func drone_view(parent: Node, world: World, d: Drone) -> DroneView:
	var v := DroneView.new().setup(d, world)
	parent.add_child(v)
	return v
