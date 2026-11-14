## VIEW. The money gun lying on the street, spinning slowly. Aim at it close up and press E (the
## interaction controller finds it by its `pickup` meta) and `take()` fires `taken`.
class_name GunPickupView
extends Node3D

signal taken

const MODEL := preload("res://assets/models/money_gun_world.glb")
const LAYER_MACHINE := 8

var prompt := "E   pick up the money gun"
var _model: Node3D
var _t := 0.0
var _resting := false


func _ready() -> void:
	name = "GunPickup"
	_model = Look.model(MODEL)
	_model.scale = Vector3.ONE * 2.5
	add_child(_model)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	var area := Look.pick_area(self, sphere, Vector3(0, 0.3, 0), LAYER_MACHINE, "pickup", self)
	area.name = "Pick"
	Look.label3d(self, "money gun", Vector3(0, 0.9, 0), 30, 18.0)


## Call once it has landed: it settles to hover and spin.
func rest() -> void:
	_resting = true


func _process(delta: float) -> void:
	_t += delta
	if _resting:
		_model.position.y = 0.12 + sin(_t * 2.2) * 0.04
		_model.rotation.y += delta * 0.8


func take() -> void:
	taken.emit()
	queue_free()
