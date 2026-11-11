## Sim tests: the tutorial's parallel goals, the gold glow on people who need help, and any banker giving the letter.
extends TestCase


## The four stands (wrecked), three bankers, and the player. Returns [world, cast, bankers].
func _town() -> Array:
	var w := World.new()
	var cast := {}
	cast["hot_dog"] = w.add_vendor("hot_dog_stand", Vector2(0, 0), 0.0, false, false)
	cast["bakery"] = w.add_vendor("bakery", Vector2(5, 0), 0.0, false, false)
	cast["tent"] = w.add_vendor("tent", Vector2(10, 0), 0.0, false, false)
	cast["lemonade"] = w.add_vendor("lemonade_stand", Vector2(15, 0), 0.0, false, false)
	var bankers: Array[Drone] = []
	for i in 3:
		var b := w.add_drifter(Vector2(40 + i * 3, 0), 5.0)
		b.look = "banker"
		b.label = "Banker"
		bankers.append(b)
	w.add_player(Vector2(0, 20))
	return [w, cast, bankers]


func test_the_stands_can_be_funded_in_any_order() -> void:
	var t := _town()
	var w: World = t[0]
	var cast: Dictionary = t[1]
	var tut := Tutorial.new(w, cast, false)
	check(tut.open_goals().size() == 1 and tut.open_goals()[0].id == "walk", "at first there is one goal: meet the vendors")
	tut.update(w.player.pos)
	check(tut.index == 0, "and nothing is done yet")
	w.player.pos = (w.machine_of(cast.hot_dog) as Machine).pos + Vector2(2, 2)
	tut.update(w.player.pos)
	var ids: Array = tut.open_goals().map(func(g): return g.id)
	check(ids.has("hot_dog") and ids.has("bakery") and ids.has("tent") and ids.has("lemonade") and ids.has("bankers"), "walking up opens all the funding goals at once, with the bankers: %s" % str(ids))
	check(not ids.has("eat") and not ids.has("income"), "but what depends on them waits")
	w.machine_of(cast.tent).working = true  # the last one first
	tut.update(w.player.pos)
	check(tut.index == 2 and not (tut.open_goals().map(func(g): return g.id)).has("tent"), "funding the tent first is fine: it is done")
	check(tut.text().contains("Also open:") and tut.text().contains("Fund the baker"), "and the text names the others open beside it")
	var news := tut.take_news()
	check(news.size() == 1 and news[0].contains("tent") and tut.take_news().is_empty(), "what the player did is put in words once: %s" % str(news))
	w.machine_of(cast.hot_dog).working = true
	w.machine_of(cast.bakery).working = true
	tut.update(w.player.pos)
	ids = tut.open_goals().map(func(g): return g.id)
	check(ids.has("eat") and ids.has("invest"), "with the hot dog stand and the bakery open, feeding people and investing open up")
	check(not ids.has("loop"), "the last goal waits for all the rest")


func test_the_beacon_points_at_the_nearest_open_goal() -> void:
	var t := _town()
	var w: World = t[0]
	var cast: Dictionary = t[1]
	var tut := Tutorial.new(w, cast, false)
	w.player.pos = (w.machine_of(cast.hot_dog) as Machine).pos
	tut.update(w.player.pos)
	w.player.pos = (w.machine_of(cast.lemonade) as Machine).pos + Vector2(1, 1)
	tut.update(w.player.pos)
	check(tut.marker() != null, "there is a beacon")
	var m: Vector2 = tut.marker()
	for id in ["hot_dog", "bakery", "tent"]:
		var d: Drone = cast[id]
		check(m.distance_to(w.player.pos) <= d.pos.distance_to(w.player.pos) + 0.01, "it points at something at least as near as the %s" % id)


func test_people_who_need_help_glow_until_they_have_it() -> void:
	var t := _town()
	var w: World = t[0]
	var cast: Dictionary = t[1]
	var bankers: Array = t[2]
	var owner := w.add_vendor("bike_shop", Vector2(60, 0), 0.0, true, true)
	w.attention.step()
	check((cast.hot_dog as Drone).aura and (cast.bakery as Drone).aura and (cast.tent as Drone).aura, "vendors with wrecked stands glow")
	check(not owner.aura, "the rich bike shop owner does not")
	check(bankers.all(func(b): return b.aura), "and the bankers who have not yet had a meal")
	w.machine_of(cast.hot_dog).working = true
	(bankers[0] as Drone).bars.hunger = 0.2
	w.tick(1.0)
	(bankers[0] as Drone).bars.hunger = 0.9
	w.tick(1.0)
	check(not (cast.hot_dog as Drone).aura, "once the stand runs, the glow goes out")
	check(not (bankers[0] as Drone).aura and (bankers[1] as Drone).aura, "and a banker who has eaten stops glowing, the others do not")
	check(w.events.any(func(e): return e.contains("proper meal (1 of 3")), "with a line in the feed saying so")


func test_any_banker_can_give_the_letter() -> void:
	var t := _town()
	var w: World = t[0]
	var cast: Dictionary = t[1]
	var bankers: Array = t[2]
	for key in ["hot_dog", "bakery", "tent", "lemonade"]:
		w.machine_of(cast[key]).working = true
	for b in bankers:
		(b as Drone).bars.hunger = 0.2
	w.tick(1.0)
	for b in bankers:
		(b as Drone).bars.hunger = 0.9
	w.tick(1.0)
	check(w.quests.state.get(QuestBook.LETTER, "") == "offered", "all the bankers are fed: the letter is on offer")
	check(bankers.all(func(b): return w.quests.is_banker(b) and (b as Drone).label == "Banker with a letter"), "and all of them say so, not just one")
	w.player.pos = (bankers[2] as Drone).pos + Vector2(0, 2)
	check(w.quests.objective().at == (bankers[2] as Drone).pos, "the beacon points at the nearest one, wherever you are")
	check(not w.quests.is_banker(cast.hot_dog) and not w.quests.is_banker(null), "a vendor is not a banker")
