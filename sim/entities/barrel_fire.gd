## A barrel fire standing in the street. Free: anyone near it warms up, much faster the closer they are
## (see Shelter for the falloff), and a cold drone can join the ring of people round it.
class_name BarrelFire
extends RefCounted

var zone := "district"
var pos := Vector2.ZERO
var shelter: Shelter
var _solid: Footprint = null


func _init(at: Vector2) -> void:
	pos = at
	shelter = Shelter.new(8, 0.02, at, true)


func solid() -> Footprint:
	if _solid == null:
		_solid = Footprint.of("fire", pos, Vector2(0, 1))
	return _solid
