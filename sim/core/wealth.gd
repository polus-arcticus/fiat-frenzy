## How much money someone has, on a scale you can read at a glance from across the street: a count of orders of magnitude, and how
## far through the current one they are. Under $1 is nothing at all (broke). Each tenfold is a notch: $10 is one notch, $100 two,
## $1,000 three, $10,000 four (the most the scale shows). Within a notch the fill runs from empty at the order's start to full as
## they reach the next: $10 to $100 fills as $10 to $100, so $55 is half.
class_name Wealth
extends RefCounted

const MAX_TIER := 4


## The orders of magnitude of `money`: 0 below $10, 1 from $10, 2 from $100, 3 from $1,000, up to MAX_TIER.
static func tiers(money: float) -> int:
	if money < 10.0:
		return 0
	return mini(MAX_TIER, int(floor(log(money) / log(10.0) + 0.000001)))


## How far through the current order they are, 0 to 1. Broke (under $1) is empty; $1 to $10 fills the first stretch; after that
## each order runs from its start (10, 100, ...) to the next.
static func progress(money: float) -> float:
	if money < 1.0:
		return 0.0
	var t := tiers(money)
	if t >= MAX_TIER:
		return 1.0
	var low := 1.0 if t == 0 else pow(10.0, t)
	return clampf((money - low) / (pow(10.0, t + 1) - low), 0.0, 1.0)
