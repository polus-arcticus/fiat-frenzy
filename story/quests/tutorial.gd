## The tutorial, as a set of goals checked against the model. A goal has a title, the text to show, an optional
## place to point the beacon at, a test that says it's done, a note explaining what the player just did, the goals that must be
## done before it opens (`after`), and what must be there for it to open at all (`ready`: a stand whose keeper has not come yet
## has nothing to fund). Goals with nothing in the way are open together, so the player can fund the stands in any order.
## The town grows as the hero puts up tents: its founders come in their order (Lodging.FOUNDERS), and the goals follow them.
## Nothing here changes the world: it only watches, so it needs no nodes and is tested headless like any other system. It is the
## HUD's Objectives (the user space's shape for what the hero is asked).
class_name Tutorial
extends Objectives

var goals: Array[Dictionary] = []
## How many goals are done.
var index := 0
## What the player has just done, in words, waiting for the HUD to show it (see take_news).
var news: Array[String] = []

var _w: World
var _town: Variant  # who is who, by role (Scenario.cast): a Dictionary, or a Callable that gives one as it is now
var _player := Vector2.ZERO

## What each founder brings, as the tent goal says who comes next.
const COMING := {"bottle_depot": "the bottle depot's attendant (bottles to cash: the town's money)", "first_aid": "a medic",
	"runner": "a cart runner (they fetch the stands' goods from the bins)", "lemonade_stand": "a lemonade seller",
	"bakery": "a baker", "thrift_stall": "a thrift seller (coats, of scrap)", "scrap_camp": "a camp keeper (boards, of scrap)",
	"hot_dog_stand": "a hot dog vendor"}


func _init(world: World, town: Variant, with_pickup := false) -> void:
	_w = world
	_town = town
	var gun := -1
	if with_pickup:
		gun = _goal("gun", "Take the gun", "Pick up the money gun at your feet: aim at it and press E.",
			func(): return _w.player.pos, func(): return _w.gun_owned,
			"You have the money gun. Hold left click to print money.")
	var walk := _goal("walk", "Meet the tent keeper", "Welcome to the station district. It's abandoned: all that is left is a tent city and its keeper, broke, hungry and cold. Walk over to the tent keeper. (Anyone with a gold glow needs your help.)",
		func(): return _pos("tent"), func(p): return p.distance_to(_pos("tent")) < 10.0,
		"", [gun])
	# The town comes a tent at a time, its founders in their order; their stands open goals of their own as they come.
	_goal("tent", "Put up tents", func(): return _tent_line(),
		func(): return _pos("tent"), func(): return _city() != null and _w.lodging.next_founder(_city()).is_empty(),
		"The tent city is full: the town is all here.", [walk])
	var fund_lemonade := _goal("lemonade", "Fund the lemonade seller", "Something to drink: the lemonade stand is wrecked. Aim at the seller and hold LEFT CLICK to spray $1 bills (GIFT mode). Every dollar you give fills the green bar over a head; fill it and their business levels up.",
		func(): return _pos("lemonade"), func(): return _working("lemonade"),
		"The lemonade stand is running: water from the fountain and leftovers from the bins become drinks.", [walk], _has.bind("lemonade"))
	var fund_baker := _goal("bakery", "Fund the baker", "Something to eat: the baker's stand is wrecked too. Gift about $50 so they can bake.",
		func(): return _pos("bakery"), func(): return _working("bakery"),
		"The bakery is running: bread to eat, and buns for hot dogs.", [walk], _has.bind("bakery"))
	_goal("hot_dog", "Fund the hot dog vendor", "Hot dogs: bread and leftovers, more filling for the money. The stand is wrecked: gift the vendor about $50.",
		func(): return _pos("hot_dog"), func(): return _working("hot_dog"),
		"The hot dog stand is running.", [walk], _has.bind("hot_dog"))
	_goal("eat", "Get someone fed", "People need money to buy food. Gift them until someone eats. Bills that miss land in the street: anyone can pick them up, and so can you. Whoever is short of cash takes bottles to the depot.",
		func(): return _nearest_needy(), func(): return _sold() >= 3,
		"Customers are buying: the money you printed is moving through the town.", [fund_lemonade, fund_baker])
	var invest := _goal("invest", "Buy a share of the bakery", "Scroll the mouse wheel to switch to INVEST. HOLD left click to charge a contract (the ring fills: the longer, the bigger), aim at the baker and RELEASE. You buy a share of the bakery (up to 49%), and the money goes to the baker. A contract that misses is void.",
		func(): return _pos("bakery"), func(): return _has("bakery") and _w.machine_of(_who("bakery")).equity.share(_w.ledger.local) > 0.05,
		"You own a share of the bakery: you get that share of everything it sells, forever.", [fund_baker])
	_goal("income", "Earn from your stake", "Every sale now pays you a share of the takings, forever. Keep the town fed until your stake has paid you $2.",
		func(): return null, func(): return _w.ledger.stake_income >= 2.0,
		"Your first income from a stake: the money works for you now.", [invest])
	var bankers := _goal("bankers", "Feed the bankers", "",
		func(): return _nearest_unfed_banker(), func(): return _w.quests.state.has(QuestBook.LETTER),
		"A banker has noticed what you have done for them, and wants a word.", [walk])
	goals[bankers].text = func(): return "Keep the bankers fed (%d of %d have had a meal): fund the stands and the people who sell, until they eat. Any of them will have a favour to ask, once all have." % [_fed_bankers(), _w.quests.bankers().size()]
	var every: Array = range(goals.size())
	_goal("loop", "Explore", "That's the loop. Every building in this district is waiting for someone: explore, and spray responsibly.",
		func(): return null, func(): return false, "", every)


