## The player's ownership of one machine. What the business is worth is inferred from the experience it has
## had: what it would cost to rebuild (its "book" value) plus all the money the player has given it. A
## business that has been heavily funded is dearer to buy into. Buying more is priced at the same valuation,
## so it dilutes the earlier stake into a bigger total. Every sale then pays the stake its share of the
## takings, with no end.
##
## The player can own at most MAX_STAKE of any business (49%): never a majority.
class_name Equity
extends RefCounted

const MAX_STAKE := 0.49

var stake := 0.0  # the player's share of the takings, 0..MAX_STAKE


## What the business is worth, given its rebuild cost and the experience it has had.
func value(book: float, xp: float) -> float:
	return book + xp


## The most that can still be invested before the cap is reached.
func room(book: float, xp: float) -> float:
	return maxf(0.0, (MAX_STAKE - stake) * value(book, xp) / (1.0 - MAX_STAKE))


## What it would cost to take the stake up to `target` (at today's valuation).
func cost_to_reach(target: float, book: float, xp: float) -> float:
	if target <= stake:
		return 0.0
	return value(book, xp) * (target - stake) / (1.0 - target)


## Buys up to `amount` worth, as much as fits under the cap. Returns the dollars actually accepted.
func buy(amount: float, book: float, xp: float) -> float:
	var accepted := minf(amount, room(book, xp))
	if accepted <= 0.0:
		return 0.0
	var v := value(book, xp)
	stake = minf(MAX_STAKE, (stake * v + accepted) / (v + accepted))
	return accepted


## The player's cut of a sale.
func cut_of(price: float) -> float:
	return stake * price
