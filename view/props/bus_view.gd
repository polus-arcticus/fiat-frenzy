## VIEW. A city bus you can get into, built from boxes: long along its local Z (the front is +Z), which
## `rotation.y` points down the road. Hollow: a floor, a roof, walls with a band of windows, rows of seats, and a
## door in the right-hand wall (the kerb side, as traffic keeps right) with two panels that slide open. It stands at
## its stop at the start; the quest controller moves it to the traffic jam. Its walls and floor are solid, and the door
## is solid while it is shut.
class_name BusView
extends Node3D

const LENGTH := 11.0
const WIDTH := 2.5
const HEIGHT := 3.0
const FLOOR := 0.35        # the top of the floor
const CEILING := 2.6       # the underside of the roof
const WALL := 0.12
const DOOR_Z := 3.6        # the doorway's middle, along the bus
const DOOR_WIDTH := 1.1
const DOOR_SIDE := -1.0    # which side of the bus (local x) the door is on: the right, facing the front
const BODY := Color(0.86, 0.78, 0.25)
const GLASS := Color(0.45, 0.58, 0.66)
const SEAT := Color(0.24, 0.3, 0.5)
const INSIDE := Color(0.82, 0.78, 0.68)
const ROWS := [-4.2, -3.0, -1.8, -0.6, 0.6, 1.8]  # where the seat rows are, along the bus

var door_open := false

var _model: Bus = null
var _loop: SimLoop = null
var _glass_material: StandardMaterial3D = null
var _solid: StaticBody3D
var _door_block: CollisionShape3D
var _panels: Array[Node3D] = []
var _tween: Tween


func setup(at: Vector2, yaw: float) -> BusView:
	name = "Bus"
	place(at, yaw)
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	add_child(_solid)
	_shell()
	_seats()
	_door()
	_exterior()
	var light := OmniLight3D.new()  # a warm light inside, so the inside is not just the daylight through the glass
	light.position = Vector3(0, CEILING - 0.3, 0)
	light.omni_range = 7.0
	light.light_energy = 0.7
	light.light_color = Color(1.0, 0.92, 0.75)
	add_child(light)
	return self


## Floor, roof, the two ends and the two walls.
func _shell() -> void:
	_part(Vector3(WIDTH, FLOOR, LENGTH), Vector3(0, FLOOR * 0.5, 0), INSIDE)                       # the floor
	_part(Vector3(WIDTH + 0.1, 0.16, LENGTH + 0.1), Vector3(0, CEILING + 0.08, 0), BODY)            # the roof
	_part(Vector3(WIDTH, CEILING - FLOOR, WALL), Vector3(0, (CEILING + FLOOR) * 0.5, -LENGTH * 0.5 + WALL * 0.5), BODY)  # the back
	_part(Vector3(WIDTH, 0.8, WALL), Vector3(0, FLOOR + 0.4, LENGTH * 0.5 - WALL * 0.5), BODY, false)  # the front: below the windscreen...
	_part(Vector3(WIDTH, 0.3, WALL), Vector3(0, CEILING - 0.15, LENGTH * 0.5 - WALL * 0.5), BODY, false)  # ...above it...
	_slab(Vector3(WIDTH, CEILING - FLOOR, WALL), Vector3(0, (CEILING + FLOOR) * 0.5, LENGTH * 0.5 - WALL * 0.5))
	_glass(Vector3(WIDTH - 0.1, CEILING - FLOOR - 1.1, 0.05), Vector3(0, FLOOR + 0.8 + (CEILING - FLOOR - 1.1) * 0.5, LENGTH * 0.5 - 0.04))  # ...the windscreen
	_part(Vector3(WIDTH - 0.2, 0.4, 0.6), Vector3(0, FLOOR + 0.5, LENGTH * 0.5 - 0.5), Color(0.18, 0.18, 0.2), false)  # the dashboard (low: you look over it from the front seat)
	_side(-DOOR_SIDE * WIDTH * 0.5, -LENGTH * 0.5, LENGTH * 0.5)                                   # the side with no door
	_side(DOOR_SIDE * WIDTH * 0.5, -LENGTH * 0.5, DOOR_Z - DOOR_WIDTH * 0.5)                       # the door side, behind the door...
	_side(DOOR_SIDE * WIDTH * 0.5, DOOR_Z + DOOR_WIDTH * 0.5, LENGTH * 0.5)                        # ...and in front of it


