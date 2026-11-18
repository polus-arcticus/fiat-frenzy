## The price rule, as a pure function. A stand aims to keep a little on its shelf (BUFFER of it). One tick per craft cycle:
##   output empty when the next unit is made  -> price up one tick (it sold out: it is too cheap)
##   output under the buffer                  -> price holds
##   output at the buffer or more             -> price down one tick, never below the floor (it is not selling)
## A price below the floor (the inputs got dearer) is first lifted to it.
## So a stand that cannot make as much as people want (short of inputs) finds the price at which what it makes is what sells,
## and comes back down as soon as it has some left over. (The buffer was the whole shelf, then half of it: a stand short of
## inputs never got back to half full, so every sell-out added a tick for good, and over a season its price climbed until
## nobody could eat: tools/epoch.gd.)
class_name Pricing
extends RefCounted

const BUFFER := 0.1  # of the shelf: a stand with at least this much left over (and at least one) is not selling all it makes


static func after_craft(price: float, floor_price: float, tick: float, stock: int, capacity: int) -> float:
	var p := maxf(price, floor_price)
	if stock == 0:
		return p + tick
	if stock >= maxi(1, ceili(capacity * BUFFER)):
		return maxf(floor_price, p - tick)
	return p
