## Who owns a share of one machine. What the business is worth is inferred from the experience it has
## had: what it would cost to rebuild (its "book" value) plus all the money that has been given to it. A
## business that has been heavily funded is dearer to buy into. Buying more is priced at the same valuation,
## so it dilutes every earlier stake (and the owner) into a bigger total. Every sale then pays each stake its
## share of the takings, with no end.
##
## Stakes are per hero (a world can hold more than one). Together the heroes can own at most MAX_STAKE of any
## business (49%): never a majority.
class_name Equity
extends RefCounted

const MAX_STAKE := 0.49
const MERGE := {"stakes": "sum"}  # each save's heroes keep what they bought (see Merge, which also enforces the cap after)

var stakes := {}  # hero uid -> their share of the takings; the shares add up to at most MAX_STAKE

## Everything the heroes own of it together, 0..MAX_STAKE.
var stake: float:
	get:
		var s := 0.0
		for h in stakes:
			s += stakes[h]
		return s


## One hero's share.
func share(hero: String) -> float:
	return stakes.get(hero, 0.0)


## What the business is worth, given its rebuild cost and the experience it has had.
func value(book: float, xp: float) -> float:
	return book + xp


## The most that can still be invested before the cap is reached.
func room(book: float, xp: float) -> float:
	return maxf(0.0, (MAX_STAKE - stake) * value(book, xp) / (1.0 - MAX_STAKE))


## `hero` buys up to `amount` worth, as much as fits under the cap. Returns the dollars actually accepted. The new money
## dilutes every stake already held, and the buyer gets what it bought.
func buy(amount: float, book: float, xp: float, hero := "") -> float:
	var accepted := minf(amount, room(book, xp))
	if accepted <= 0.0:
		return 0.0
	var v := value(book, xp)
	var keep := v / (v + accepted)
	for h in stakes:
		stakes[h] *= keep
	stakes[hero] = share(hero) + accepted / (v + accepted)
	var over := stake - MAX_STAKE
	if over > 0.0:  # (rounding)
		stakes[hero] -= over
	return accepted


## Each hero's cut of a sale: hero uid -> dollars.
func cuts(price: float) -> Dictionary:
	var out := {}
	for h in stakes:
		out[h] = stakes[h] * price
	return out


## All the heroes' cut of a sale together.
func cut_of(price: float) -> float:
	return stake * price
