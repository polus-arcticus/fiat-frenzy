## Warm places to be indoors: the shops, Mr. Nobody's house, and the bus (while you are in it). Anyone standing inside one of
## them, the hero included, warms up, at about the rate a tent does. It does not stack: being in two at once is being in one.
## (Fires and a tent's own bed are the Needs system's; this is the rest of the warmth in the world.)
class_name Heating
extends RefCounted

const GAIN := 0.012      # warmth a second indoors: more than night cooling (1/240 a second), so you gain on it
const BUS_HALF_LENGTH := 5.5
const BUS_HALF_WIDTH := 1.25

var _w: World
var _spaces: Array[PackedVector2Array] = []


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
	var bus := _w.bus
	if bus != null:
		var along := Vector2.from_angle(bus.heading)
		var rel := p - bus.pos
		if absf(rel.dot(along)) <= BUS_HALF_LENGTH and absf(rel.dot(Vector2(-along.y, along.x))) <= BUS_HALF_WIDTH:
			return true
	return false


## Warmth a second this spot gets from being indoors.
func gain_at(p: Vector2) -> float:
	return GAIN if is_warm(p) else 0.0
