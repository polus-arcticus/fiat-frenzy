## VIEW. A low-floor tram you can get into, built from boxes: long along its local Z (a cab at each end, so it has no back),
## in three sections joined by bellows, two doorways in each side, a pantograph on the roof, its line's colour as a band along
## it and its line's number and destination on both ends. The same car draws a tile's train. Which side's doors open is whoever
## rides it (door_toward, door_to_alight). Its walls and floor are solid, and a doorway is solid while shut.
class_name TramView
extends VehicleView

const LENGTH := Vehicle.SPECS.tram.length
const WIDTH := Vehicle.SPECS.tram.width
const FLOOR := 0.32
const CEILING := 2.65
const WALL := 0.12
const DOOR_Z := 6.4          # the doorways' middles: this far either way from the middle of the car
const DOOR_WIDTH := 1.4
const JOINT_Z := 3.7         # the bellows' middles, likewise
const SILL := 0.65           # the side below the windows, from the floor
const GLASS_TO := 1.95       # the top of the windows, from the floor
const BODY := Color(0.88, 0.90, 0.91)
const SKIRT := Color(0.30, 0.33, 0.36)
const BELLOWS := Color(0.22, 0.23, 0.26)
const TRIM := Color(0.10, 0.58, 0.62)  # a line with no colour of its own
const SEAT := Color(0.20, 0.44, 0.52)
const INSIDE := Color(0.80, 0.80, 0.76)
const METAL := Color(0.62, 0.64, 0.68)
const ROWS := [-9.2, -8.0, -4.9, -2.6, -1.4, -0.2, 1.0, 2.2, 4.9, 8.0]  # where the seat rows are, along the car
const SIDES := [-1.0, 1.0]   # local x: -1 is the right, facing the front

var door_open := false
var side := -1.0             # which side's doors open, and where one gets on

var _trim := TRIM
var _glass_material: StandardMaterial3D = null
var _solid: StaticBody3D
var _door_blocks := {}   # side -> [CollisionShape3D]
var _panels := {}        # side -> [[panel, its shut z, which way it slides]]
var _tween: Tween


## `livery`: {colour (the line's), sign (its number and where it goes)}.
func setup(at: Vector2, yaw: float, livery := {}) -> TramView:
	name = "Tram"
	var colour: Color = livery.get("colour", TRIM)
	_trim = colour if colour.a > 0.0 else TRIM
	place(at, yaw)
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	_solid.set_meta(CABIN, self)
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	add_child(_solid)
	_shell()
	for s in SIDES:
		_wall(s)
		_doors(s)
	_seats()
	for end in [-1.0, 1.0]:
		_cab(end, str(livery.get("sign", "")))
	_joints()
	_roof_gear()
	for z in [-5.0, 0.0, 5.0]:  # lit inside
		var light := OmniLight3D.new()
		light.position = Vector3(0, CEILING - 0.3, z)
		light.omni_range = 5.0
		light.light_energy = 0.5
		light.light_color = Color(0.95, 0.97, 1.0)
		add_child(light)
	return self


func _shell() -> void:
	_part(Vector3(WIDTH, FLOOR, LENGTH), Vector3(0, FLOOR * 0.5, 0), INSIDE)
	_part(Vector3(WIDTH + 0.08, 0.16, LENGTH), Vector3(0, CEILING + 0.08, 0), BODY)
	for s in SIDES:  # (the line's colour along the roof's edge, outside)
		Look.box(self, Vector3(0.05, 0.12, LENGTH - 0.1), Vector3(s * (WIDTH * 0.5 + 0.06), CEILING + 0.02, 0), _trim)


