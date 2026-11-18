## Premises: where a business is, who runs it, and what it is. Every business in the game is one of these: a stand, the food
## bank, the welfare office, a shop. What it is, is a TRADE at a TIER (Catalog.TRADES: the hot dog stand is the meat trade at
## tier 0, the burger bar is tier 1), and its owner (an NPC) climbs the trade by paying to build the next tier out of their own
## savings (see Trades). `kind` is the tier's id, the key of everything else about it in the Catalog.
##
## (A class that extends this has its own MERGE table; a tier is merged as "max" there, and Merge.settle makes the kind agree.)
class_name Premises
extends RefCounted

var uid := ""          # see World.mint
var kind := ""         # what it is: a Catalog id ("hot_dog_stand", "food_bank", "welfare_office")
var trade := ""        # the ladder it climbs ("meat", "bread", "money"...; see Catalog.TRADES)
var tier := 0          # how far up that ladder
var owner := ""        # the uid of whoever runs it (a vendor, the keeper, the clerk)
var zone := "district" # which patch of the map it stands in (its owner's zone)
var pos := Vector2.ZERO
var front := Vector2(0, 1):  # unit vector from it toward its customers (set by whoever places it)
	set(v):
		front = v
		_solid = null
var _solid: Footprint = null


## What it takes up on the ground, for keeping drones out of it (by its kind's footprint).
func solid() -> Footprint:
	if _solid == null:
		_solid = Footprint.of(kind, pos, front)
	return _solid


## Where whoever runs it stands: behind the counter.
func post() -> Vector2:
	return pos - front * 1.2


func display_name() -> String:
	return Catalog.name_of(kind)
