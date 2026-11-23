## The deposit (Pfand): every bottle the town throws away is worth DEPOSIT at its bottle depot. Whoever is short of cash collects
## them from the recycling bins and hands them in (Collecting: the people's side); the depot pays them out of the town's fund
## first, the attendant's wallet (what the stalls paid for their salvaged goods: Hauling), and only when that is empty is it new
## money, counted in Ledger.printed and Ledger.issued, so total_money == ledger.printed holds.
##
## So the town's new money is bounded by how fast its recycling bins fill (WasteBin.KINDS.recycling) times DEPOSIT, and it goes
## only to who walks for it, when they need it. It replaced the welfare office's fountain, which gave a few dollars at random to
## whoever was poorest (2026-11-23).
class_name Deposit
extends RefCounted

## Dollars a bottle. (It was a German PET bottle's $0.25, with four times the bottles: the same money, but the town's people
## spent their days on an endless supply of cans, a quarter of a drifter's time. A dollar each, a quarter as many.)
const DEPOSIT := 1.0

var _w: World


func _init(world: World) -> void:
	_w = world


## A depot's attendant, whose wallet holds the fund.
func attendant(depot: BottleDepot) -> Drone:
	return _w.drone(depot.owner)


## The depot `zone`'s people take their bottles to, or null if it has none.
func depot_in(zone: String) -> BottleDepot:
	for d in _w.bottle_depots:
		if d.zone == zone:
			return d
	return null


## Who keeps the fund for `zone`: the attendant of its depot (or of the home town's, or of the first there is); null where there
## is none (then the town's salvaged goods are simply free).
func fund(zone: String) -> Drone:
	if _w.bottle_depots.is_empty():
		return null
	var depot := depot_in(zone)
	if depot == null:
		depot = depot_in(Zones.HOME)
	if depot == null:
		depot = _w.bottle_depots[0]
	return attendant(depot)


## `who` hands `n` bottles in at `depot` and is paid the deposit on each: from the fund while it lasts, then new money. Returns
## what they were paid.
func redeem(who: Drone, depot: BottleDepot, n: int) -> float:
	if n <= 0:
		return 0.0
	var owed := DEPOSIT * n
	var till := attendant(depot)
	var from_fund := minf(owed, maxf(till.wallet, 0.0)) if till != null else 0.0
	if till != null:
		till.wallet -= from_fund
	var printed := owed - from_fund
	_w.ledger.printed += printed
	_w.ledger.issued += printed
	who.wallet += owed
	depot.paid_out += owed
	depot.taken_in += n
	return owed
