## The Red Cross van. An emergency supply vehicle with a small, free load: it turns up at the same times
## each day, stays a little while, and hands out what the food stalls are made of (leftovers and water, GOODS) to the working
## machines that use them, filling their input inventories as far as the load goes. No money changes
## hands. When there is not enough to go round, every machine that wants a good gets an equal share.
class_name ReliefTruck
extends RefCounted

const ARRIVALS := [0.15, 0.5]  # fractions of the day
const STAY := 100.0            # seconds it stays in town
const GOODS := ["leftovers", "water"]

var uid := ""  # see World.mint
var zone := "district"
var pos := Vector2.ZERO
var heading := Vector2(1, 0)  # the way it is parked (down the street)
var present := false
var load_per_good := 15        # units of each good it brings
var visits := 0
var last_delivery := {}        # good -> units handed over on the most recent visit


func _init(at := Vector2.ZERO) -> void:
	pos = at


func arrive(machines: Array) -> void:
	present = true
	visits += 1
	last_delivery = deliver(machines)


func depart() -> void:
	present = false


## Hands out the load, one unit at a time round the machines that want it, until it runs out or
## everyone is full. Returns how much of each good went out.
func deliver(machines: Array) -> Dictionary:
	var given := {}
	for g in GOODS:
		var takers := machines.filter(func(m): return m.working and m.recipe.has(g))
		var left := load_per_good
		var progress := true
		while left > 0 and progress:
			progress = false
			for m in takers:
				if left > 0 and m.input.room(g) > 0:
					m.receive(g, 1, Catalog.base_price(g))
					left -= 1
					given[g] = given.get(g, 0) + 1
					progress = true
	return given