## One side: stretches of wall between and beyond its two doorways, with a skirt over the wheels and the colour band.
func _wall(s: float) -> void:
	var x: float = s * WIDTH * 0.5
	var cuts := [-LENGTH * 0.5, -DOOR_Z - DOOR_WIDTH * 0.5, -DOOR_Z + DOOR_WIDTH * 0.5, DOOR_Z - DOOR_WIDTH * 0.5, DOOR_Z + DOOR_WIDTH * 0.5, LENGTH * 0.5]
	for k in [0, 2, 4]:
		var z0: float = cuts[k]
		var z1: float = cuts[k + 1]
		var length := z1 - z0
		var mid := (z0 + z1) * 0.5
		Look.box(self, Vector3(WALL, SILL, length), Vector3(x, FLOOR + SILL * 0.5, mid), BODY)
		Look.box(self, Vector3(0.03, 0.2, length), Vector3(x + s * 0.07, FLOOR + 0.45, mid), _trim)
		Look.box(self, Vector3(WALL + 0.04, 0.3, length), Vector3(x, 0.17, mid), SKIRT)
		_glass(Vector3(0.06, GLASS_TO - SILL, length), Vector3(x, FLOOR + (SILL + GLASS_TO) * 0.5, mid))
		Look.box(self, Vector3(WALL, CEILING - FLOOR - GLASS_TO, length), Vector3(x, FLOOR + GLASS_TO + (CEILING - FLOOR - GLASS_TO) * 0.5, mid), BODY)
		var post := z0
		while post <= z1 + 0.01:  # window posts
			Look.box(self, Vector3(WALL, GLASS_TO - SILL, 0.09), Vector3(x, FLOOR + (SILL + GLASS_TO) * 0.5, post), BELLOWS)
			post += length / maxf(1.0, round(length / 1.4))
		_slab(Vector3(WALL, CEILING - FLOOR, length), Vector3(x, (FLOOR + CEILING) * 0.5, mid))


func _doors(s: float) -> void:
	var x: float = s * WIDTH * 0.5
	_panels[s] = []
	_door_blocks[s] = []
	for z in [-DOOR_Z, DOOR_Z]:
		Look.box(self, Vector3(WALL, CEILING - FLOOR - 2.1, DOOR_WIDTH), Vector3(x, FLOOR + 2.1 + (CEILING - FLOOR - 2.1) * 0.5, z), BODY)
		for way in [-1.0, 1.0]:
			var panel := Node3D.new()
			panel.position = Vector3(x, 0.0, z + way * DOOR_WIDTH * 0.25)
			add_child(panel)
			Look.box(panel, Vector3(0.06, 0.35, DOOR_WIDTH * 0.5 - 0.03), Vector3(0, FLOOR + 0.18, 0), _trim)
			Look.box(panel, Vector3(0.05, 1.75, DOOR_WIDTH * 0.5 - 0.12), Vector3(0, FLOOR + 1.22, 0), Color(0.45, 0.58, 0.66))
			for edge in [-1.0, 1.0]:
				Look.box(panel, Vector3(0.07, 1.75, 0.06), Vector3(0, FLOOR + 1.22, edge * (DOOR_WIDTH * 0.25 - 0.05)), _trim)
			_panels[s].append([panel, panel.position.z, way])
		_door_blocks[s].append(_slab(Vector3(WALL, CEILING - FLOOR, DOOR_WIDTH), Vector3(x, (FLOOR + CEILING) * 0.5, z)))


func _seats() -> void:
	for z in ROWS:
		for x in [-0.85, 0.85]:
			_part(Vector3(0.5, 0.09, 0.5), Vector3(x, FLOOR + 0.45, z), SEAT, false)
			_part(Vector3(0.12, 0.45, 0.12), Vector3(x, FLOOR + 0.22, z), BELLOWS, false)
			_part(Vector3(0.5, 0.55, 0.08), Vector3(x, FLOOR + 0.78, z - 0.24), SEAT, false)
	for z in [-7.4, -5.4, 0.4, 5.4, 7.4]:
		_part(Vector3(0.05, CEILING - FLOOR, 0.05), Vector3(0, (CEILING + FLOOR) * 0.5, z), METAL, false)


## A driver's end (`end` +1 the front, -1 the other): the nose below a deep windscreen, the line on a board above it, lamps.
func _cab(end: float, sign: String) -> void:
	var z: float = end * (LENGTH * 0.5 - WALL * 0.5)
	_part(Vector3(WIDTH, 0.75, WALL), Vector3(0, FLOOR + 0.38, z), BODY, false)
	Look.box(self, Vector3(WIDTH + 0.02, 0.2, 0.03), Vector3(0, FLOOR + 0.45, z + end * 0.07), _trim)
	Look.box(self, Vector3(WIDTH, 0.3, WALL + 0.04), Vector3(0, 0.17, z), SKIRT)
	_glass(Vector3(WIDTH - 0.16, 1.3, 0.05), Vector3(0, FLOOR + 1.4, z))
	for x in [-1.0, 1.0]:
		Look.box(self, Vector3(0.09, CEILING - FLOOR, WALL), Vector3(x * (WIDTH * 0.5 - 0.05), (FLOOR + CEILING) * 0.5, z), BODY)
		Look.box(self, Vector3(0.28, 0.12, 0.05), Vector3(x * 0.8, FLOOR + 0.2, z + end * 0.07), Color(1.0, 0.95, 0.7))
	Look.box(self, Vector3(WIDTH, 0.32, WALL + 0.02), Vector3(0, CEILING - 0.16, z), Color(0.1, 0.1, 0.12))  # the board
	_slab(Vector3(WIDTH, CEILING - FLOOR, WALL), Vector3(0, (CEILING + FLOOR) * 0.5, z))
	var l := Look.label3d(self, sign, Vector3(0, CEILING - 0.16, z + end * 0.09), 26, 40.0)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.fixed_size = false
	l.pixel_size = 0.004
	l.no_depth_test = false
	l.rotation.y = 0.0 if end > 0.0 else PI
	_part(Vector3(WIDTH - 0.4, 0.4, 0.55), Vector3(0, FLOOR + 0.5, z - end * 0.45), BELLOWS, false)  # the desk


