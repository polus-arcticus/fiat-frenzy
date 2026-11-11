## The price rule, as a pure function. One MIN_TICK per craft cycle:
##   output empty when the next unit is made -> price up one tick
##   output has stock (but isn't full)       -> price holds
##   output full (the craft is skipped)      -> price down one tick, never below the floor
## A price below the floor (the inputs got dearer) is first lifted to it.
class_name Pricing
extends RefCounted


static func after_craft(price: float, floor_price: float, tick: float, stock: int, capacity: int) -> float:
	var p := maxf(price, floor_price)
	if stock >= capacity:
		return maxf(floor_price, p - tick)
	if stock == 0:
		return p + tick
	return p
