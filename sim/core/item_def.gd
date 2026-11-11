## Everything the game knows about one kind of item, in one place. Built by Catalog.
##
## cls says what it is for: "food", "drink" and "warmth" answer a survival demand; "material" is a raw input
## (flour, scrap) that is only ever made into something else; "vehicle" and "document" are carried, not used up.
class_name ItemDef
extends RefCounted

var id := ""
var cls := "material"
var restores := 0.0     # how much of a survival bar one unit refills (a bed instead shelters the drone)
var price := 0.0        # what a unit costs before anything has been bought: a raw good's cost, a product's floor,
                        # or the fixed price of something sold at a flat rate (the bicycle)
var found_free := false # lies around and costs nothing (scrap)
var relief := false     # comes on the Red Cross van


func _init(item_id: String, item_cls: String, item_price := 0.0, item_restores := 0.0) -> void:
	id = item_id
	cls = item_cls
	price = item_price
	restores = item_restores


## Can a drone use one up? (Beds shelter rather than refill, but they are still "used".)
func consumable() -> bool:
	return cls in ["food", "drink", "warmth"]
