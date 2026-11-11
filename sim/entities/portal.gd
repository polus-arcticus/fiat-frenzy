## One end of a teleporter: an upright ring standing on the ground. Walk through it and you come out of its
## twin, a few metres clear of it, facing away.
class_name Portal
extends RefCounted

const HALF_WIDTH := 1.1   # across the ring: the opening
const HALF_DEPTH := 0.6   # through the ring: how thick the doorway is, so a fast bike can't skip over it
const EXIT_DISTANCE := 2.5  # where you come out, in front of the ring (past its doorway, so you don't go straight back)

var zone := "district"
var pos := Vector2.ZERO
var normal := Vector2(0, 1)  # unit vector through the ring's opening; you come out on this side
var label := ""
var twin: Portal = null


func _init(at: Vector2, facing: Vector2, name := "") -> void:
	pos = at
	normal = facing.normalized()
	label = name


## Whether a walker at `p` is standing in the doorway.
func contains(p: Vector2) -> bool:
	var rel := p - pos
	var across := Vector2(-normal.y, normal.x)
	return absf(rel.dot(normal)) < HALF_DEPTH and absf(rel.dot(across)) < HALF_WIDTH


## Where you appear if you come out of this ring.
func exit_point() -> Vector2:
	return pos + normal * EXIT_DISTANCE


## The yaw (as the player body and camera use it) that looks along `normal`.
func exit_yaw() -> float:
	return atan2(-normal.x, -normal.y)
