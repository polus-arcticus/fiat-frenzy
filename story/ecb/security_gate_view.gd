## VIEW. The European Central Bank's security gate, from the layout in SecurityGate: a guard's glass booth, a red-and-white boom
## barrier and a sliding steel gate across the vehicle way in, a turnstile for people on foot, bollards and big concrete blocks
## along the frontage, and four flagpoles flying the EU's blue. The barrier lifts and the gate slides open when the model says the
## gate is open (it is then no longer solid); closed, everything here is solid, so no one walks through it.
class_name SecurityGateView
extends Node3D

const STEEL := Color(0.3, 0.32, 0.36)
const LIGHT_STEEL := Color(0.58, 0.6, 0.64)
const CONCRETE := Color(0.72, 0.71, 0.68)
const GLASS_TINT := Color(0.6, 0.75, 0.85, 0.25)
const RED := Color(0.82, 0.16, 0.14)
const WHITE := Color(0.95, 0.95, 0.92)
const EU_BLUE := Color(0.1, 0.25, 0.6)
const EU_GOLD := Color(1.0, 0.82, 0.1)
const ARM_LENGTH := 7.0
const OPEN_TIME := 1.4
const SLIDE_TIME := 3.0

var world: World
var is_open := false

var _solid: StaticBody3D
var _barrier: Node3D
var _barrier_shape: CollisionShape3D
var _panels: Array[Node3D] = []
var _panel_shapes: Array[CollisionShape3D] = []
var _glass_material: StandardMaterial3D
var _tween: Tween


func setup(w: World, plan: Dictionary) -> SecurityGateView:
	world = w
	name = "SecurityGate"
	position = Vector3(plan.origin.x, 0.0, plan.origin.y)
	rotation.y = plan.yaw
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	add_child(_solid)
	_booth()
	_barrier_arm()
	_sliding_gate()
	_turnstile()
	for u in SecurityGate.BOLLARDS_U:
		_box(Vector3(0.24, 0.95, 0.24), Vector3(u, 0.475, SecurityGate.BOLLARDS_V), LIGHT_STEEL, true)
		_box(Vector3(0.26, 0.08, 0.26), Vector3(u, 0.85, SecurityGate.BOLLARDS_V), RED)
	for b in SecurityGate.BLOCKS:
		_box(Vector3(b.u1 - b.u0, b.height, b.depth), Vector3((b.u0 + b.u1) * 0.5, b.height * 0.5, b.v), CONCRETE, true)
	for p in SecurityGate.FLAG_POLES:
		_flag(p[0], p[1])
	return self


func _process(_delta: float) -> void:
	var want := SecurityGate.is_open(world)
	if want != is_open:
		is_open = want
		_animate(want)


## Opens or closes the barrier and the gate. (Open, neither is solid.)
func _animate(open: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_barrier, "rotation:z", deg_to_rad(82.0) if open else 0.0, OPEN_TIME)
	for k in _panels.size():
		var slide: float = (-1.0 if k == 0 else 1.0) * (SecurityGate.DRIVE_U1 - SecurityGate.DRIVE_U0) * 0.5
		var closed_u: float = SecurityGate.DRIVE_U0 + (SecurityGate.DRIVE_U1 - SecurityGate.DRIVE_U0) * (0.25 if k == 0 else 0.75)
		_tween.tween_property(_panels[k], "position:x", closed_u + (slide if open else 0.0), SLIDE_TIME)
	if open:
		_tween.chain().tween_callback(_set_solid.bind(false))
	else:
		_set_solid(true)


func _set_solid(on: bool) -> void:
	_barrier_shape.set_deferred("disabled", not on)
	for s in _panel_shapes:
		s.set_deferred("disabled", not on)


# ---------------------------------------------------------------- the pieces

