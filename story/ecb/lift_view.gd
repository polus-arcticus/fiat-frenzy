## VIEW. A lift in a plain steel frame with a glass-and-brushed-steel pod behind its doorway: one button, a little arrow
## lamp over the door. The doorway is a Portal (the model's); this only draws it, and keeps the pod's sides and back solid so
## the way in is through the front. Built in the portal's frame: local -Z is the way out (the front), +Z is deeper into the lift.
class_name LiftView
extends Node3D

const STEEL := Color(0.62, 0.64, 0.68)
const DARK := Color(0.24, 0.25, 0.3)
const BRASS := Color(0.85, 0.7, 0.3)
const WIDTH := 1.5   # half the inside width
const DEPTH := 2.2   # how far back the pod goes from the doorway line


func setup(p: Portal) -> LiftView:
	name = "Lift"
	position = Vector3(p.pos.x, 0.0, p.pos.y)
	rotation.y = p.exit_yaw()
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_wall(body, Vector3(0.12, 3.0, DEPTH + 0.7), Vector3(-WIDTH - 0.06, 1.5, (DEPTH - 0.7) * 0.5 + 0.0))
	_wall(body, Vector3(0.12, 3.0, DEPTH + 0.7), Vector3(WIDTH + 0.06, 1.5, (DEPTH - 0.7) * 0.5 + 0.0))
	_wall(body, Vector3(WIDTH * 2.0 + 0.24, 3.0, 0.12), Vector3(0, 1.5, DEPTH))
	Look.box(self, Vector3(WIDTH * 2.0 + 0.24, 0.05, DEPTH + 0.7), Vector3(0, 0.03, (DEPTH - 0.7) * 0.5), DARK)  # the floor of the car
	Look.box(self, Vector3(WIDTH * 2.0 + 0.5, 0.3, DEPTH + 0.9), Vector3(0, 3.15, (DEPTH - 0.7) * 0.5), STEEL)  # roof
	for sx in [-1.0, 1.0]:  # door posts, front
		Look.box(self, Vector3(0.2, 3.0, 0.2), Vector3(sx * (WIDTH + 0.1), 1.5, -0.7), STEEL)
	Look.box(self, Vector3(WIDTH * 2.0 + 0.4, 0.25, 0.22), Vector3(0, 2.9, -0.7), STEEL)  # lintel
	var lamp := Look.box(self, Vector3(0.5, 0.18, 0.05), Vector3(0, 2.9, -0.83), BRASS)
	lamp.material_override = _glow(BRASS)
	Look.box(self, Vector3(0.14, 0.34, 0.05), Vector3(WIDTH + 0.3, 1.2, -0.7), DARK)  # the one button
	var btn := Look.box(self, Vector3(0.07, 0.07, 0.04), Vector3(WIDTH + 0.3, 1.2, -0.74), BRASS)
	btn.material_override = _glow(BRASS)
	for sx in [-1.0, 1.0]:  # brushed steel panels on the walls inside
		Look.box(self, Vector3(0.04, 2.4, DEPTH - 0.4), Vector3(sx * (WIDTH - 0.03), 1.4, (DEPTH - 0.7) * 0.5 + 0.1), STEEL.lightened(0.1))
	Look.box(self, Vector3(WIDTH * 2.0 - 0.2, 2.4, 0.04), Vector3(0, 1.4, DEPTH - 0.06), STEEL.lightened(0.1))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.7, DEPTH * 0.4)
	light.omni_range = 5.0
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.95, 0.82)
	add_child(light)
	Look.label3d(self, p.label, Vector3(0, 3.7, 0), 26)
	return self


func _wall(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	Look.box(self, size, at, STEEL.darkened(0.15))


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
