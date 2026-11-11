## What the player does at a stand, as the rules: buy an item (right-click the stand's stock) and
## consume one they carry (right-click their own). The UI only asks; this decides.
##
## The player pays out of their cash flow (the money their stakes earn), because the gun prints money for
## other people, not for them. A bed can't be carried: buying one is a night in the tent, and warms the
## player straight away.
class_name Commerce
extends RefCounted

const REACH := 5.0       # how close the player must be to a stand to trade with it
const CARRY_SLOTS := 12  # the player's bag
const BED_WARMTH := 0.6
## What the player starts with in their bag.
const START_KIT := {"bread": 2, "bottled_water": 2}

var _w: World


func _init(world: World) -> void:
	_w = world


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
	var is_bike := Catalog.class_of(item) == "vehicle"
	if is_bike and _w.bike != null:
		return _no("You already have a bike.")
	var is_bed := Catalog.class_of(item) == "warmth"
	if not is_bed and not is_bike and not Stacks.can_add(p.carry, item, CARRY_SLOTS):
		return _no("Your bag is full.")
	m.output.take(item, 1)
	_w.ledger.player_cash -= price
	_w.logistics.pay_supplier(m, price)
	if is_bed:
		p.bars.warmth = minf(1.0, p.bars.warmth + BED_WARMTH)
		return _yes("Slept a while in the tent for $%.2f: warmth +%d%%." % [price, roundi(BED_WARMTH * 100.0)])
	if is_bike:
		_w.bike = Bike.new(p.pos + m.front * 1.0)  # it waits by the player, on the customers' side of the counter
		return _yes("Bought a bicycle for $%.0f. It is waiting beside you: press F to get on." % price)
	p.carry.add(item, 1)
	return _yes("Bought 1 %s for $%.2f." % [_name(item), price])


func consume(item: String) -> Dictionary:
	var p: Drone = _w.player
	if p.carry.count(item) < 1:
		return _no("You don't have any.")
	if not Catalog.is_consumable(item) or Catalog.class_of(item) == "warmth":
		return _no("You can't eat or drink that.")
	var amount: float = _w.needs.eat(p, item)
	p.carry.take(item, 1)
	var bar := "hunger" if Catalog.class_of(item) == "food" else "thirst"
	return _yes("Had 1 %s: %s +%d%%." % [_name(item), bar, roundi(amount * 100.0)])


func _name(item: String) -> String:
	return item.replace("_", " ")


func _yes(text: String) -> Dictionary:
	return {"ok": true, "text": text}


func _no(text: String) -> Dictionary:
	return {"ok": false, "text": text}