## The bellows between the sections: a dark ring round the car, ribbed.
func _joints() -> void:
	for z in [-JOINT_Z, JOINT_Z]:
		for k in 5:
			var at: float = z + (k - 2) * 0.16
			for s in SIDES:
				Look.box(self, Vector3(0.05, CEILING - 0.05, 0.09), Vector3(s * (WIDTH * 0.5 + 0.07), (CEILING + 0.05) * 0.5, at), BELLOWS)
			Look.box(self, Vector3(WIDTH + 0.19, 0.06, 0.09), Vector3(0, CEILING + 0.19, at), BELLOWS)


## Boxes of gear on the roof, and the pantograph: a folded arm up to a bar under the wire.
func _roof_gear() -> void:
	for z in [-7.5, 7.5]:
		Look.box(self, Vector3(1.7, 0.28, 3.6), Vector3(0, CEILING + 0.3, z), METAL)
	var foot := CEILING + 0.16
	Look.box(self, Vector3(0.9, 0.12, 1.1), Vector3(0, foot + 0.06, 0), SKIRT)
	Look.box(self, Vector3(0.07, 0.07, 1.5), Vector3(0, foot + 0.55, -0.25), BELLOWS, Vector3(0.62, 0, 0))
	Look.box(self, Vector3(0.07, 0.07, 1.5), Vector3(0, foot + 1.35, -0.25), BELLOWS, Vector3(-0.62, 0, 0))
	Look.box(self, Vector3(1.7, 0.07, 0.12), Vector3(0, foot + 1.8, 0.35), BELLOWS)


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


func open_door() -> Tween:
	return _slide(true)


func close_door() -> Tween:
	return _slide(false)


## Both doorways on `side` slide open, their panels parting; shutting shuts every door.
func _slide(open: bool) -> Tween:
	door_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for s in SIDES:
		var apart: bool = open and s == side
		for p in _panels[s]:
			var to := Vector3(s * (WIDTH * 0.5 + (0.1 if apart else 0.0)), 0.0, float(p[1]) + (float(p[2]) * DOOR_WIDTH * 0.5 if apart else 0.0))
			_tween.tween_property(p[0], "position", to, 0.7)
		for block in _door_blocks[s]:
			block.set_deferred("disabled", apart)
	return _tween


## The side facing `from`, while the doors are shut.
func door_toward(from: Vector3) -> void:
	if not door_open:
		side = 1.0 if to_local(from).x > 0.0 else -1.0


## The side with a raised pavement beside it (a platform), the right if both have or neither has.
func door_to_alight() -> void:
	side = -1.0
	var raised := func(s: float) -> bool:
		var p := to_global(Vector3(s * (WIDTH * 0.5 + 1.2), 0.0, DOOR_Z))
		return Ground.kerbs != null and Ground.kerbs.height_at(Vector2(p.x, p.z)) > 0.0
	if raised.call(1.0) and not raised.call(-1.0):
		side = 1.0


## Where someone stands to get on, in the world: out from the front doorway on `side`.
func kerb_point() -> Vector3:
	return to_global(Vector3(side * (WIDTH * 0.5 + 1.2), 0.0, DOOR_Z))


func doorway_point() -> Vector3:
	return to_global(Vector3(side * 0.5, FLOOR, DOOR_Z))


## The hero's seat: just behind the front doorway, on its side.
func seat_local() -> Vector3:
	return Vector3(side * 0.85, FLOOR, 4.9 + 0.12)


func floor_height() -> float:
	return FLOOR


func ceiling_height() -> float:
	return CEILING
