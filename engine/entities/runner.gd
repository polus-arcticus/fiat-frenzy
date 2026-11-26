## A runner's business (`Drone.runner`, null for anyone else): what they haul with (their tier), what is in it, what it has
## carried, the fees it has earned, and the heroes' stakes in it. A runner is a business like a stand: the hero can invest in
## it (see Gun) and takes their share of every fee (see Hauling). Held by the runner, saved and merged with them, by its own
## MERGE table.
##
## It climbs tiers as a stand does (Trades): at dawn a runner who has the next one's price, and the reserve everyone keeps,
## buys it. The tiers are one table (TIERS); the next ones in mind: a moped, a tuk tuk, a delivery vehicle.
class_name Runner
extends RefCounted

const MERGE := {"delivered_total": "sum", "deliveries": "sum", "fees_earned": "sum", "tier": "max"}
## By tier: what it is called, what the runner is then, the speed it goes (metres a second), the units it holds, how far from
## the market it reaches for bins beyond walking (World.open_round; 0: the town's own only), and its price.
const TIERS := [
	{"id": "cart", "name": "shopping cart", "keeper": "Cart runner", "speed": 1.9, "load": 16, "reach": 0.0, "cost": 0.0},
	{"id": "bike", "name": "pedal bike with a trailer", "keeper": "Bike courier", "speed": 4.5, "load": 40, "reach": 350.0, "cost": 60.0},
]
const CART_VALUE := 20.0  # what a cart is worth on the books, before its runner's experience (Equity.value)

var tier := 0
var cart := Inventory.new()  # what is in it (salvaged goods on their way, goods bought off a shelf, a runner's bottles)
var paid := {}               # item -> what each of those in the cart cost the runner, bought off another business's shelf (Hauling)
var delivered_total := 0     # units delivered
var deliveries := 0          # in how many trips
var fees_earned := 0.0       # what the deliveries paid in fees (the heroes' shares included)
var equity := Equity.new()   # the heroes' shares of its fees


## What they haul with now (a row of TIERS)...
func rig() -> Dictionary:
	return TIERS[tier]


## ...and what they could buy next ({} at the top).
func next_rig() -> Dictionary:
	return TIERS[tier + 1] if tier + 1 < TIERS.size() else {}


## What the business is worth on the books: the cart's, and what has been paid for every rig since.
func book_value() -> float:
	var total := CART_VALUE
	for k in range(1, tier + 1):
		total += float(TIERS[k].cost)
	return total
