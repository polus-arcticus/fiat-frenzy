## A cart runner's business (`Drone.runner`, null for anyone else): the cart they push, what it has carried, the fees it has
## earned, and the heroes' stakes in it. A runner is a business like a stand: the hero can invest in the cart (see Gun) and
## takes their share of every fee (see Hauling). Held by the runner, saved and merged with them, by its own MERGE table.
class_name Runner
extends RefCounted

const MERGE := {"delivered_total": "sum", "deliveries": "sum", "fees_earned": "sum"}
const CART_VALUE := 20.0  # what a cart is worth on the books, before its runner's experience (Equity.value)

var cart := Inventory.new()  # what is in it (salvaged goods on their way, a runner's bottles)
var delivered_total := 0     # units delivered
var deliveries := 0          # in how many trips
var fees_earned := 0.0       # what the deliveries paid in fees (the heroes' shares included)
var equity := Equity.new()   # the heroes' shares of its fees
