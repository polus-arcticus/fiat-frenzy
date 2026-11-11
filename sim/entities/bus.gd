## The bus: a vehicle that waits at a stop and, when the hero is aboard, drives itself along a smooth path through the
## streets to where it is going. It has no money and no needs. Transit is the system that runs it; this is its state.
##
## It moves by distance along its path (see BusPath), so position, heading and speed all change smoothly. It keeps where
## it was a tick ago as well, so a view can draw it between ticks (see BusView) instead of in jumps.
class_name Bus
extends RefCounted

enum State { AT_STOP, DRIVING, ARRIVED }

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


func _init(at: Vector2, facing: float) -> void:
	pos = at
	heading = facing
	prev_pos = at
	prev_heading = facing
