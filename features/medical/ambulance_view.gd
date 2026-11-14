## VIEW. The ambulance: a white van with a red stripe and a light bar that flashes while it is out on a call.
## It follows the model's position and turns to face the way it drives.
class_name AmbulanceView
extends Node3D

var ambulance: Ambulance
var _lights: Array[MeshInstance3D] = []
var _last := Vector3.ZERO
var _t := 0.0


func setup(a: Ambulance, facing: float) -> AmbulanceView:
	ambulance = a
	name = "Ambulance"
	position = Vector3(a.pos.x, 0, a.pos.y)
	rotation.y = facing
	_last = position
	var white := Color(0.96, 0.96, 0.94)
	var red := Color(0.82, 0.12, 0.14)
	Look.box(self, Vector3(2.1, 2.1, 3.6), Vector3(0, 1.45, 0.6), white)
	Look.box(self, Vector3(2.1, 1.3, 1.4), Vector3(0, 1.0, -1.85), white)
	Look.box(self, Vector3(1.8, 0.6, 0.05), Vector3(0, 1.3, -2.56), Color(0.35, 0.45, 0.55))
	for side in [-1.0, 1.0]:
		Look.box(self, Vector3(0.05, 0.25, 4.6), Vector3(side * 1.07, 1.1, 0.2), red)
		Look.box(self, Vector3(0.05, 0.8, 0.22), Vector3(side * 1.07, 1.75, 0.8), red)
		Look.box(self, Vector3(0.05, 0.22, 0.8), Vector3(side * 1.07, 1.75, 0.8), red)
		for wz in [-1.6, 1.6]:
			Look.box(self, Vector3(0.28, 0.7, 0.7), Vector3(side * 1.0, 0.35, wz), Color(0.15, 0.15, 0.17))
	_lights.append(Look.box(self, Vector3(0.5, 0.2, 0.3), Vector3(-0.5, 2.6, -1.6), red))
	_lights.append(Look.box(self, Vector3(0.5, 0.2, 0.3), Vector3(0.5, 2.6, -1.6), Color(0.2, 0.4, 0.95)))
	Look.label3d(self, "AMBULANCE", Vector3(0, 3.4, 0), 30, 30.0)
	return self


func _process(delta: float) -> void:
	_t += delta
	var target := Vector3(ambulance.pos.x, 0, ambulance.pos.y)
	global_position = global_position.lerp(target, 1.0 - exp(-14.0 * delta))
	var moved := global_position - _last
	_last = global_position
	if moved.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-moved.x, -moved.z), 1.0 - exp(-6.0 * delta))
	var out := ambulance.job != Ambulance.Job.IDLE
	for i in _lights.size():
		var on := out and int(_t * 5.0 + i) % 2 == 0
		_lights[i].material_override = Look.tinted((Color(1.0, 0.2, 0.2) if i == 0 else Color(0.3, 0.5, 1.0)) if on else Color(0.35, 0.3, 0.3))
