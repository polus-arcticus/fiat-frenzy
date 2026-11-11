## VIEW. The player's bicycle parked in the street, where the model says it is and facing the way it was left.
## Hidden while the player is on it (the rig in their hands takes over). Appears once the bike is bought.
class_name BikeView
extends Node3D

var world: World
var _bike: Node3D


func setup(w: World) -> BikeView:
	world = w
	name = "ParkedBike"
	_bike = BikeModel.build(BikeModel.FRAMES[0])
	add_child(_bike)
	return self


func _process(_delta: float) -> void:
	var b := world.bike
	visible = b != null and not b.riding
	if b == null:
		return
	global_position = Vector3(b.pos.x, 0.0, b.pos.y)
	rotation.y = b.heading