## Adds a goal and returns its number. `after` lists the numbers of the goals that must be done first (-1: none); `ready`, if
## given, must say true as well.
func _goal(id: String, title: String, text: Variant, marker: Callable, done: Callable, note := "", after := [], ready := Callable()) -> int:
	var needs: Array[int] = []
	for a in after:
		if int(a) >= 0:
			needs.append(int(a))
	goals.append({"id": id, "title": title, "text": text, "marker": marker, "done": done, "note": note, "after": needs, "finished": false, "ready": ready})
	return goals.size() - 1


## Who is who now, by role (see `_town`).
func _cast() -> Dictionary:
	return _town.call() if _town is Callable else _town


func _who(role: String) -> Drone:
	return _cast().get(role)


func _has(role: String) -> bool:
	return _who(role) != null


func _pos(role: String) -> Variant:
	var d := _who(role)
	return d.pos if d != null else null


func _working(role: String) -> bool:
	return _has(role) and _w.machine_of(_who(role)).working


## The first market's tent city.
func _city() -> Machine:
	return _w.machine_of(_who("tent")) if _has("tent") else null


## The tent goal's line: who will come for the next tent, or that the town is all there.
func _tent_line() -> String:
	var city := _city()
	var next: Dictionary = _w.lodging.next_founder(city) if city != null else {}
	if next.is_empty():
		return "The tent city is full."
	return "The town is its tent city: press E at it and put up a tent (the gun pays $%d). The next to come and live in it: %s. Each comes with their stand, wrecked, and broke." % [int(Catalog.base_price("tent")), COMING.get(next.role, next.role)]


func _fed_bankers() -> int:
	return _w.quests.fed_count()


func _nearest_unfed_banker() -> Variant:
	var best: Variant = null
	var bd := INF
	for b in _w.quests.bankers():
		if not _w.quests.fed.has(b.uid) and b.pos.distance_to(_player) < bd:
			bd = b.pos.distance_to(_player)
			best = b.pos
	return best


## The goals that can be worked on now: not done, and everything they wait for is.
func open_goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in goals:
		if g.finished:
			continue
		var ready: bool = not g.ready.is_valid() or g.ready.call()
		for a in g.after:
			if not goals[a].finished:
				ready = false
		if ready:
			out.append(g)
	return out


func _line(g: Dictionary) -> String:
	var t: Variant = g.text
	return t.call() if t is Callable else t  # some goals show live numbers


## What to show: the main goal in full, and the others open beside it by name.
func text() -> String:
	var open := open_goals()
	if open.is_empty():
		return ""
	var out := "%d/%d  %s" % [index + 1, goals.size(), _line(open[0])]
	if open.size() > 1:
		var also: Array[String] = []
		for g in open.slice(1):
			also.append(g.title)
		out += "\n\nAlso open: " + "  ·  ".join(also)
	return out


## The place to point the beacon at: of the open goals that have one, the nearest to the player. Or null.
func marker() -> Variant:
	var best: Variant = null
	var bd := INF
	for g in open_goals():
		var m: Variant = g.marker.call()
		if m == null:
			continue
		var dist: float = _player.distance_to(m)
		if dist < bd:
			bd = dist
			best = m
	return best


## Notes any goals that are now done. `player` is the player's position on the ground plane.
func update(player: Vector2) -> void:
	_player = player
	var changed := true
	while changed:
		changed = false
		for g in open_goals():
			if g.id == "loop":
				continue  # the last goal is never done
			var done: bool = g.done.call(player) if g.done.get_argument_count() > 0 else g.done.call()
			if done:
				g.finished = true
				index += 1
				changed = true
				if g.note != "":
					news.append("Done: %s. %s" % [g.title, g.note])


## What the player has just done, for the HUD to say; empties the list.
func take_news() -> Array[String]:
	var out := news.duplicate()
	news.clear()
	return out


func _sold() -> int:
	var city := _city()
	if city == null:
		return 0
	var n := 0
	for m in _w.zones.machines_in(city.zone):  # (the first market's: the far one at the bank is not the lesson)
		if m.trade in ["bread", "meat", "drinks"]:  # (at whatever tier its owner has built it up to)
			n += m.sold_total
	return n


## Whoever of the town is shortest of money, near the market: someone to gift so they can buy.
func _nearest_needy() -> Variant:
	var city := _city()
	if city == null:
		return null
	var best: Drone = null
	for d in _w.lodging.housed(city):
		if d.wallet < 10.0 and (best == null or d.wallet < best.wallet):
			best = d
	return best.pos if best else null
