## The cart runners' trade: buy a load of base materials at the food bank and wheel it to the shop that is
## most short of it, for a fee on top of the cost. A trip is only planned when it is worth the walk.
class_name Hauling
extends RefCounted

const CART_CAPACITY := 16    # units a cart holds
const DELIVERY_FEE := 0.3    # what the shop pays the runner per unit, on top of the goods' cost
const MIN_DELIVERY := 4      # a shop must be this many units short before a runner makes the trip
const MIN_LOAD := 2          # and a load smaller than this is not worth wheeling

var _w: World


func _init(world: World) -> void:
	_w = world


## What a runner should do next. Carrying a load: take it to the shop that wants it most. Otherwise find
## the shop most short of something the food bank has, and plan a trip: buy a load there, wheel it over.
## A shop is only worth a trip if it is at least MIN_DELIVERY short (counting what other runners are
## already bringing), its owner can pay for the goods and the fee, and the runner can afford the load.
func haul_job(d: Drone) -> Dictionary:
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
	for item in Catalog.relief_goods():
		for fb in _w.zones.food_banks_in(d.zone):
			if not fb.offers(item):
				continue
			var price: float = fb.price_of(item)
			for dest in _w.zones.machines_in(d.zone):
				if not dest.working or not dest.recipe.has(item) or dest.owner_id < 0:
					continue
				var short: int = dest.input.room(item) - inbound(dest, item, d)
				if short < MIN_DELIVERY:
					continue
				var owner: Drone = _w.drones[dest.owner_id]
				var qty := mini(mini(short, CART_CAPACITY), fb.output.count(item))
				qty = mini(qty, int(d.wallet / price))
				qty = mini(qty, int(owner.wallet / (price + DELIVERY_FEE)))
				if qty < MIN_LOAD:
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
	var unit: float = Catalog.base_price(item) + DELIVERY_FEE
	for dest in _w.zones.machines_in(d.zone):
		if not dest.working or not dest.recipe.has(item) or dest.owner_id < 0 or dest.input.room(item) < 1:
			continue
		if _w.drones[dest.owner_id].wallet < unit:
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


## At the food bank: buy the load. At the shop: hand it over, and get paid the cost plus the fee.
func complete(d: Drone, job: Dictionary) -> void:
	var item: String = job.item
	if job.stage == "pickup":
		var fb: FoodBank = job.target
		var price: float = fb.price_of(item)
		var qty := mini(mini(job.qty, fb.output.count(item)), int(d.wallet / price))
		if qty <= 0:
			return
		fb.output.take(item, qty)
		d.wallet -= price * qty
		_w.drones[fb.owner_id].wallet += price * qty
		fb.sold_total += qty
		fb.revenue_total += price * qty
		fb.refresh()
		d.cart.add(item, qty)
		var drop := {"for": "haul", "stage": "drop", "target": job.dest, "item": item, "qty": qty}
		drop["stand"] = _w.logistics.stand_point(d, drop)
		d.job = drop  # and now wheel it over
		return
	var dest: Machine = job.target
	var unit: float = Catalog.base_price(item) + DELIVERY_FEE
	var owner: Drone = _w.drones[dest.owner_id]
	var n := mini(mini(d.cart.count(item), dest.input.room(item)), int(owner.wallet / unit))
	if n <= 0:
		return
	d.cart.take(item, n)
	dest.receive(item, n, unit)  # the fee becomes part of what the shop's input costs it
	owner.wallet -= unit * n
	d.wallet += unit * n
	d.delivered_total += n
	d.fees_earned += DELIVERY_FEE * n
