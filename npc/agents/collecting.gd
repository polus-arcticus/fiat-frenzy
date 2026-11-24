## Collecting bottles (Pfand): whoever is short of cash walks to the recycling bin, takes what bottles they can carry, and hands
## them in at the bottle depot for the deposit on each (Deposit). It is how money comes into the town now: not given, but walked
## for, by who needs it, when they need it. Fed and warm comes first (Needs.demands puts it after the bars and the vocation): one
## who is hungry and can't pay for food has nothing better to do than go and collect.
##   who    anyone resident with less than ENOUGH, but the depot's attendant; a vendor only while their working stand needs
##          it (nothing on its shelf, or they can't pay for a load of its inputs: not mid-trade otherwise; and not while it is
##          wrecked: they wait by it for the hero); a runner with the cart, so more at a time
##   how    to the nearest recycling bin with MIN_PICK bottles in it, up to CARRY by hand (the cart's whole load), then to the
##          zone's depot; anyone already holding bottles takes them in, whatever their wallet
class_name Collecting
extends RefCounted

## A resident with less than this goes collecting (a few days' food and drink, about $7 a day): the deposit is for who is short,
## not the town's savings. (The welfare office's net was cut off at the same line: Deposit.)
const ENOUGH := 25.0
const CARRY := 20    # bottles one carries by hand, a bag's worth (a runner's cart takes Hauling.CART_CAPACITY)
const MIN_PICK := 2  # a bin with fewer isn't worth the walk ($2: at 4 a broke medic lost every race to the trickle)
const ITEM := "recyclables"
const NEVER := ["attendant", "clerk", "player"]  # (behind the counter, the story's own, the hero)

var _w: World


func _init(world: World) -> void:
	_w = world


## Should `d` go collecting (or take in what they hold)? Needs.demands asks.
func wants(d: Drone) -> bool:
	if d.needless or d.aloof or d.kind in NEVER or _w.deposit.depot_in(d.zone) == null:
		return false
	if held(d) > 0:
		return true
	if d.wallet >= ENOUGH:
		return false
	var m := _w.machine_of(d)
	if m == null:
		return true
	if not m.working:
		return false  # (a wrecked stand: its keeper waits by it for the money to mend it, the hero's; a few dollars won't)
	return m.stock() == 0 or not _can_restock(d, m)


## Can `d` pay for a runner's load of each salvaged input their stand makes its wares of? (If not, the stand will run dry: the
## bottles are what pays for it.)
func _can_restock(d: Drone, m: Machine) -> bool:
	for raw in m.recipe:
		if raw in Catalog.scavenged_goods() and _w.logistics.hauling.affordable(d, raw) < Hauling.MIN_LOAD:
			return false
	return true


## How many bottles `d` has on them (in the cart, for a runner).
func held(d: Drone) -> int:
	return _bag(d).count(ITEM)


## Holding bottles: to the depot with them. Otherwise to the nearest recycling bin that has enough to be worth it. {} if there
## is nothing to do (no depot here, or no bin with bottles).
func job(d: Drone) -> Dictionary:
	var depot := _w.deposit.depot_in(d.zone)
	if depot == null:
		return {}
	var n := held(d)
	if n > 0:
		return {"for": "collect", "stage": "redeem", "target": depot, "item": ITEM, "qty": n}
	var best: WasteBin = null
	var near := INF
	for bin in _w.zones.bins_in(d.zone):
		if bin.item != ITEM or bin.output.count(ITEM) - _inbound(bin, d) < MIN_PICK:
			continue
		var gap := d.pos.distance_to(bin.pos)
		if not _w.needs.would_last(d, _w.walking.effort([d.pos, bin.pos, depot.pos])):  # (metres on the flat: hills count)
			continue  # (they'd go down on the way)
		if gap < near:
			near = gap
			best = bin
	if best == null:
		return {}
	var qty := mini(best.output.count(ITEM) - _inbound(best, d), mini(capacity(d), needed(d)))
	return {"for": "collect", "stage": "pickup", "target": best, "item": ITEM, "qty": qty}


## How many bottles bring `d` back up to ENOUGH: they take what they need, not a bagful whatever their wallet (the deposit is a
## net, not savings). At least MIN_PICK, or the walk isn't worth it.
func needed(d: Drone) -> int:
	return maxi(MIN_PICK, ceili((ENOUGH - d.wallet) / Deposit.DEPOSIT))


## How many bottles `d` can take at once.
func capacity(d: Drone) -> int:
	return Hauling.CART_CAPACITY if d.runner != null else CARRY


## Bottles others are already on their way to take from `bin`.
func _inbound(bin: WasteBin, except: Drone) -> int:
	var n := 0
	for o in _w.zones.drones_in(bin.zone):
		if o != except and not o.job.is_empty() and o.job["for"] == "collect" and o.job.stage == "pickup" and is_same(o.job.target, bin):
			n += int(o.job.qty)
	return n


## At the bin: take the bottles, and set off for the depot. At the depot: hand them in, and be paid.
func complete(d: Drone, job: Dictionary) -> void:
	if job.stage == "pickup":
		var bin: WasteBin = job.target
		var n := mini(int(job.qty), bin.output.count(ITEM))
		if n <= 0:
			return
		bin.output.take(ITEM, n)
		bin.refresh()
		_bag(d).add(ITEM, n)
		var next := job_to_depot(d)
		if not next.is_empty():
			d.job = next  # and now take them in
		return
	var n := held(d)
	if n <= 0:
		return
	_bag(d).take(ITEM, n)
	_w.deposit.redeem(d, job.target, n)


func job_to_depot(d: Drone) -> Dictionary:
	var j := job(d)
	if not j.is_empty():
		j["stand"] = _w.logistics.stand_point(d, j)
	return j


func _bag(d: Drone) -> Inventory:
	return d.runner.cart if d.runner != null else d.carry
