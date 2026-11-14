## The player's bicycle. It doesn't exist until it is bought; after that it is either parked somewhere or
## being ridden (and then it is wherever the player is).
class_name Bike
extends RefCounted

var pos := Vector2.ZERO
var heading := 0.0     # yaw, for the view to park it facing the way it was left
var riding := false


func _init(at: Vector2, yaw := 0.0) -> void:
	pos = at
	heading = yaw
