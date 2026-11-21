## Getting on and off a bike, and what riding does: you go about two and a half times as fast (an old bike from a bike camp,
## less), and can't jump. The bike is in the hero's loadout (see Loadout), so they get on wherever they stand (awake, and not
## on something else); getting off puts it away again.
class_name Riding
extends RefCounted

const RIDE_FACTOR := 2.4   # how much faster than walking, on a shop's bike

var _w: World


func _init(world: World) -> void:
	_w = world


func riding() -> bool:
	return _w.hero.mode == Hero.Mode.RIDING


## The bike the hero would ride: the best in their loadout, or "".
func bike() -> String:
	return _w.loadout.ride("vehicle") if _w.player != null else ""


## How many times faster than walking the player moves.
func speed_factor() -> float:
	if not riding() or bike() == "":
		return 1.0
	return lerpf(1.0, RIDE_FACTOR, Catalog.item(bike()).speed)  # (an old bike from a bike camp is slower)


## Returns {ok, text}.
func mount() -> Dictionary:
	if bike() == "":
		return _no("You don't have a bike in your loadout.")
	var why := _w.hero.why_not(Hero.Mode.RIDING)
	if why != "":
		return _no(why)
	_w.hero.enter(Hero.Mode.RIDING)
	return {"ok": true, "text": "You get on the %s." % bike().replace("_", " ")}


## Returns {ok, text}.
func dismount() -> Dictionary:
	if not riding():
		return _no("You're not on a bike.")
	_w.hero.stand()
	return {"ok": true, "text": "You get off and wheel the bike along with you."}


func _no(text: String) -> Dictionary:
	return {"ok": false, "text": text}
