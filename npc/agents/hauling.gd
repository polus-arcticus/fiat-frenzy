## The cart runners' trade: salvage a load of the town's base inputs from its bins (WasteBin: scrap from the garbage, leftovers
## from the organics, water from a fountain: free to gather) and wheel it to whatever is most short of it (a shop's inputs, or
## the scrap a tent city is being built up of). Cash on delivery: the shop pays the goods' price into the town's fund
## (Deposit.fund: the bottle depot's, paid back out as deposits) and a flat DELIVERY_FEE to the runner for the trip, however big the load; both go into
## what its inputs cost it (so into its floor price: a baker's bread carries its share of the runner's walk). A trip is only
## planned when it is worth the walk.
##
## A runner is a business too (its cart, Drone.runner: Runner): the hero can invest in one (see Gun), and then takes their share of every
## fee.
class_name Hauling
extends RefCounted

const CART_CAPACITY := 16    # units a cart holds
const DELIVERY_FEE := 0.4    # what the shop pays the runner for a delivery, flat
## The goods are free, so all a load costs the shop is the fee: a trip waits for this much (at $2 for two, a tent city's keeper
## went hungry paying for it), or a store smaller than that filled. Only scrap goes as the last few of what a store has room for:
## a build waits on them (MachineDef.build_scrap). (Topping every stall up a unit or two at a time, the runners made three
## times the trips the town needed, each paying a fee: they banked $6 a day each, and the welfare office of the day printed it.)
const MIN_LOAD := 6

var _w: World


func _init(world: World) -> void:
	_w = world


## What a runner should do next. Carrying a load: take it to the shop that wants it most. Otherwise find the shop most short of
## something a bin has, and plan a trip: salvage a load there, wheel it over. A shop is only worth a trip if it is short a load
## (MIN_LOAD, or all the room it has left, counting what other runners are already bringing) and its owner can pay the fee.
## The bins are looked for in `from_zone` and the shops in `to_zone` (both the runner's own unless given: Borders gives them to
## plan a load across the border between two tiles).
func haul_job(d: Drone, from_zone := "", to_zone := "") -> Dictionary:
	if d.runner == null:
		return {}
	for item in d.runner.cart.counts:
		var carried: int = d.runner.cart.count(item)
		if carried <= 0:
			continue
		var dest: Machine = best_destination(d, item)
		if dest != null:
			return {"for": "haul", "stage": "drop", "target": dest, "item": item, "qty": carried}
		return {}  # holding a load nobody wants just now
	var best := {}
	var best_value := -INF
	var here := from_zone if from_zone != "" else d.zone
	for bin in _w.zones.bins_in(here):
		var item: String = bin.item
		if not bin.offers(item):
			continue
		for dest in _w.zones.machines_in(to_zone if to_zone != "" else d.zone):
			if not dest.working or not dest.input.caps.has(item) or dest.owner == "":
				continue
			var short: int = dest.input.room(item) - inbound(dest, item, d)
			var least := mini(MIN_LOAD, int(dest.input.caps[item]))
			if item == "scrap":
				least = mini(MIN_LOAD, dest.input.room(item))  # (the last few are worth it: a build waits on them)
			if short < maxi(least, 1):
				continue
			var qty := mini(mini(short, CART_CAPACITY), bin.output.count(item))
			qty = mini(qty, affordable(_w.drone(dest.owner), item))
			if qty < maxi(least, 1):
				continue
			var need: float = float(short) / float(dest.input.caps[item])
			var trip: float = _w.walking.effort([d.pos, bin.pos, dest.pos])  # (metres on the flat: a hill counts for more)
			if to_zone == "" and not _w.needs.would_last(d, trip):
				continue  # (not half empty, that far: eat and drink first. A load over the border is Borders' to judge.)
			var value := need * 10.0 - Logistics.DISTANCE_COST * trip
			if value > best_value:
				best_value = value
				best = {"for": "haul", "stage": "pickup", "target": bin, "dest": dest, "item": item, "qty": qty}
	return best


## The shop that most wants `item` and can pay for it, for a runner already carrying some.
func best_destination(d: Drone, item: String) -> Machine:
	var best: Machine = null
	var best_value := -INF
	for dest in _w.zones.machines_in(d.zone):
		if not dest.working or not dest.input.caps.has(item) or dest.owner == "" or dest.input.room(item) < 1:
			continue
		if affordable(_w.drone(dest.owner), item) < 1:
			continue
		var need: float = float(dest.input.room(item)) / float(dest.input.caps[item])
		var value := need * 10.0 - Logistics.DISTANCE_COST * d.pos.distance_to(dest.pos)
		if value > best_value:
			best_value = value
			best = dest
	return best


## What a shop's owner can spend on a delivery: their wallet less the reserve every agent keeps back for food and drink
## (Drone.RESERVE). (Cash on delivery once took the baker's last dollar, and the baker went thirsty.)
static func spendable(owner: Drone) -> float:
	return owner.wallet - (0.0 if owner.needless else Drone.RESERVE)


## How many of `item` the shop's owner can pay for, with the fee (a great many, for free scrap, if they can pay the fee).
func affordable(owner: Drone, item: String) -> int:
	var left := spendable(owner) - DELIVERY_FEE
	if left < 0.0:
		return 0
	var price := Catalog.base_price(item)
	return CART_CAPACITY if price <= 0.0 else int(left / price)


## Units of `item` other runners are already bringing to `dest`.
func inbound(dest: Machine, item: String, except: Drone) -> int:
	var n := 0
	for o in _w.zones.runners_in(dest.zone):
		if o == except or o.job.is_empty() or o.job["for"] != "haul" or o.job.item != item:
			continue
		var to = o.job.dest if o.job.stage == "pickup" else o.job.target
		if to == dest:
			n += o.job.qty
	return n


## At the bin: take the load (free). At the shop: hand it over; the shop pays the goods' price into the town's fund and the
## flat fee to the runner, cash on delivery, less the heroes' shares of the fee (see Equity: each into their own pocket).
func complete(d: Drone, job: Dictionary) -> void:
	var item: String = job.item
	if job.stage == "pickup":
		var bin = job.target
		var qty := mini(job.qty, bin.output.count(item))
		if qty <= 0:
			return
		bin.output.take(item, qty)
		bin.refresh()
		d.runner.cart.add(item, qty)
		var drop := {"for": "haul", "stage": "drop", "target": job.dest, "item": item, "qty": qty}
		drop["stand"] = _w.logistics.stand_point(d, drop)
		d.job = drop  # and now wheel it over
		return
	var dest: Machine = job.target
	var owner: Drone = _w.drone(dest.owner)
	var fund: Drone = _w.deposit.fund(dest.zone)
	var price := Catalog.base_price(item) if fund != null else 0.0  # (no fund to pay into: the goods are free)
	var r := d.runner
	var n := mini(mini(r.cart.count(item), dest.input.room(item)), affordable(owner, item))
	if n <= 0:
		return
	r.cart.take(item, n)
	dest.receive(item, n, price + DELIVERY_FEE / n)  # what they cost, and the fee, become what the shop's input costs it
	owner.wallet -= price * n + DELIVERY_FEE
	if fund != null:
		fund.wallet += price * n
	r.delivered_total += n
	r.deliveries += 1
	r.fees_earned += DELIVERY_FEE
	var paid := 0.0
	var cuts := r.equity.cuts(DELIVERY_FEE)
	for hero in cuts:
		_w.ledger.pay(hero, cuts[hero])
		paid += cuts[hero]
	d.wallet += DELIVERY_FEE - paid
