## VIEW. A free barrel fire in the street, with a flickering light.
class_name FireView
extends Node3D

const BARREL := preload("res://assets/models/fire_barrel.glb")

var fire: BarrelFire
var _light: OmniLight3D


func setup(f: BarrelFire) -> FireView:
	fire = f
	name = "BarrelFire"
	position = Vector3(f.pos.x, 0, f.pos.y)
	add_child(Look.model(BARREL))
	Look.solid_body(self, f.solid(), 1.0)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.3, 0)
	_light.omni_range = 10.0
	_light.light_color = Color(1.0, 0.6, 0.3)
	add_child(_light)
	Look.label3d(self, "free fire", Vector3(0, 2.4, 0), 26)
	return self


func _process(_delta: float) -> void:
	_light.light_energy = 2.2 + sin(Time.get_ticks_msec() * 0.013) * 0.5 + sin(Time.get_ticks_msec() * 0.031) * 0.25
