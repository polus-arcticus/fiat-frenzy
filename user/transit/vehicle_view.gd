## VIEW. What anything that drives has in common: it follows its model (a Vehicle: the bus, the shuttle, a train alike), drawn
## between the sim's ticks so it never moves in jumps, and it is what the hero rides in. Subclasses build the body, and say where
## to stand to get on (`kerb_point`, `doorway_point`) and where to sit (`seat_local`).
class_name VehicleView
extends Node3D

const CABIN := "cabin"  # the group of every vehicle's view; "cabin_<name>" is one vehicle's

var _model: Vehicle = null
var _loop: SimLoop = null
## Rides the land (Ground.land) where it goes, not at a fixed height: a train's way crosses a tile's hills. (The bus drives the
## story's flat Frankfurt, and stays at 0.)
var on_ground := false


func place(at: Vector2, yaw: float) -> void:
	position = Vector3(at.x, Ground.land(at) if on_ground else 0.0, at.y)
	rotation.y = yaw


## Follow the model from now on. The model moves in ticks, so the vehicle is drawn `loop.alpha()` of the way between where it
## was at the last tick and where it is now: that is what keeps it from moving in jumps. It updates early in each physics
## frame, before the seated hero (who rides in it) is moved to their seat.
func follow(model: Vehicle, loop: SimLoop = null) -> void:
	_model = model
	_loop = loop
	add_to_group(CABIN)
	add_to_group(CABIN + "_" + model.name)  # (what flies or lies inside finds it: PaperProjectile, BillsView)
	process_physics_priority = -5
	place(model.pos, _yaw_of(model.heading))


## The rotation.y that points the vehicle's front (+Z) along the model's heading (the angle of the way it is going).
static func _yaw_of(heading: float) -> float:
	return atan2(cos(heading), sin(heading))


## How fast it is going, as a vector in the world (zero when it has no model, or is standing).
func velocity() -> Vector3:
	return global_basis * Vector3(0, 0, 1) * _model.speed if _model != null else Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if _model == null:
		return
	var a := _loop.alpha() if _loop != null else 1.0
	var at := _model.prev_pos.lerp(_model.pos, a)
	position = Vector3(at.x, Ground.land(at) if on_ground else 0.0, at.y)
	rotation.y = _yaw_of(lerp_angle(_model.prev_heading, _model.heading, a))


## The vehicle it draws (null before `follow`).
func model() -> Vehicle:
	return _model


# What a rider needs (each kind of view says):

## The top and underside of what can be stood in: its floor and ceiling, in its own frame.
func floor_height() -> float:
	return 0.0


func ceiling_height() -> float:
	return 2.4


## With doors on both sides, take the one facing someone at `from` (getting on)...
func door_toward(_from: Vector3) -> void:
	pass


## ...and the one to get off by, where it has stopped.
func door_to_alight() -> void:
	pass


## Where the hero's feet are when they sit, in the vehicle's own frame.
func seat_local() -> Vector3:
	return Vector3.ZERO


func seat_point() -> Vector3:
	return to_global(seat_local())


## Where to stand, outside, to get on; and the way in.
func kerb_point() -> Vector3:
	return global_position


func doorway_point() -> Vector3:
	return global_position


func open_door() -> Tween:
	return null


func close_door() -> Tween:
	return null
