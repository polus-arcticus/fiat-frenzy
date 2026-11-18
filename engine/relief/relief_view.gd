## VIEW. The Red Cross van: a white box truck with a red cross, in town only while the model says so.
class_name ReliefView
extends Node3D

var truck: ReliefTruck
var _body: Node3D
var _label: Label3D


func setup(t: ReliefTruck, facing: float) -> ReliefView:
	truck = t
	name = "RedCrossVan"
	position = Vector3(t.pos.x, 0, t.pos.y)
	rotation.y = facing
	_body = Node3D.new()
	add_child(_body)
	var white := Color(0.96, 0.96, 0.94)
	var red := Color(0.82, 0.12, 0.14)
	Look.box(_body, Vector3(2.3, 2.3, 4.2), Vector3(0, 1.55, 0.7), white)
	Look.box(_body, Vector3(2.3, 1.5, 1.6), Vector3(0, 1.1, -2.1), white)
	Look.box(_body, Vector3(2.0, 0.7, 0.05), Vector3(0, 1.45, -2.93), Color(0.35, 0.45, 0.55))
	for side in [-1.0, 1.0]:
		Look.box(_body, Vector3(0.05, 0.9, 0.3), Vector3(side * 1.17, 1.7, 0.7), red)
		Look.box(_body, Vector3(0.05, 0.3, 0.9), Vector3(side * 1.17, 1.7, 0.7), red)
		for wz in [-1.8, 1.8]:
			Look.box(_body, Vector3(0.3, 0.8, 0.8), Vector3(side * 1.1, 0.4, wz), Color(0.15, 0.15, 0.17))
	_label = Look.label3d(self, "RED CROSS\nfree supplies", Vector3(0, 3.6, 0), 34)
	return self


func _process(_delta: float) -> void:
	visible = truck.present