## A stretch of side wall from z0 to z1: a solid panel below, a band of windows, a strip above.
func _side(x: float, z0: float, z1: float) -> void:
	var len := z1 - z0
	var mid := (z0 + z1) * 0.5
	_part(Vector3(WALL, 0.75, len), Vector3(x, FLOOR + 0.375, mid), BODY, false)
	_glass(Vector3(WALL, 1.2, len), Vector3(x, FLOOR + 0.75 + 0.6, mid))
	_part(Vector3(WALL, CEILING - FLOOR - 1.95, len), Vector3(x, FLOOR + 1.95 + (CEILING - FLOOR - 1.95) * 0.5, mid), BODY, false)
	_slab(Vector3(WALL, CEILING - FLOOR, len), Vector3(x, (FLOOR + CEILING) * 0.5, mid))


func _seats() -> void:
	for z in ROWS:
		for x in [-0.85, 0.85]:
			_part(Vector3(0.5, 0.09, 0.5), Vector3(x, FLOOR + 0.45, z), SEAT, false)
			_part(Vector3(0.12, 0.45, 0.12), Vector3(x, FLOOR + 0.22, z), Color(0.15, 0.15, 0.17), false)
			_part(Vector3(0.5, 0.55, 0.08), Vector3(x, FLOOR + 0.78, z - 0.24), SEAT, false)
	for z in [-3.6, 0.0, 1.2]:  # a pole in the aisle
		_part(Vector3(0.05, CEILING - FLOOR, 0.05), Vector3(0, (CEILING + FLOOR) * 0.5, z), Color(0.7, 0.7, 0.72), false)


## The door: two panels on the wall's plane, and a block in the gap that is solid while they are shut.
func _door() -> void:
	var x := DOOR_SIDE * WIDTH * 0.5
	for k in 2:
		var panel := Node3D.new()
		panel.position = Vector3(x, 0.0, DOOR_Z + (-1.0 if k == 0 else 1.0) * DOOR_WIDTH * 0.25)
		add_child(panel)
		Look.box(panel, Vector3(0.06, 0.75, DOOR_WIDTH * 0.5), Vector3(0, FLOOR + 0.375, 0), BODY)
		Look.box(panel, Vector3(0.06, CEILING - FLOOR - 0.75, DOOR_WIDTH * 0.5 - 0.06), Vector3(0, FLOOR + 0.75 + (CEILING - FLOOR - 0.75) * 0.5, 0), GLASS)
		_panels.append(panel)
	_door_block = _slab(Vector3(WALL, CEILING - FLOOR, DOOR_WIDTH), Vector3(x, (FLOOR + CEILING) * 0.5, DOOR_Z))
	# a step up, so the doorway is not a lip
	_part(Vector3(0.7, FLOOR * 0.5, DOOR_WIDTH), Vector3(x + DOOR_SIDE * 0.35, FLOOR * 0.25, DOOR_Z), INSIDE, false)  # (not solid: it is just a lip to step over)


## Wheels, a stripe, the destination board.
func _exterior() -> void:
	var red := Color(0.78, 0.2, 0.18)  # a red stripe down each side (not across: the bus is hollow), broken by the door
	Look.box(self, Vector3(0.04, 0.18, LENGTH + 0.04), Vector3(-DOOR_SIDE * (WIDTH * 0.5 + 0.035), FLOOR + 0.5, 0), red)
	var side_x := DOOR_SIDE * (WIDTH * 0.5 + 0.035)
	var behind := DOOR_Z - DOOR_WIDTH * 0.5 + LENGTH * 0.5
	var ahead := LENGTH * 0.5 - (DOOR_Z + DOOR_WIDTH * 0.5)
	Look.box(self, Vector3(0.04, 0.18, behind), Vector3(side_x, FLOOR + 0.5, -LENGTH * 0.5 + behind * 0.5), red)
	Look.box(self, Vector3(0.04, 0.18, ahead), Vector3(side_x, FLOOR + 0.5, LENGTH * 0.5 - ahead * 0.5), red)
	for z in [-3.6, 1.9]:  # the front axle is behind the door
		for x in [-WIDTH * 0.5, WIDTH * 0.5]:
			Look.box(self, Vector3(0.3, 0.9, 0.9), Vector3(x, 0.45, z), Color(0.12, 0.12, 0.14))
	Look.box(self, Vector3(1.2, 0.35, 0.06), Vector3(0, 2.95, LENGTH * 0.5 - 0.05), Color(0.1, 0.1, 0.12))  # the destination board
	var l := Look.label3d(self, "EZB  Ostend", Vector3(0, 3.5, LENGTH * 0.5), 26, 25.0)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.fixed_size = false
	l.pixel_size = 0.004
	l.no_depth_test = false
	l.position = Vector3(0, 2.97, LENGTH * 0.5 + 0.05)


