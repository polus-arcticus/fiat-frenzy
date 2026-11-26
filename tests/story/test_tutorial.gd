## Sim tests: the tutorial follows the town as it grows (its founders come a tent at a time: Lodging.FOUNDERS), its goals open
## together where nothing is in the way, people who need help glow, and any banker gives the letter.
extends TestCase


## An atom as found (its tent city and keeper), three bankers, and the player. Returns [world, cast (a Callable: who is who now,
## as Scenario.cast is), bankers, tent city].
func _town() -> Array:
	var w := World.new()
	var city := Atom.seed(w, Zones.HOME, Vector2.ZERO)
	var bankers: Array[Drone] = []
	for i in 3:
		var b := w.add_drifter(Vector2(40 + i * 3, 0), 5.0)
		b.look = "banker"
		b.label = "Banker"
		bankers.append(b)
	w.add_player(Vector2(0, 20))
	return [w, func() -> Dictionary: return _roles(w, city), bankers, city]


## Who is who in `city`, by the story's names for them (Scenario.FOUNDER_CAST).
static func _roles(w: World, city: Machine) -> Dictionary:
	var out := {"tent": w.drone(city.owner)}
	for d in w.lodging.housed(city):
		var role := w.lodging.role_of(d)
		if Scenario.FOUNDER_CAST.has(role) and role != "runner":
			out[Scenario.FOUNDER_CAST[role]] = d
	return out


func test_the_goals_follow_the_town_as_it_grows() -> void:
	var t := _town()
	var w: World = t[0]
	var cast: Callable = t[1]
	var city: Machine = t[3]
	var tut := Tutorial.new(w, cast, false)
	check(tut.open_goals().size() == 1 and tut.open_goals()[0].id == "walk", "at first there is one goal: meet the tent keeper")
	tut.update(w.player.pos)
	check(tut.index == 0, "and nothing is done yet")
	w.player.pos = city.pos + Vector2(2, 2)
	tut.update(w.player.pos)
	var ids: Array = tut.open_goals().map(func(g): return g.id)
	check(ids.has("tent") and ids.has("bankers") and not ids.has("lemonade") and not ids.has("bakery"), "walking up opens putting up tents and the bankers; no stand to fund yet: %s" % str(ids))
	check(tut.text().contains("bottle depot"), "and the tent goal says who comes next: %s" % tut.text())
	Atom.grow(w, city, 4)  # (the depot, the medic, a runner, the lemonade seller)
	tut.update(w.player.pos)
	ids = tut.open_goals().map(func(g): return g.id)
	check(ids.has("lemonade") and not ids.has("bakery") and ids.has("tent"), "the lemonade seller has come: funding them opens, and the tents go on (%s)" % str(ids))
	check(tut.text().contains("baker"), "the next to come is the baker")
	Atom.grow(w, city)
	tut.update(w.player.pos)
	ids = tut.open_goals().map(func(g): return g.id)
	check(not ids.has("tent") and ids.has("bakery") and ids.has("hot_dog") and ids.has("lemonade"), "with everyone come, the tents are done, and every stand can be funded in any order (%s)" % str(ids))
	var news := tut.take_news()
	check(news.size() == 1 and news[0].contains("full") and tut.take_news().is_empty(), "what the player did is put in words once: %s" % str(news))
	check(not ids.has("eat") and not ids.has("income"), "what depends on the stands waits")
	w.machine_of(cast.call().bakery).working = true
	w.machine_of(cast.call().lemonade).working = true
	tut.update(w.player.pos)
	ids = tut.open_goals().map(func(g): return g.id)
	check(ids.has("eat") and ids.has("invest"), "with the bakery and the lemonade stand open, feeding people and investing open up")
	check(not ids.has("loop"), "the last goal waits for all the rest")


func test_the_beacon_points_at_the_nearest_open_goal() -> void:
	var t := _town()
	var w: World = t[0]
	Atom.grow(w, t[3])
	var cast: Dictionary = t[1].call()
	var tut := Tutorial.new(w, cast, false)
	w.player.pos = (cast.tent as Drone).pos
	tut.update(w.player.pos)
	w.player.pos = (w.machine_of(cast.lemonade) as Machine).pos + Vector2(1, 1)
	tut.update(w.player.pos)
	check(tut.marker() != null, "there is a beacon")
	var m: Vector2 = tut.marker()
	for id in ["hot_dog", "bakery", "lemonade"]:
		var d: Drone = cast[id]
		check(m.distance_to(w.player.pos) <= d.pos.distance_to(w.player.pos) + 0.01, "it points at something at least as near as the %s" % id)


func test_people_who_need_help_glow_until_they_have_it() -> void:
	var t := _town()
	var w: World = t[0]
	Atom.grow(w, t[3])
	var cast: Dictionary = t[1].call()
	var bankers: Array = t[2]
	var owner := w.add_vendor("bike_shop", Vector2(60, 0), 0.0, true, true)
	w.attention.step()
	check((cast.hot_dog as Drone).aura and (cast.bakery as Drone).aura and (cast.lemonade as Drone).aura, "vendors with wrecked stands glow")
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
	Atom.grow(w, t[3])
	var cast: Dictionary = t[1].call()
	var bankers: Array = t[2]
	for m in w.zones.machines_in(Zones.HOME):  # (every stand running)
		m.working = true
	for b in bankers:
		(b as Drone).bars.hunger = 0.2
	w.tick(1.0)
	for b in bankers:
		(b as Drone).bars.hunger = 0.9
	w.tick(1.0)
	check(w.quests.state.get(QuestBook.LETTER, "") == "offered", "all the bankers are fed: the letter is on offer")
	check(bankers.all(func(b): return w.quests.is_banker(b) and (b as Drone).profession == "Banker with a letter"), "and all of them say so, not just one")
	w.player.pos = (bankers[2] as Drone).pos + Vector2(0, 2)
	check(w.quests.objective().at == (bankers[2] as Drone).pos, "the beacon points at the nearest one, wherever you are")
	check(not w.quests.is_banker(cast.hot_dog) and not w.quests.is_banker(null), "a vendor is not a banker")


func test_the_tutorial_does_not_send_you_for_the_bike() -> void:
	var town := _town()
	var w: World = town[0]
	Atom.grow(w, town[3])
	var cast: Dictionary = town[1].call()
	cast["bike_shop"] = w.add_vendor("bike_shop", Vector2(-20, 0), 500.0, true, true)
	var t := Tutorial.new(w, cast, false)
	var mentions := 0
	for goal in t.goals:
		var line: Variant = goal.text
		var text: String = line.call() if line is Callable else line
		if text.to_lower().contains("bicycle") or text.to_lower().contains("bike"):
			mentions += 1
	check(mentions == 0, "no tutorial step mentions the bicycle: it is too dear to be a goal yet")
