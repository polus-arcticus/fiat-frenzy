## VIEW. Shared materials and small builders, so primitive props share the watercolour look.
class_name Look
extends RefCounted

static var _tints: Dictionary[Color, ShaderMaterial] = {}

const INK := Color(0.16, 0.14, 0.2)
## The player's own cash bar (in the HUD) is full at this much money: the dearest repair plus the reserve.
## (The bars over NPCs' heads are level progress now, not money; see Growth.)
const CASH_FULL := 50.0
const PAPER := Color(0.97, 0.94, 0.86, 0.94)


static func tinted(color: Color) -> ShaderMaterial:
	if not _tints.has(color):
		var m: ShaderMaterial = Watercolor.surface().duplicate()
		m.set_shader_parameter("tint", color)
		_tints[color] = m
	return _tints[color]


static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = tinted(color)
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## A squashed sphere: loaves, sacks. `size` is its full width, height and depth.
static func blob(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.scale = size
	mi.material_override = tinted(color)
	mi.position = at
	parent.add_child(mi)
	return mi


static func label3d(parent: Node3D, text: String, at: Vector3, size := 30, reach := 30.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.pixel_size = 0.00062
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.visibility_range_end = reach
	l.modulate = Color(1, 0.98, 0.92)
	l.outline_modulate = INK
	l.position = at
	parent.add_child(l)
	return l


static func model(scene: PackedScene) -> Node3D:
	var n: Node3D = scene.instantiate()
	Watercolor.apply(n)
	return n


## A thin collider on a layer so the gun's ray can find things. `meta` says what it belongs to.
static func pick_area(parent: Node3D, shape: Shape3D, at: Vector3, layer: int, meta_key: String, meta_value: Variant) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = layer
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta(meta_key, meta_value)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	a.add_child(cs)
	parent.add_child(a)
	return a


## A static collider for everything a Footprint takes up, so the player and the gun's bills run into it as
## the drones do. The shapes are in world coordinates (the body ignores its parent's transform).
static func solid_body(parent: Node3D, fp: Footprint, height := 1.2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.top_level = true
	body.collision_layer = 1
	body.collision_mask = 0
	for p in fp.parts:
		var cs := CollisionShape3D.new()
		if p.r > 0.0:
			var cyl := CylinderShape3D.new()
			cyl.radius = p.r
			cyl.height = height
			cs.shape = cyl
			cs.position = Vector3(p.c.x, height * 0.5, p.c.y)
		else:
			var bs := BoxShape3D.new()
			bs.size = Vector3(p.half.x * 2.0, height, p.half.y * 2.0)
			cs.shape = bs
			cs.position = Vector3(p.c.x, height * 0.5, p.c.y)
			cs.rotation.y = atan2(-p.ax.y, p.ax.x)
		body.add_child(cs)
	parent.add_child(body)
	return body
