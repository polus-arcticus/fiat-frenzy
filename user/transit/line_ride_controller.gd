## CONTROLLER. Riding a vehicle that runs on a line (Vehicle.run_on: a tile's train, a bus route, a tram), stop to stop. Next to
## its door the hero can board it (E, as the interaction prompt says), and it takes them to its next stop (Transit.ride); the ride
## itself is RideController's. One of these for each vehicle on a line, on any map; the story's own rides are QuestController's.
class_name LineRideController
extends Node

const BOARD_REACH := 3.6  # metres from the door's kerb point the hero may board from
const CALLED := {"train": "ride the train", "tram": "ride the tram","bus": "take the bus", "cart": "hop on the shuttle"}

var world: World
var player: PlayerController
var rides: RideController
var view: VehicleView
var model: Vehicle
## Says whether the landing has this vehicle for itself just now (Landing.held): then there is no getting on it here.
var held: Callable


func setup(w: World, p: PlayerController, r: RideController, v: VehicleView, m: Vehicle) -> LineRideController:
	world = w
	player = p
	rides = r
	view = v
	model = m
	name = "LineRider_%s" % m.name
	return self


## Can the hero get on now: it is standing on its line, they are on their feet at its door.
func boardable() -> bool:
	if model.line == null or rides.riding or model.state == Vehicle.State.DRIVING or (held.is_valid() and held.call()):
		return false
	if not world.hero.is_on_foot() or world.player.unconscious() or not player.controls_enabled:
		return false
	view.door_toward(player.global_position)
	var door := view.kerb_point()
	return player.ground_pos().distance_to(Vector2(door.x, door.z)) <= BOARD_REACH


## What the interaction prompt says about getting on ("" when they cannot).
func prompt() -> String:
	if not boardable():
		return ""
	return "E   %s to %s" % [CALLED.get(model.kind, "ride"), _called(model.line.stops[model.next_stop()])]


func board() -> void:
	if not boardable():
		return
	var next: Dictionary = model.line.stops[model.next_stop()]
	await rides.ride(view, model, func() -> bool: return world.transit.ride(model),
		"The doors close. Next stop: %s." % _called(next), "%s. Doors opening." % _called(next).capitalize(), 3.0, 2.2)


func _called(stop: Dictionary) -> String:
	var n := str(stop.get("name", ""))
	return n if n != "" else "the next stop"