func _booth() -> void:
	var c: Vector2 = SecurityGate.BOOTH
	var sz: Vector2 = SecurityGate.BOOTH_SIZE
	_box(Vector3(sz.x, 1.0, sz.y), Vector3(c.x, 0.5, c.y), Color(0.55, 0.57, 0.6), true)                  # the lower walls
	_box(Vector3(sz.x, 1.5, 0.1), Vector3(c.x, 1.75, c.y + sz.y * 0.5 - 0.05), Color(0.5, 0.52, 0.56))     # the solid back
	for x in [-1.0, 1.0]:  # corner posts
		for z in [-1.0, 1.0]:
			_box(Vector3(0.1, 1.55, 0.1), Vector3(c.x + x * (sz.x * 0.5 - 0.05), 1.775, c.y + z * (sz.y * 0.5 - 0.05)), STEEL)
	_glass(Vector3(sz.x - 0.2, 1.4, 0.04), Vector3(c.x, 1.75, c.y - sz.y * 0.5 + 0.02))                    # glass: the street side...
	_glass(Vector3(0.04, 1.4, sz.y - 0.2), Vector3(c.x + sz.x * 0.5 - 0.02, 1.75, c.y))                    # ...the drive side...
	_glass(Vector3(0.04, 1.4, sz.y - 0.2), Vector3(c.x - sz.x * 0.5 + 0.02, 1.75, c.y))                    # ...and the other
	_box(Vector3(sz.x + 0.6, 0.14, sz.y + 0.6), Vector3(c.x, 2.55, c.y), Color(0.25, 0.27, 0.3))          # the roof, over-hanging
	var sign := Look.label3d(self, "SECURITY", Vector3(c.x, 3.5, c.y - sz.y * 0.5 - 0.1), 34, 40.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_box(Vector3(0.9, 0.5, 0.5), Vector3(c.x, 1.2, c.y - 0.4), Color(0.62, 0.55, 0.45))                    # a desk inside


func _barrier_arm() -> void:
	var v: float = SecurityGate.BARRIER_V
	var u0: float = SecurityGate.DRIVE_U0
	_box(Vector3(0.45, 1.0, 0.45), Vector3(u0 - 0.35, 0.5, v), Color(0.88, 0.78, 0.18), true)              # the post it turns on
	_barrier = Node3D.new()
	_barrier.name = "BoomBarrier"
	_barrier.position = Vector3(u0 - 0.2, 0.95, v)
	add_child(_barrier)
	var segments := 7
	for k in segments:  # red and white stripes
		Look.box(_barrier, Vector3(ARM_LENGTH / segments, 0.12, 0.1), Vector3((k + 0.5) * ARM_LENGTH / segments, 0.0, 0.0), RED if k % 2 == 0 else WHITE)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARM_LENGTH, 0.4, 0.2)
	shape.shape = box
	shape.position = Vector3(u0 - 0.2 + ARM_LENGTH * 0.5, 0.95, v)
	_solid.add_child(shape)
	_barrier_shape = shape


func _sliding_gate() -> void:
	var v: float = SecurityGate.GATE_V
	var u0: float = SecurityGate.DRIVE_U0
	var u1: float = SecurityGate.DRIVE_U1
	for u in [u0 - 0.2, u1 + 0.2]:
		_box(Vector3(0.35, 2.5, 0.35), Vector3(u, 1.25, v), STEEL, true)
	var width := (u1 - u0) * 0.5
	for k in 2:
		var panel := Node3D.new()
		panel.name = "GatePanel%d" % k
		panel.position = Vector3(u0 + (u1 - u0) * (0.25 if k == 0 else 0.75), 0.0, v + 0.3)  # (on a rail, a little inside the posts)
		add_child(panel)
		Look.box(panel, Vector3(width, 0.1, 0.12), Vector3(0, 0.15, 0), STEEL)
		Look.box(panel, Vector3(width, 0.1, 0.12), Vector3(0, 2.0, 0), STEEL)
		for x in [-width * 0.5 + 0.05, width * 0.5 - 0.05]:
			Look.box(panel, Vector3(0.1, 2.0, 0.12), Vector3(x, 1.1, 0), STEEL)
		for h in [0.5, 0.9, 1.3, 1.7]:  # the bars
			Look.box(panel, Vector3(width - 0.1, 0.07, 0.08), Vector3(0, h, 0), LIGHT_STEEL)
		_panels.append(panel)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 2.0, 0.3)
		shape.shape = box
		shape.position = Vector3(panel.position.x, 1.1, panel.position.z)  # (where the panel stands, shut: they are turned off while it is open)
		_solid.add_child(shape)
		_panel_shapes.append(shape)


func _turnstile() -> void:
	var t: Vector2 = SecurityGate.TURNSTILE
	for z in [-0.6, 0.6]:
		_box(Vector3(0.14, 1.0, 0.14), Vector3(t.x, 0.5, t.y + z), STEEL, true)
	_box(Vector3(0.1, 0.08, 1.3), Vector3(t.x, 1.0, t.y), STEEL)
	_box(Vector3(0.12, 0.95, 0.12), Vector3(t.x, 0.5, t.y), STEEL)  # the hub
	for k in 3:  # three arms
		var a := TAU * k / 3.0
		Look.box(self, Vector3(0.6, 0.04, 0.04), Vector3(t.x + cos(a) * 0.3, 0.95, t.y + sin(a) * 0.3), LIGHT_STEEL, Vector3(0.0, -a, 0.0))


func _flag(u: float, v: float) -> void:
	_box(Vector3(0.09, 9.0, 0.09), Vector3(u, 4.5, v), LIGHT_STEEL)
	var cloth := _box(Vector3(2.0, 1.3, 0.03), Vector3(u + 1.1, 8.0, v), EU_BLUE)
	cloth.rotation.z = -0.05
	for k in 12:  # the ring of twelve gold stars
		var a := TAU * k / 12.0
		_box(Vector3(0.1, 0.1, 0.04), Vector3(u + 1.1 + cos(a) * 0.42, 8.0 + sin(a) * 0.42, v), EU_GOLD)


## A box; `solid` also gives it collision.
func _box(size: Vector3, at: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mi := Look.box(self, size, at, color)
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		_solid.add_child(shape)
	return mi


func _glass(size: Vector3, at: Vector3) -> void:
	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.albedo_color = GLASS_TINT
		_glass_material.roughness = 0.15
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _glass_material
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
