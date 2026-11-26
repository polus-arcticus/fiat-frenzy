## A vehicle the hero can ride: the bus, the bank's golf cart, a train, a tram. It waits at a stop and, when the hero is aboard,
## drives itself along a smooth path (DrivePath) to where it is going. It has no money and no needs. Transit is the system that
## runs it; this is its state.
##
## On a line (Line: a way with stops, the map's railway or a bus route), it runs stop to stop. Most kinds go round (`wraps`):
## from the last stop they run off the line's end and come on again at its start, to the first (the line leaves the map at one
## edge and comes in at the other). The others go back and forth, turning at each end. Off a line it goes where it is sent
## (Transit.board). How it drives, and how big it is, are its kind's (SPECS).
##
## It moves by distance along its path, so position, heading and speed all change smoothly. It keeps where it was a tick ago as
## well, so a view can draw it between ticks instead of in jumps.
class_name Vehicle
extends RefCounted

enum State { AT_STOP, DRIVING, ARRIVED }

## What each kind is and can do: its inside's length and width in metres (its view builds to these), top speed (metres a second
## on a straight), how fast it speeds up and brakes, how tightly it turns (corners are rounded with this), whether it goes round
## its line (`wraps`), and, going back and forth, how it turns: `uturn`, a half circle that many metres across (0: none).
const SPECS := {
	"bus": {"length": 11.0, "width": 2.5, "top": DrivePath.MAX_SPEED, "accel": DrivePath.ACCEL, "brake": DrivePath.BRAKE, "radius": DrivePath.RADIUS, "wraps": true, "uturn": 12.0},
	"cart": {"length": 5.0, "width": 2.2, "top": 7.0, "accel": 1.6, "brake": 2.2, "radius": 5.0, "wraps": false, "uturn": 9.0},  # (a golf cart: slower, quicker off the mark)
	"train": {"length": 22.0, "width": 2.5, "top": 16.0, "accel": 0.9, "brake": 1.3, "radius": 30.0, "wraps": true, "uturn": 0.0},
	"tram": {"length": 22.0, "width": 2.5, "top": 12.0, "accel": 1.1, "brake": 1.4, "radius": 14.0, "wraps": true, "uturn": 0.0},  # (it keeps to its street's curves)
}

var uid := ""  # see World.mint
var name := ""          # which it is ("bus", "shuttle", "train"): what the story and the views find it by (Transit.vehicle)
var kind := "bus"       # how it drives (SPECS)
var pos := Vector2.ZERO
var heading := 0.0       # the angle of the way it is pointing
var prev_pos := Vector2.ZERO      # where it was at the last tick
var prev_heading := 0.0
var speed := 0.0
var zone := "district"
var state := State.AT_STOP
var dest := Vector2(INF, INF)
var flag := ""           # what arriving here counts as, for whoever listens (Transit.arrived: the story's quests)
var path: DrivePath = null
var s := 0.0             # how far along the path it is
var aboard := false      # the hero is on it
var home := Vector2(INF, INF)  # where it first stood (its stop, for the beacon)
# On a line: the line (made again with the map on every build, so not saved), the stop it is at or was last at, the way it faces
# along the line (+1 toward its end), the stop it is on its way to (-1: standing), whether it goes round (its kind says, unless
# whoever laid it says otherwise), and the rest of a way that jumps from the line's end to its start (Transit.ride).
var line: Line = null
var stop := 0
var dir := 1
var going := -1
var wraps := false
var then := PackedVector2Array()


func _init(at := Vector2.ZERO, facing := 0.0, vehicle_kind := "bus") -> void:
	pos = at
	heading = facing
	prev_pos = at
	prev_heading = facing
	home = at
	kind = vehicle_kind
	wraps = SPECS[vehicle_kind].wraps


func spec() -> Dictionary:
	return SPECS[kind]


## Puts it on `on` at stop `at_stop`, facing on along the line.
func run_on(on: Line, at_stop := 0) -> void:
	line = on
	stop = at_stop
	dir = -1 if not wraps and at_stop == on.stops.size() - 1 else 1
	pos = on.stops[at_stop].at
	prev_pos = pos
	home = pos
	heading = on.heading_at(at_stop, dir)
	prev_heading = heading


## The stop it would go to from where it stands.
func next_stop() -> int:
	if wraps:
		return (stop + 1) % line.stops.size()
	var n := stop + dir
	return n if n >= 0 and n < line.stops.size() else stop - dir


## It has arrived, if it was on its way: it is at that stop now, and faces on (the other way at the end of the line).
func settle() -> void:
	if line == null or going < 0 or state == State.DRIVING:
		return
	dir = signi(going - stop) if going != stop and not wraps else dir
	stop = going
	going = -1
	if wraps or stop == 0:
		dir = 1
	elif stop == line.stops.size() - 1:
		dir = -1


## The vehicle's own coordinates: x across (to the right of the way it is going, with the door on the right: negative), y along
## (the front is positive). So a thing lying on the floor keeps its (x, y) however it drives and turns.
func to_world(local: Vector2) -> Vector2:
	var fwd := Vector2.from_angle(heading)
	return pos + fwd * local.y + fwd.rotated(-PI * 0.5) * local.x


func to_local(world: Vector2) -> Vector2:
	var d := world - pos
	var fwd := Vector2.from_angle(heading)
	return Vector2(d.dot(fwd.rotated(-PI * 0.5)), d.dot(fwd))


## `local`, brought in to lie on the floor: not in the walls.
func on_the_floor(local: Vector2, margin := 0.3) -> Vector2:
	var half := Vector2(float(spec().width), float(spec().length)) * 0.5 - Vector2(margin, margin)
	return local.clamp(-half, half)
