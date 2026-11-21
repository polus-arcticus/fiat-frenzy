## The hero's loadout, Planet Crafter's exoskeleton for the street: SLOTS generic slots beside the bag, for whatever can be
## ridden or worn (ItemDef.gear: bikes, boards, clothes). Anything equipped is with the hero wherever they are: a bike in the
## loadout is ridden from where they stand (Riding), a board likewise (Skating), and clothes are worn (their insulation is for
## the warmth rules to read). These are the rules; the inventory screen only asks.
class_name Loadout
extends RefCounted

const SLOTS := 4  # (a quest may widen it later)

var _w: World


func _init(world: World) -> void:
	_w = world


func _gear() -> Inventory:
	return _w.player.gear


## How many slots are taken (one item to a slot: gear does not stack).
func used() -> int:
	var n := 0
	for item in _gear().counts:
		n += _gear().count(item)
	return n


func items() -> Array[String]:
	var out: Array[String] = []
	for item in _gear().counts:
		for i in _gear().count(item):
			out.append(item)
	return out


func has_room() -> bool:
	return used() < SLOTS


## Moves one `item` from the bag into a slot. Returns {ok, text}.
func equip(item: String) -> Dictionary:
	var p := _w.player
	if p.carry.count(item) < 1:
		return _no("You don't have one.")
	if not Catalog.item(item).gear:
		return _no("That isn't something to ride or wear.")
	if not has_room():
		return _no("Your loadout is full: take something off first.")
	p.carry.take(item, 1)
	_gear().add(item, 1)
	return {"ok": true, "text": "Equipped the %s." % _name(item)}


## Moves one `item` from a slot back into the bag. Returns {ok, text}.
func unequip(item: String) -> Dictionary:
	var p := _w.player
	if _gear().count(item) < 1:
		return _no("You don't have that on.")
	if item == riding():
		return _no("Get off it first.")
	if not Stacks.can_add(p.carry, item, Commerce.CARRY_SLOTS):
		return _no("Your bag is full.")
	_gear().take(item, 1)
	p.carry.add(item, 1)
	return {"ok": true, "text": "Put the %s in your bag." % _name(item)}


## Gear just got (bought): into a slot if one is free, else into the bag. Returns where it went: "gear" or "bag".
func receive(item: String) -> String:
	if Catalog.item(item).gear and has_room():
		_gear().add(item, 1)
		return "gear"
	_w.player.carry.add(item, 1)
	return "bag"


## The fastest equipped item of class `cls` ("vehicle", "board"), or "".
func ride(cls: String) -> String:
	var best := ""
	for item in _gear().counts:
		if _gear().count(item) > 0 and Catalog.class_of(item) == cls and (best == "" or Catalog.item(item).speed > Catalog.item(best).speed):
			best = item
	return best


## What the hero is on right now, or "".
func riding() -> String:
	match _w.hero.mode:
		Hero.Mode.RIDING:
			return ride("vehicle")
		Hero.Mode.SKATING:
			return ride("board")
	return ""


## Everything worn that keeps the cold out, and how much in all.
func insulation() -> float:
	return _w.player.insulation() if _w.player != null else 0.0


func _name(item: String) -> String:
	return item.replace("_", " ")


func _no(text: String) -> Dictionary:
	return {"ok": false, "text": text}
