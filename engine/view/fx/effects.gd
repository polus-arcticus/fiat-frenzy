## VIEW. One-off particle effects from CPUParticles3D (cheap, and they work on every renderer): a smoke
## column for the helicopter's trail and wreck, and a burst for dust and sparks on impact.
class_name Effects
extends RefCounted

static var _mats := {}


static func _mat(unshaded: bool) -> StandardMaterial3D:
	if not _mats.has(unshaded):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.roughness = 1.0
		_mats[unshaded] = m
	return _mats[unshaded]


static func _particles(radius: float, unshaded: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _mat(unshaded)
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _ramp(colors: Array[Color]) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / (colors.size() - 1))
	g.offsets = offs
	return g


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 1.6))
	return c


## A continuous smoke column that follows `parent` (the helicopter's trail, then the wreck).
static func smoke(parent: Node, local_pos: Vector3, amount := 60) -> CPUParticles3D:
	var p := _particles(0.6, false)
	p.amount = amount
	p.lifetime = 4.0
	p.position = local_pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.6, 1.2, 0.0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.scale_amount_curve = _grow_curve()
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color_ramp = _ramp([Color(0.25, 0.24, 0.26, 0.85), Color(0.45, 0.44, 0.47, 0.5), Color(0.7, 0.7, 0.72, 0.0)])
	parent.add_child(p)
	return p


## A one-shot puff: dust on impact, sparks. `colors` runs from the colour at birth to the colour at death.
static func burst(parent: Node, world_pos: Vector3, colors: Array[Color], amount := 30, speed := 4.0,
		size := 0.12, lifetime := 1.0) -> void:
	var p := _particles(size, true)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -3.0, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_curve = _grow_curve()
	p.color_ramp = _ramp(colors)
	parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.finished.connect(p.queue_free)
