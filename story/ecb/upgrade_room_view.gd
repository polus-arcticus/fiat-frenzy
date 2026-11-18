## VIEW. The instrument room upstairs at the bank: a long low office with a brass lamp on every desk and no window. A big workbench
## with a padded, hand-shaped cradle in the middle of it (the bench: not in service yet), a rack of drawers, a pneumatic tube,
## a wall clock that has stopped, and a sign that says what the room is for in the way a form would. It stands far off the map,
## in a zone of its own (Scenario.LIFT_ZONE), and is entered only by the lift. The people in it are the model's.
class_name UpgradeRoomView
extends Node3D

const FLOOR := Color(0.42, 0.36, 0.3)
const WALL := Color(0.74, 0.7, 0.62)
const PANEL := Color(0.36, 0.28, 0.22)
const BRASS := Color(0.85, 0.7, 0.3)
const HEIGHT := 3.4


func setup(room: Dictionary) -> UpgradeRoomView:
	name = "UpgradeRoom"
	var c: Vector2 = room.centre
	var h: Vector2 = room.half
	position = Vector3(c.x, 0.0, c.y)
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_solid(body, Vector3(h.x * 2.0 + 2.0, 0.4, h.y * 2.0 + 2.0), Vector3(0, -0.2, 0), FLOOR)  # floor
	_solid(body, Vector3(h.x * 2.0 + 1.0, 0.3, h.y * 2.0 + 1.0), Vector3(0, HEIGHT + 0.15, 0), WALL.darkened(0.1))  # ceiling
	_solid(body, Vector3(0.4, HEIGHT, h.y * 2.0 + 0.8), Vector3(-h.x - 0.2, HEIGHT * 0.5, 0), WALL)
	_solid(body, Vector3(0.4, HEIGHT, h.y * 2.0 + 0.8), Vector3(h.x + 0.2, HEIGHT * 0.5, 0), WALL)
	_solid(body, Vector3(h.x * 2.0 + 0.8, HEIGHT, 0.4), Vector3(0, HEIGHT * 0.5, -h.y - 0.2), WALL)
	_solid(body, Vector3(h.x * 2.0 + 0.8, HEIGHT, 0.4), Vector3(0, HEIGHT * 0.5, h.y + 0.2), WALL)
	Look.box(self, Vector3(h.x * 2.0, 1.1, 0.06), Vector3(0, 0.55, -h.y + 0.04), PANEL)  # wainscot on the back wall
	Look.box(self, Vector3(h.x * 2.0, 0.08, 4.0), Vector3(0, 0.05, -h.y + 4.0), Color(0.5, 0.18, 0.2))  # a long runner rug
	_bench(Vector3(1.8, 0.0, -h.y + 3.4))
	_drawers(Vector3(-h.x + 0.5, 0.0, 0.0))
	_drawers(Vector3(-h.x + 0.5, 0.0, -3.4))
	_tube(Vector3(h.x - 1.0, 0.0, -2.0))
	_clock(Vector3(0, 2.6, -h.y + 0.12))
	_sign(Vector3(0, 2.0, -h.y + 0.1))
	for spot in [Vector3(-4, 3.0, -2), Vector3(3, 3.0, -2), Vector3(0, 3.0, 3)]:
		var l := OmniLight3D.new()
		l.position = spot
		l.omni_range = 11.0
		l.light_energy = 1.0
		l.light_color = Color(1.0, 0.9, 0.7)
		add_child(l)
	return self


func _solid(body: StaticBody3D, size: Vector3, at: Vector3, color: Color) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	Look.box(self, size, at, color)


