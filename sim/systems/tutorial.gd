## The tutorial, as a list of objectives checked against the model. Each step has the text to show, an
## optional place to point the beacon at, and a test that says it's done. Nothing here changes the world: it
## only watches, so it needs no nodes and is tested headless like any other system.
class_name Tutorial
extends RefCounted

var steps: Array[Dictionary] = []
var index := 0

var _w: World
var _cast: Dictionary


func _init(world: World, cast: Dictionary, with_pickup := false) -> void:
	_w = world
	_cast = cast
	if with_pickup:
		_step("Pick up the money gun at your feet: aim at it and press E.",
			func(): return _w.player.pos + Vector2.ZERO, func(): return _w.gun_owned)
	var hot: Drone = cast.hot_dog
	var baker: Drone = cast.bakery
	var tent: Drone = cast.tent
	_step("Welcome to the station district. It's abandoned, and everyone left in it is broke, hungry and cold. Walk over to the hot dog vendor.",
		func(): return hot.pos, func(p): return p.distance_to(hot.pos) < 10.0)
	_step("His stand is wrecked and he has nothing. Aim at him and hold LEFT CLICK to spray $1 bills (GIFT mode). Repairs cost about $50. Every dollar you give fills the green bar over a head; fill it and their business levels up.",
		func(): return hot.pos, func(): return _w.machine_of(hot).working)
	_step("Hot dogs need buns. The baker's stand is wrecked too: gift him about $50 so he can bake.",
		func(): return baker.pos, func(): return _w.machine_of(baker).working)
	_step("The Red Cross van brings a few free supplies twice a day. Now the drifters need money to buy food. Gift them until someone eats. Bills that miss land in the street: anyone can pick them up, and so can you.",
		func(): return _nearest_drifter(), func(): return _sold() >= 3)
	_step("Scroll the mouse wheel to switch to INVEST. HOLD left click to charge a contract (the ring fills: the longer, the bigger), aim at the baker and RELEASE. You buy a share of his bakery (up to 49%), and the money goes to him. A contract that misses is void.",
		func(): return baker.pos, func(): return _w.machine_of(baker).equity.stake > 0.05)
	_step("Every sale now pays you a share of the takings, forever. Keep the town fed until your stake has paid you $2.",
		func(): return null, func(): return _w.ledger.stake_income >= 2.0)
	var shop: Drone = cast.get("bike_shop")
	if shop != null:
		var counter: Vector2 = _w.machine_of(shop).pos
		_step(func(): return "Save $%d for a bicycle at the bike shop (%.0f m away). Spray the ground and walk over the bills to pick them up (other people will grab loose cash too), or live off your stakes.  You have $%.0f of $%d." % [int(Catalog.bike_price()), _w.player.pos.distance_to(counter), _w.ledger.player_cash, int(Catalog.bike_price())],
			func(): return counter, func(): return _w.bike != null or _w.ledger.player_cash >= Catalog.bike_price())
		_step("You have the money. Go into the bike shop and press E at the counter, then right-click the bicycle to buy it.",
			func(): return counter, func(): return _w.bike != null)
		_step("Your bike is waiting outside the counter. Press F next to it to get on (and F again to get off). It's more than twice as fast as walking.",
			func(): return _w.bike.pos, func(): return _w.riding.riding())
	_step("Night falls at 8:30pm and it gets bitter. Fund the tent keeper, and use the free barrel fire, or your drifters freeze.",
		func(): return tent.pos, func(): return _w.machine_of(tent).working and _w.clock.day() >= 1)
	_step(func(): return "Get every stand running and keep the bankers fed (%d of %d have had a meal). One of them has a favour to ask." % [_fed_bankers(), _w.quests.bankers().size()],
		func(): return _nearest_unfed_banker(), func(): return _w.quests.state.has(QuestBook.LETTER))
	_step("That's the loop. Every building in this district is waiting for someone: explore, and spray responsibly.",
		func(): return null, func(): return false)


func _fed_bankers() -> int:
	return _w.quests.fed_count()


func _nearest_unfed_banker() -> Variant:
	for b in _w.quests.bankers():
		if not _w.quests.fed.has(b.id):
			return b.pos
	return null


func _step(text: Variant, marker: Callable, done: Callable) -> void:
	steps.append({"text": text, "marker": marker, "done": done})


func text() -> String:
	var t: Variant = steps[index].text
	var line: String = t.call() if t is Callable else t  # some steps show live numbers
	return "%d/%d  %s" % [index + 1, steps.size(), line]


## The place to point the beacon at, or null.
func marker() -> Variant:
	return steps[index].marker.call()


## Advances through any steps that are now done. `player` is the player's position on the ground plane.
func update(player: Vector2) -> void:
	while index < steps.size() - 1:
		var s: Dictionary = steps[index]
		var done: bool = s.done.call(player) if s.done.get_argument_count() > 0 else s.done.call()
		if not done:
			return
		index += 1


func _sold() -> int:
	var n := 0
	for m in _w.machines:
		if m.kind in ["bakery", "hot_dog_stand", "lemonade_stand"]:
			n += m.sold_total
	return n


func _nearest_drifter() -> Variant:
	var best: Drone = null
	var bd := INF
	for d in _w.drones:
		if d.kind == "drifter" and d.wallet < 10.0 and d.pos.distance_to(_cast.hot_dog.pos) < bd:
			bd = d.pos.distance_to(_cast.hot_dog.pos)
			best = d
	return best.pos if best else null
