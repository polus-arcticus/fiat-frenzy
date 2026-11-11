## The ambulance: a vehicle that drives itself (it has no money and no needs of its own), fetches anyone who
## has collapsed and takes them to the hospital. Rescue is the system that runs it; this is just its state.
## It has the same position and route fields a Drone has, so Walking can steer it along the streets.
class_name Ambulance
extends RefCounted

enum Job { IDLE, TO_PATIENT, LOADING, TO_HOSPITAL, UNLOADING }

const SPEED := 7.0  # metres a second, about 25 km/h through a street full of stalls

var pos := Vector2.ZERO
var heading := 0.0
var route := PackedVector2Array()
var route_goal := Vector2(INF, INF)
var speed := SPEED
var hospital: Hospital
var job := Job.IDLE
var patient: Drone = null
var wait := 0.0         # seconds left of loading or unloading
var rescues := 0


func _init(from: Hospital) -> void:
	hospital = from
	pos = from.bay()
