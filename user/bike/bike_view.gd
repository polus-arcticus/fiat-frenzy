## VIEW. The bike under the hero, seen from behind (third person) while they ride it. In first person the handlebars in their
## hands (BikeRig) are the bike; off it, the bike is in their loadout and not drawn.
class_name BikeView
extends Node3D

var world: World
var _bike: Node3D


func setup(w: World) -> BikeView:
	world = w
	name = "RiddenBike"
	_bike = BikeModel.build(BikeModel.FRAMES[0])
	add_child(_bike)
	return self


func _process(_delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player")
	visible = world.riding.riding() and me != null and me.third_person
	if visible:
		global_position = Vector3(world.player.pos.x, 0.0, world.player.pos.y)
		rotation.y = me.rotation.y
