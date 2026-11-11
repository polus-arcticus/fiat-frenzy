## The tutorial, as a set of goals checked against the model. A goal has a title, the text to show, an optional
## place to point the beacon at, a test that says it's done, a note explaining what the player just did, and the
## goals that must be done before it opens (`after`). Goals with nothing in the way are open together, so the player
## can fund the stands in any order. Nothing here changes the world: it only watches, so it needs no nodes and is
## tested headless like any other system.
class_name Tutorial
extends RefCounted

var goals: Array[Dictionary] = []
## How many goals are done.
var index := 0
## What the player has just done, in words, waiting for the HUD to show it (see take_news).
var news: Array[String] = []

var _w: World
var _cast: Dictionary
var _player := Vector2.ZERO


func _init(world: World, cast: Dictionary, with_pickup := false) -> void:
	_w = world
	_cast = cast
	var hot: Drone = cast.hot_dog
	var baker: Drone = cast.bakery
	var tent: Drone = cast.tent
	var gun := -1
	if with_pickup:
		gun = _goal("gun", "Take the gun", "Pick up the money gun at your feet: aim at it and press E.",
			func(): return _w.player.pos, func(): return _w.gun_owned,
			"You have the money gun. Hold left click to print money.")
	var walk := _goal("walk", "Meet the vendors", "Welcome to the station district. It's abandoned, and everyone left in it is broke, hungry and cold. Walk over to the hot dog vendor. (Anyone with a gold glow needs your help.)",
		func(): return hot.pos, func(p): return p.distance_to(hot.pos) < 10.0,
		"", [gun])
	# Everything below is open at the same time: do it in whatever order suits.
	var fund_hot := _goal("hot_dog", "Fund the hot dog vendor", "His stand is wrecked and he has nothing. Aim at him and hold LEFT CLICK to spray $1 bills (GIFT mode). Repairs cost about $50. Every dollar you give fills the green bar over a head; fill it and their business levels up.",
		func(): return hot.pos, func(): return _w.machine_of(hot).working,
		"The hot dog stand is running: he can cook and sell now. His glow went out because he has what he needs.", [walk])
	var fund_baker := _goal("bakery", "Fund the baker", "Hot dogs need buns. The baker's stand is wrecked too: gift him about $50 so he can bake.",
		func(): return baker.pos, func(): return _w.machine_of(baker).working,
		"The bakery is running: bread to eat, and buns for the hot dogs.", [walk])
	_goal("tent", "Fund the tent keeper", "Night falls at 8:30pm and it gets bitter. Fund the tent keeper (and use the free barrel fire) or your drifters freeze.",
		func(): return tent.pos, func(): return _w.machine_of(tent).working,
		"The tent is open: beds out of the cold at night.", [walk])
	var lemonade: Drone = cast.get("lemonade")
	if lemonade != null:
		_goal("lemonade", "Fund the lemonade seller", "Something to drink: the lemonade stand is wrecked too.",
			func(): return lemonade.pos, func(): return _w.machine_of(lemonade).working,
			"The lemonade stand is running: water and sugar from the food bank become drinks.", [walk])
	_goal("eat", "Get someone fed", "The Red Cross van brings a few free supplies twice a day. Now the drifters need money to buy food. Gift them until someone eats. Bills that miss land in the street: anyone can pick them up, and so can you.",
		func(): return _nearest_drifter(), func(): return _sold() >= 3,
		"Customers are buying: the money you printed is moving through the town.", [fund_hot, fund_baker])
	var invest := _goal("invest", "Buy a share of the bakery", "Scroll the mouse wheel to switch to INVEST. HOLD left click to charge a contract (the ring fills: the longer, the bigger), aim at the baker and RELEASE. You buy a share of his bakery (up to 49%), and the money goes to him. A contract that misses is void.",
		func(): return baker.pos, func(): return _w.machine_of(baker).equity.stake > 0.05,
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


## Adds a goal and returns its number. `after` lists the numbers of the goals that must be done first (-1: none).
func _goal(id: String, title: String, text: Variant, marker: Callable, done: Callable, note := "", after := []) -> int:
	var needs: Array[int] = []
	for a in after:
		if int(a) >= 0:
			needs.append(int(a))
	goals.append({"id": id, "title": title, "text": text, "marker": marker, "done": done, "note": note, "after": needs, "finished": false})
	return goals.size() - 1


func _fed_bankers() -> int:
	return _w.quests.fed_count()


func _nearest_unfed_banker() -> Variant:
	var best: Variant = null
	var bd := INF
	for b in _w.quests.bankers():
		if not _w.quests.fed.has(b.id) and b.pos.distance_to(_player) < bd:
			bd = b.pos.distance_to(_player)
			best = b.pos
	return best


## The goals that can be worked on now: not done, and everything they wait for is.
func open_goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in goals:
		if g.finished:
			continue
		var ready := true
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
