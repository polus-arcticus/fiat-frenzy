## Experience and level: how much money the player has given someone (a gift, an investment, a bill they
## picked up), and the level that adds up to. A level costs more than the one before it: going from level 1
## to 2 takes FIRST dollars, and each level after takes FACTOR times what the last did. Progress toward the
## next level is what the green bar over a head shows; the excess carries over when the bar fills.
##
## Every drone has one. A vendor's machine shares its owner's, so the business and its owner level together,
## and what the business is worth is worked out from the experience it has had (see Equity).
class_name Growth
extends RefCounted

const FIRST := 50.0   # dollars from level 1 to level 2
const FACTOR := 1.5   # each level takes this many times the previous one
const MAX_LEVEL := 10

var xp := 0.0
var level := 1


## What it takes to go from `from_level` to the next one.
static func need(from_level: int) -> float:
	return FIRST * pow(FACTOR, from_level - 1)


## Total experience at which `lvl` is reached.
static func total_for(lvl: int) -> float:
	return FIRST * (pow(FACTOR, lvl - 1) - 1.0) / (FACTOR - 1.0)


## Adds experience. Returns how many levels that gained.
func add(amount: float) -> int:
	xp += maxf(0.0, amount)
	var gained := 0
	while level < MAX_LEVEL and xp >= total_for(level + 1):
		level += 1
		gained += 1
	return gained


## 0..1: how far through the current level the bar is.
func progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	return clampf((xp - total_for(level)) / need(level), 0.0, 1.0)


## Dollars still to give before the next level.
func to_next() -> float:
	return INF if level >= MAX_LEVEL else total_for(level + 1) - xp
