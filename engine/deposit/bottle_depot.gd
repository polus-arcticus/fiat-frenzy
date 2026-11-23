## The bottle depot: a kiosk on the street where an attendant takes in the town's empties and pays the deposit on each (see
## Deposit). Its Premises: the money trade at tier 0 (the loan shark, the credit union and the bank branch above it are not
## built: docs/upgrade_trees.md). It stands where it was put and faces the street. The attendant's wallet is the town's fund:
## what its stalls paid for their salvaged goods (Hauling), paid back out as deposits before any new money is.
class_name BottleDepot
extends Premises

const MERGE := {"paid_out": "sum", "taken_in": "sum"}  # (see Merge)

var paid_out := 0.0  # dollars paid in deposits, all told
var taken_in := 0    # bottles taken in, all told


func _init(at := Vector2.ZERO, toward := Vector2(0, 1)) -> void:
	kind = "bottle_depot"
	trade = "money"
	pos = at
	front = toward
