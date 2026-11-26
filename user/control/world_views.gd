## CONTROLLER (construction only). Makes the views for everything the starting world contains that is not the story's own
## set pieces (those are StoryViews'), and adds them to a parent node. `facing` is the yaw each thing faces, from whoever laid
## it out. Things that turn up later come through `add` (see World.arrivals). It builds and forgets: the views read the model
## themselves.
class_name WorldViews
extends RefCounted


static func spawn(parent: Node, world: World, facing: Dictionary) -> void:
	for d in world.drones + world.visitors:
		drone_view(parent, world, d)
	for m in world.machines:
		parent.add_child(MachineView.new().setup(m, world, facing.get(m, _yaw(m.front))))
	for f in world.fires:
		parent.add_child(FireView.new().setup(f))
	for b in world.bins:
		parent.add_child(WasteBinView.new().setup(b))
	for t in world.relief_trucks:
		parent.add_child(ReliefView.new().setup(t, facing.get(t, 0.0)))
	for h in world.hospitals:
		parent.add_child(HospitalView.new().setup(h, facing.get(h, _yaw(h.front))))
	for o in world.bottle_depots:
		parent.add_child(BottleDepotView.new().setup(o, world))  # (it turns itself by its model's front)
	for ring in world.portals.all:
		if ring.kind != "lift":  # (the bank's lift is a story set piece)
			parent.add_child(PortalView.new().setup(ring))
	for a in world.ambulances:
		parent.add_child(AmbulanceView.new().setup(a, facing.get(a, 0.0)))


## A view for one thing that turned up after the start (see World.arrivals: a block's cluster found, things a save had). It
## faces the way the model says it does (its `front`, or the way it is parked). Bills draw themselves (BillsView).
static func add(parent: Node, world: World, thing: Object) -> void:
	if thing is Drone:
		if thing in world.drones or thing in world.visitors:
			drone_view(parent, world, thing)
	elif thing is Machine:
		parent.add_child(MachineView.new().setup(thing, world, _yaw(thing.front)))
	elif thing is BarrelFire:
		parent.add_child(FireView.new().setup(thing))
	elif thing is WasteBin:
		parent.add_child(WasteBinView.new().setup(thing))
	elif thing is ReliefTruck:
		parent.add_child(ReliefView.new().setup(thing, -(thing.heading as Vector2).angle() + PI / 2.0))
	elif thing is Hospital:
		parent.add_child(HospitalView.new().setup(thing, _yaw(thing.front)))
	elif thing is Ambulance:
		var f: Vector2 = thing.hospital.front if thing.hospital != null else Vector2(0, 1)
		parent.add_child(AmbulanceView.new().setup(thing, _yaw(Vector2(-f.y, f.x))))
	elif thing is BottleDepot:
		parent.add_child(BottleDepotView.new().setup(thing, world))


## The yaw of a view whose front is toward `dir`.
static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


static func drone_view(parent: Node, world: World, d: Drone) -> DroneView:
	var v := DroneView.new().setup(d, world)
	parent.add_child(v)
	return v
