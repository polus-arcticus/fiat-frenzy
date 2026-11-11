## CONTROLLER (a query). What the hero's crosshair is on, close enough to use: a stand, someone to talk to, or something
## lying about to pick up. It only looks; it changes nothing.
class_name Aim
extends RefCounted

const STAND_RANGE := 5.0
const TALK_RANGE := 5.0
const PICKUP_RANGE := 3.5

var _player: PlayerController
var _world: World


func _init(p: PlayerController, w: World) -> void:
	_player = p
	_world = w


## The stand the crosshair is on, if it is close enough to trade with.
func machine() -> Machine:
	var hit := _ray(STAND_RANGE, GunController.LAYER_MACHINE)
	if hit.is_empty() or not hit.collider.has_meta("machine"):
		return null
	var m: Machine = hit.collider.get_meta("machine")
	return m if _world.commerce.can_reach(m) else null


## Whoever the crosshair is on, within talking distance (anyone: the caller decides who is worth talking to).
func person() -> Drone:
	var hit := _ray(TALK_RANGE, GunController.LAYER_NPC)
	return hit.collider.get_meta("drone") if not hit.is_empty() and hit.collider.has_meta("drone") else null


## Something lying about to pick up (the gun), if the crosshair is on it and it's close.
func pickup() -> GunPickupView:
	var hit := _ray(PICKUP_RANGE, GunController.LAYER_MACHINE)
	if hit.is_empty() or not hit.collider.has_meta("pickup"):
		return null
	return hit.collider.get_meta("pickup")


func _ray(reach: float, layer: int) -> Dictionary:
	var cam := _player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * reach, layer)
	q.collide_with_areas = true
	return _player.get_world_3d().direct_space_state.intersect_ray(q)