## A box of the bus; `solid` also puts a matching box in the collision body. (Walls are drawn in several pieces and
## collided as one slab: see _slab.)
func _part(size: Vector3, at: Vector3, color: Color, solid := true) -> void:
	Look.box(self, size, at, color)
	if solid:
		_slab(size, at)


func _slab(size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	_solid.add_child(shape)
	return shape


## Window glass you can see through (a pale blue tint): the hero looks out of it at the town going by.
func _glass(size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.albedo_color = Color(0.6, 0.75, 0.85, 0.22)
		_glass_material.roughness = 0.15
	mi.material_override = _glass_material
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Slide the door open or shut. Returns the tween, so a caller can `await` it.
func open_door() -> Tween:
	return _slide(true)


func close_door() -> Tween:
	return _slide(false)


func _slide(open: bool) -> Tween:
	door_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for k in 2:
		var shut_z := DOOR_Z + (-1.0 if k == 0 else 1.0) * DOOR_WIDTH * 0.25
		var open_z := shut_z + (-1.0 if k == 0 else 1.0) * DOOR_WIDTH * 0.5 * (1.0 if open else 0.0)
		var out_x := DOOR_SIDE * WIDTH * 0.5 + (DOOR_SIDE * 0.1 if open else 0.0)
		_tween.tween_property(_panels[k], "position", Vector3(out_x, 0.0, open_z if open else shut_z), 0.7)
	_door_block.set_deferred("disabled", open)
	return _tween


## Where someone stands on the pavement to get on, in the world: out from the door.
func kerb_point() -> Vector3:
	return to_global(Vector3(DOOR_SIDE * (WIDTH * 0.5 + 1.2), 0.0, DOOR_Z))


## The doorway itself, and the hero's seat (their eye is about 0.65 m above it), in the world.
func doorway_point() -> Vector3:
	return to_global(Vector3(DOOR_SIDE * 0.5, FLOOR, DOOR_Z))


## Where the hero's feet are when they sit (on the floor in front of the seat, the head lower while seated), in the bus's
## own frame and in the world.
const SEAT_LOCAL := Vector3(DOOR_SIDE * 0.85, FLOOR, ROWS[-1] + 0.12)  # on the seat, in front of its back


func seat_point() -> Vector3:
	return to_global(SEAT_LOCAL)


func place(at: Vector2, yaw: float) -> void:
	position = Vector3(at.x, 0.0, at.y)
	rotation.y = yaw


## Follow the model's bus from now on. The model moves in ticks, so the bus is drawn `loop.alpha()` of the way between
## where it was at the last tick and where it is now: that is what keeps it from moving in jumps. It updates early in
## each physics frame, before the seated hero (who rides in it) is moved to their seat.
func follow(model: Bus, loop: SimLoop = null) -> BusView:
	_model = model
	_loop = loop
	process_physics_priority = -5
	place(model.pos, _yaw_of(model.heading))
	return self


## The rotation.y that points the bus's front (+Z) along the model's heading (the angle of the way it is going).
static func _yaw_of(heading: float) -> float:
	return atan2(cos(heading), sin(heading))


func _physics_process(_delta: float) -> void:
	if _model == null:
		return
	var a := _loop.alpha() if _loop != null else 1.0
	var at := _model.prev_pos.lerp(_model.pos, a)
	position = Vector3(at.x, 0.0, at.y)
	rotation.y = _yaw_of(lerp_angle(_model.prev_heading, _model.heading, a))


## A car stuck in the jam: a body, a cabin and four wheels.
static func car(at: Vector2, yaw: float, color: Color) -> Node3D:
	var c := Node3D.new()
	c.name = "StuckCar"
	c.add_to_group("stuck_cars")
	c.position = Vector3(at.x, 0.0, at.y)
	c.rotation.y = yaw
	Look.box(c, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.65, 0), color)
	Look.box(c, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.3, -0.2), GLASS)
	Look.box(c, Vector3(1.64, 0.1, 2.3), Vector3(0, 1.62, -0.2), color.darkened(0.15))
	for z in [-1.3, 1.3]:
		for x in [-0.9, 0.9]:
			Look.box(c, Vector3(0.2, 0.6, 0.6), Vector3(x, 0.3, z), Color(0.1, 0.1, 0.12))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.6, 4.2)
	cs.shape = box
	cs.position.y = 0.8
	body.add_child(cs)
	c.add_child(body)
	return c
