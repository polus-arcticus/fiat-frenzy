## Getting on and off the bicycle, and what riding does: you go about two and a half times as fast, and can't
## jump. You can only get on when you are standing by it (and awake); getting off parks it where you stand.
class_name Riding
extends RefCounted

const MOUNT_REACH := 3.0   # how close the player must be to the parked bike to get on
const RIDE_FACTOR := 2.4   # how much faster than walking

var _w: World


func _init(world: World) -> void:
	_w = world


func riding() -> bool:
	return _w.hero.mode == Hero.Mode.RIDING


## How many times faster than walking the player moves.
func speed_factor() -> float:
	return RIDE_FACTOR if riding() else 1.0


## Returns {ok, text}.
func mount() -> Dictionary:
	if _w.bike == null:
		return _no("You don't have a bike.")
	var why := _w.hero.why_not(Hero.Mode.RIDING)
	if why != "":
		return _no(why)
	if _w.player.pos.distance_to(_w.bike.pos) > MOUNT_REACH:
		return _no("Your bike is too far away.")
	_w.hero.enter(Hero.Mode.RIDING)
	_w.bike.pos = _w.player.pos
	return {"ok": true, "text": "You get on the bike."}


## Gets off where the player stands, leaving the bike facing `yaw`. Returns {ok, text}.
func dismount(yaw := 0.0) -> Dictionary:
	if not riding():
		return _no("You're not on a bike.")
	_w.hero.stand()
	_w.bike.pos = _w.player.pos
	_w.bike.heading = yaw
	return {"ok": true, "text": "You get off and leave the bike here."}


## While riding, the bike is wherever the player is.
func follow_player() -> void:
	if riding():
		_w.bike.pos = _w.player.pos


func _no(text: String) -> Dictionary:
	return {"ok": false, "text": text}
