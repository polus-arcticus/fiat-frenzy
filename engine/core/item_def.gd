## Everything the game knows about one kind of item, in one place. Built by Catalog.
##
## cls says what it is for: "food", "drink" and "warmth" answer a survival demand; "material" is a raw input
## (flour, scrap) that is only ever made into something else; "vehicle", "board", "clothes" and "document" are carried or
## worn, not used up; "camping" is put down in the street (a tent, a barrel fire).
class_name ItemDef
extends RefCounted

var id := ""
var cls := "material"
var restores := 0.0     # how much of a survival bar one unit refills (a bed instead shelters the drone)
var price := 0.0        # what a unit costs before anything has been bought: a raw good's cost, a product's floor,
                        # or the fixed price of something sold at a flat rate (the bicycle)
var scavenged := false  # salvaged from the town's bins (WasteBin), costs nothing, and runners gather it (scrap, leftovers, ...)
var speed := 1.0        # a vehicle or board: how much of the full one's speed it gives (a scrap-built one is slower)
var gear := false       # can be equipped: ridden or worn, in a loadout slot (bikes, boards, clothes)
var insulation := 0.0   # clothes: how much it keeps the cold out (Needs.decay reads it: see Drone.insulation)
var placeable := false  # put down in the street from the bag: a tent (it founds a tent city) or a barrel fire (see Placing)


func _init(item_id: String, item_cls: String, item_price := 0.0, item_restores := 0.0) -> void:
	id = item_id
	cls = item_cls
	price = item_price
	restores = item_restores


## What using one from the bag does, the one rule for it: "equip" (gear: into the loadout), "consume" (food and drink),
## "place" (put down in the street: a tent, a barrel fire), or "" (nothing: it is carried).
func use() -> String:
	if gear:
		return "equip"
	if placeable:
		return "place"
	if cls in ["food", "drink"]:
		return "consume"
	return ""


## Can a drone use one up? (Beds shelter rather than refill, but they are still "used".)
func consumable() -> bool:
	return cls in ["food", "drink", "warmth"]
