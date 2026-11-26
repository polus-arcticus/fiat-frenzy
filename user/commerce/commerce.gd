## The hero's dealings with the town, as the rules: buy an item at a stand (right-click its stock), consume one they carry
## (right-click their own), pick up loose money by walking over it (and scoop up what lies on the bus's floor), and sit by a
## tent's barrels. The UI only asks; this decides.
##
## The hero pays out of their cash flow (the money their stakes earn), because the gun prints money for other people, not for
## them.
class_name Commerce
extends RefCounted

const REACH := 5.0       # how close the player must be to a stand to trade with it
const CARRY_SLOTS := 12  # the player's bag
const PICKUP_REACH := 1.4  # the hero picks up loose money from this close
const TENT_WARMS := 0.6    # warmth the hero gets from a sit by a standing tent's barrels (free)
## What the player starts with in their bag.
const START_KIT := {"bread": 2, "bottled_water": 2}

var _w: World


func _init(world: World) -> void:
	_w = world


## The hero picks up every loose bill within reach. Returns the total.
func pick_up_cash() -> float:
	if _w.player == null:
		return 0.0
	var got := 0.0
	for b in _w.bills.duplicate():
		if b.loose and b.pos.distance_to(_w.player.pos) <= PICKUP_REACH:
			got += b.value
			_w.bills.erase(b)
	_w.ledger.player_cash += got
	return got


## The hero gets off `v` with whatever is lying on its floor. Returns the total.
func scoop_aboard(v: Vehicle) -> float:
	var got := 0.0
	for b in _w.bills.duplicate():
		if b.aboard and b.ride == v.name:
			got += b.value
			_w.bills.erase(b)
	_w.ledger.player_cash += got
	return got


## The hero sits a while by `tent`'s barrels: warmer, free, if it is standing. Returns what it says.
func warm_at(tent: Machine) -> String:
	if not tent.working:
		return "The tent is wrecked: its barrels are cold."
	_w.player.bars.warmth = minf(1.0, _w.player.bars.warmth + TENT_WARMS)
	return "You sit a while by the barrels: warmth +%d%%." % roundi(TENT_WARMS * 100.0)


func can_reach(m: Machine) -> bool:
	return _w.player != null and _w.player.pos.distance_to(m.pos) <= REACH


## Returns {ok, text}: whether it happened, and a line to show the player either way.
func buy(m: Machine, item: String) -> Dictionary:
	var p: Drone = _w.player
	if not can_reach(m):
		return _no("Too far away.")
	if not m.working:
		return _no("It's wrecked: nothing for sale.")
	if not m.offers(item):
		return _no("Sold out.")
	var price := m.price_of(item)
	if _w.ledger.player_cash < price:
		return _no("Not enough cash: it's $%.2f and you have $%.2f." % [price, _w.ledger.player_cash])
	var gear: bool = Catalog.item(item).gear and _w.loadout.has_room()  # (gear goes straight into a free loadout slot)
	if not gear and not Stacks.can_add(p.carry, item, CARRY_SLOTS):
		return _no("Your bag is full.")
	m.output.take(item, 1)
	_w.ledger.player_cash -= price
	_w.logistics.pay_supplier(m, price)
	if _w.loadout.receive(item) == "gear":
		var how: String = {"vehicle": " Press F to ride it, wherever you are.", "board": " Press B to ride it."}.get(Catalog.class_of(item), "")
		var a := "an" if _name(item).left(1) in ["a", "e", "i", "o", "u"] else "a"
		return _yes("Bought %s %s for $%.2f: it's in your loadout.%s" % [a, _name(item), price, how])
	return _yes("Bought 1 %s for $%.2f." % [_name(item), price])


func consume(item: String) -> Dictionary:
	var p: Drone = _w.player
	if p.carry.count(item) < 1:
		return _no("You don't have any.")
	if Catalog.item(item).use() != "consume":
		return _no("You can't eat or drink that.")
	var amount: float = _w.needs.eat(p, item)
	p.carry.take(item, 1)
	var bar: String = Drone.need_of().get(Catalog.class_of(item), "")
	return _yes("Had 1 %s: %s +%d%%." % [_name(item), bar, roundi(amount * 100.0)])


func _name(item: String) -> String:
	return item.replace("_", " ")


func _yes(text: String) -> Dictionary:
	return {"ok": true, "text": text}


func _no(text: String) -> Dictionary:
	return {"ok": false, "text": text}