## The workbench: a long top on trestles, with a padded cradle in the shape of something held in a hand (never named), a lamp over
## it, and rows of small tools. It does nothing yet.
func _bench(at: Vector3) -> void:
	var b := Node3D.new()
	b.position = at
	add_child(b)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	b.add_child(body)
	_solid_local(body, Vector3(3.6, 0.95, 1.3), Vector3(0, 0.475, 0))
	Look.box(b, Vector3(3.8, 0.1, 1.5), Vector3(0, 0.98, 0), PANEL)
	Look.box(b, Vector3(1.4, 0.06, 0.6), Vector3(0, 1.06, 0), Color(0.18, 0.2, 0.34))   # the cradle's pad
	Look.box(b, Vector3(0.5, 0.05, 0.22), Vector3(-0.2, 1.1, 0), Color(0.3, 0.32, 0.5))
	Look.box(b, Vector3(0.18, 0.05, 0.42), Vector3(0.35, 1.1, 0), Color(0.3, 0.32, 0.5))
	for i in 6:  # small tools, laid out in a row
		Look.box(b, Vector3(0.05, 0.03, 0.3), Vector3(-1.6 + i * 0.22, 1.05, 0.5), Color(0.7, 0.72, 0.76))
	Look.box(b, Vector3(0.05, 1.2, 0.05), Vector3(0, 2.0, 0.55), Color(0.2, 0.2, 0.24))
	var shade := Look.box(b, Vector3(0.6, 0.14, 0.4), Vector3(0, 2.65, 0.4), Color(0.2, 0.3, 0.24))
	shade.rotation.x = 0.3
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, 0.2)
	lamp.omni_range = 6.0
	lamp.light_energy = 1.4
	lamp.light_color = Color(1.0, 0.85, 0.55)
	b.add_child(lamp)
	Look.label3d(b, "Bench (not in service)", Vector3(0, 1.45, 0.9), 22, 8.0)


func _solid_local(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)


func _drawers(at: Vector3) -> void:
	var d := Node3D.new()
	d.position = at
	add_child(d)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	d.add_child(body)
	_solid_local(body, Vector3(0.9, 2.0, 2.8), Vector3(0, 1.0, 0))
	Look.box(d, Vector3(0.9, 2.0, 2.8), Vector3(0, 1.0, 0), PANEL.lightened(0.05))
	for row in 6:
		for col in 3:
			Look.box(d, Vector3(0.04, 0.26, 0.8), Vector3(0.46, 0.2 + row * 0.32, -0.9 + col * 0.9), PANEL.darkened(0.2))
			Look.box(d, Vector3(0.05, 0.05, 0.14), Vector3(0.49, 0.2 + row * 0.32, -0.9 + col * 0.9), BRASS)


func _tube(at: Vector3) -> void:
	var t := Node3D.new()
	t.position = at
	add_child(t)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.14
	cm.height = HEIGHT
	cyl.mesh = cm
	cyl.material_override = Look.tinted(BRASS.darkened(0.15))
	cyl.position.y = HEIGHT * 0.5
	t.add_child(cyl)
	Look.box(t, Vector3(0.5, 0.4, 0.5), Vector3(0, 1.4, 0), BRASS.darkened(0.3))  # the hatch where the canisters land


func _clock(at: Vector3) -> void:
	var c := Node3D.new()
	c.position = at
	add_child(c)
	Look.box(c, Vector3(0.7, 0.7, 0.06), Vector3.ZERO, Color(0.95, 0.93, 0.86))
	Look.box(c, Vector3(0.05, 0.28, 0.02), Vector3(0, 0.12, 0.04), Color(0.1, 0.1, 0.12))
	Look.box(c, Vector3(0.2, 0.05, 0.02), Vector3(0.08, 0.0, 0.04), Color(0.1, 0.1, 0.12), Vector3(0, 0, 0.4))


func _sign(at: Vector3) -> void:
	Look.box(self, Vector3(3.6, 0.5, 0.05), at, Color(0.14, 0.17, 0.26))
	var l := Label3D.new()
	l.text = "DEPARTMENT OF INSTRUMENT MAINTENANCE\nPlease do not ask whose."
	l.font_size = 40
	l.pixel_size = 0.0036
	l.modulate = Color(0.95, 0.9, 0.7)
	l.position = at + Vector3(0, 0, 0.04)
	add_child(l)
