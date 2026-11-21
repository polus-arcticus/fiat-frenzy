## The cart runners' trade: buy a load of base materials at the food bank (or gather scrap from a pile in the street, free) and
## wheel it to whatever is most short of it (a shop's inputs, or the scrap a tent city is being built up of). Cash on delivery:
## the shop pays back what the goods cost and a flat DELIVERY_FEE for the trip, however big the load, and the fee goes into what
## its inputs cost it (so into its floor price: a baker's bread carries its share of the runner's walk). A trip is only planned
## when it is worth the walk.
##
## A runner is a business too (a cart, Drone.equity): the hero can invest in one (see Gun), and then takes their share of every
## fee.
class_name Hauling
extends RefCounted

const CART_CAPACITY := 16    # units a cart holds
const DELIVERY_FEE := 1.0    # what the shop pays the runner for a delivery, flat, on top of the goods' cost
const MIN_DELIVERY := 4      # a shop must be this many units short before a runner makes the trip
const MIN_LOAD := 2          # and a load smaller than this is not worth wheeling
## Scrap is free, so all a load costs is the fee: a trip waits for this much (at $2 for two, a tent city's keeper went hungry
## paying for it), unless it is the last of what a build needs.
const MIN_SCRAP_LOAD := 6

var _w: World


func _init(world: World) -> void:
	_w = world


## What a runner should do next. Carrying a load: take it to the shop that wants it most. Otherwise find
## the shop most short of something the food bank has, and plan a trip: buy a load there, wheel it over.
## A shop is only worth a trip if it is at least MIN_DELIVERY short (counting what other runners are
## already bringing), its owner can pay for the goods and the fee, and the runner can afford the load.
## The food banks are looked for in `from_zone` and the shops in `to_zone` (both the runner's own unless given: Borders
## gives them to plan a load across the border between two tiles).
func haul_job(d: Drone, from_zone := "", to_zone := "") -> Dictionary:
	for item in d.cart.counts:
		var carried: int = d.cart.count(item)
		if carried <= 0:
			continue
		var dest: Machine = best_destination(d, item)
		if dest != null:
			return {"for": "haul", "stage": "drop", "target": dest, "item": item, "qty": carried}
		return {}  # holding a load nobody wants just now
	var best := {}
	var best_value := -INF
	var here := from_zone if from_zone != "" else d.zone
	var sources: Array = []  # [where, item]: the food banks' relief goods, and the scrap lying in the street
	for fb in _w.zones.food_banks_in(here):
		for item in Catalog.relief_goods():
			sources.append([fb, item])
	for p in _w.scrap_piles:
		if p.zone == here:
			sources.append([p, "scrap"])
	for s in sources:
		var fb = s[0]
		var item: String = s[1]
		if not fb.offers(item):
			continue
		var price: float = fb.price_of(item)
		for dest in _w.zones.machines_in(to_zone if to_zone != "" else d.zone):
			if not dest.working or not dest.input.caps.has(item) or dest.owner == "":
				continue
			var short: int = dest.input.room(item) - inbound(dest, item, d)
			var least := MIN_DELIVERY  # (the smallest shortfall worth a trip, and the smallest load)
			var least_load := MIN_LOAD
			if price <= 0.0:  # (free scrap: the last few are worth it, a build waits on them)
				least = mini(MIN_SCRAP_LOAD, dest.input.room(item))
				least_load = least
			if short < maxi(least, 1):
				continue
			var owner: Drone = _w.drone(dest.owner)
			var qty := mini(mini(short, CART_CAPACITY), fb.output.count(item))
			if price > 0.0:
				qty = mini(qty, int(d.wallet / price))
				qty = mini(qty, int((owner.wallet - DELIVERY_FEE) / price))
			elif owner.wallet < DELIVERY_FEE:
				continue
			if qty < maxi(least_load, 1):
				continue
			var need: float = float(short) / float(dest.input.caps[item])
			var trip: float = d.pos.distance_to(fb.pos) + fb.pos.distance_to(dest.pos)
			var value := need * 10.0 - Logistics.DISTANCE_COST * trip
			if value > best_value:
				best_value = value
				best = {"for": "haul", "stage": "pickup", "target": fb, "dest": dest, "item": item, "qty": qty}
	return best


## The shop that most wants `item` and can pay for it, for a runner already carrying some.
func best_destination(d: Drone, item: String) -> Machine:
	var best: Machine = null
	var best_value := -INF
	var least: float = Catalog.base_price(item) + DELIVERY_FEE  # (a delivery of one)
	for dest in _w.zones.machines_in(d.zone):
		if not dest.working or not dest.input.caps.has(item) or dest.owner == "" or dest.input.room(item) < 1:
			continue
		if _w.drone(dest.owner).wallet < least:
			continue
		var need: float = float(dest.input.room(item)) / float(dest.input.caps[item])
		var value := need * 10.0 - Logistics.DISTANCE_COST * d.pos.distance_to(dest.pos)
		if value > best_value:
			best_value = value
			best = dest
	return best


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


## At the food bank: buy the load. At the shop: hand it over, and get paid, cash on delivery: the goods' cost and the flat fee,
## less the heroes' shares of the fee (see Equity: each into their own pocket).
func complete(d: Drone, job: Dictionary) -> void:
	var item: String = job.item
	if job.stage == "pickup":
		var fb = job.target  # (a food bank, or a pile of scrap in the street: free)
		var price: float = fb.price_of(item)
		var qty := mini(job.qty, fb.output.count(item))
		if price > 0.0:
			qty = mini(qty, int(d.wallet / price))
		if qty <= 0:
			return
		fb.output.take(item, qty)
		if fb is FoodBank:
			d.wallet -= price * qty
			_w.drone(fb.owner).wallet += price * qty
			fb.sold_total += qty
			fb.revenue_total += price * qty
		fb.refresh()
		d.cart.add(item, qty)
		var drop := {"for": "haul", "stage": "drop", "target": job.dest, "item": item, "qty": qty}
		drop["stand"] = _w.logistics.stand_point(d, drop)
		d.job = drop  # and now wheel it over
		return
	var dest: Machine = job.target
	var cost: float = Catalog.base_price(item)
	var owner: Drone = _w.drone(dest.owner)
	var n := mini(d.cart.count(item), dest.input.room(item))
	if cost > 0.0:
		n = mini(n, int((owner.wallet - DELIVERY_FEE) / cost))
	if n <= 0 or owner.wallet < cost * n + DELIVERY_FEE:
		return
	d.cart.take(item, n)
	dest.receive(item, n, cost + DELIVERY_FEE / n)  # the fee becomes part of what the shop's input costs it
	owner.wallet -= cost * n + DELIVERY_FEE
	d.wallet += cost * n
	d.delivered_total += n
	d.deliveries += 1
	d.fees_earned += DELIVERY_FEE
	var paid := 0.0
	var cuts := d.equity.cuts(DELIVERY_FEE)
	for hero in cuts:
		_w.ledger.pay(hero, cuts[hero])
		paid += cuts[hero]
	d.wallet += DELIVERY_FEE - paid
