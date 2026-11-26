## Warm places to be indoors: the shops, Mr. Nobody's house, and a vehicle (while you are in it). Anyone standing inside one of
## them, the hero included, warms up, at about the rate a tent does. It does not stack: being in two at once is being in one.
## (Fires and a tent's own bed are the Needs system's; this is the rest of the warmth in the world.)
class_name Heating
extends RefCounted

const GAIN := 0.012      # warmth a second indoors: more than night cooling (1/240 a second), so you gain on it

var _w: World
var _spaces: Array[PackedVector2Array] = []
## Warm vehicles: every vehicle, told by Transit.add, each as big as its kind (Vehicle.SPECS).
var vehicles: Array[Vehicle] = []


func _init(world: World) -> void:
	_w = world


## A building people can go inside (its outline).
func add_building(outline: PackedVector2Array) -> void:
	_spaces.append(outline)


## Is this spot indoors in a warm place?
func is_warm(p: Vector2) -> bool:
	for s in _spaces:
		if Geometry2D.is_point_in_polygon(p, s):
			return true
	for v in vehicles:
		var local := v.to_local(p)
		if absf(local.x) <= float(v.spec().width) * 0.5 and absf(local.y) <= float(v.spec().length) * 0.5:
			return true
	return false


## Warmth a second this spot gets from being indoors.
func gain_at(p: Vector2) -> float:
	return GAIN if is_warm(p) else 0.0
