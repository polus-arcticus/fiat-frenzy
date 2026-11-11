## Everything the game knows about the food bank, in one place: its name, its shape on the ground, and what it
## stocks. Built by Catalog.
class_name FoodBankDef
extends RefCounted

## One good on its shelves. rate: new units a minute (slow). cap: most it holds. start: on the shelves when
## the game begins.
class Good:
	var id := ""
	var rate := 1.0
	var cap := 30
	var start := 10

	func _init(good_id: String, per_minute: float) -> void:
		id = good_id
		rate = per_minute

var name := "Food bank"
var footprint := {"boxes": [[0.0, 0.0, 1.7, 0.45]]}
var goods := {}  # good id -> Good


func add(id: String, per_minute: float) -> void:
	goods[id] = Good.new(id, per_minute)
