## The bus: a vehicle that waits at a stop and, when the hero is aboard, drives itself along a smooth path through the
## streets to where it is going. It has no money and no needs. Transit is the system that runs it; this is its state.
##
## It moves by distance along its path (see BusPath), so position, heading and speed all change smoothly. It keeps where
## it was a tick ago as well, so a view can draw it between ticks (see BusView) instead of in jumps.
class_name Bus
extends RefCounted

enum State { AT_STOP, DRIVING, ARRIVED }

const LENGTH := 11.0   # the inside, along the bus (see BusView)
const WIDTH := 2.5

var pos := Vector2.ZERO
var heading := 0.0       # the angle of the way it is pointing
var prev_pos := Vector2.ZERO      # where it was at the last tick
var prev_heading := 0.0
var speed := 0.0
var zone := "district"
var state := State.AT_STOP
var dest := Vector2(INF, INF)
var flag := ""           # what arriving here counts as (a quest flag; see Transit.board)
var path: BusPath = null
var s := 0.0             # how far along the path it is
var aboard := false      # the hero is on it
# What it can do (the bus's are BusPath's defaults; a golf cart is slower, quicker to start and turns tighter):
var top_speed := BusPath.MAX_SPEED
var accel := BusPath.ACCEL
var brake := BusPath.BRAKE
var turn_radius := BusPath.RADIUS


func _init(at: Vector2, facing: float) -> void:
	pos = at
	heading = facing
	prev_pos = at
	prev_heading = facing


## The bus's own coordinates: x across (to the right of the way it is going, with the door on the right: negative), y along
## (the front is positive). So a thing lying on the floor keeps its (x, y) however the bus drives and turns.
func to_world(local: Vector2) -> Vector2:
	var fwd := Vector2.from_angle(heading)
	return pos + fwd * local.y + fwd.rotated(-PI * 0.5) * local.x


func to_local(world: Vector2) -> Vector2:
	var d := world - pos
	var fwd := Vector2.from_angle(heading)
	return Vector2(d.dot(fwd.rotated(-PI * 0.5)), d.dot(fwd))


## `local`, brought in to lie on the floor: not in the walls.
static func on_the_floor(local: Vector2, margin := 0.3) -> Vector2:
	return Vector2(clampf(local.x, -WIDTH * 0.5 + margin, WIDTH * 0.5 - margin), clampf(local.y, -LENGTH * 0.5 + margin, LENGTH * 0.5 - margin))
