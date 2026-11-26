## Sim tests: the market by the European Central Bank's gate, on the real map. The hero gets off the tram hungry and
## thirsty, and finds stands to invest in: they stand clear of the buildings, are a zone of their own (so the first market's
## people do not trek to them), the hero's zone follows them there, and money put into them starts the little economy.
extends TestCase


func _scenario() -> Scenario:
	return Fixtures.scenario()


## The bank's market's people (its atom's), but its attendant (who has no needs).
func _people(w: World, sc: Scenario) -> Array:
	return w.lodging.housed(sc.ecb_market).filter(func(d): return not d.needless)


func _clearance(sc: Scenario, p: Vector2) -> float:
	var best := INF
	for bd in sc.district.buildings:
		var poly := MapSites.pts(bd.poly)
		if Geometry2D.is_point_in_polygon(p, poly):
			return 0.0
		for i in poly.size():
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best


func test_the_market_is_a_zone_of_its_own_at_the_tram_stop() -> void:
	var sc := _scenario()
	var w := sc.build()
	check(sc.ecb_region.has_point(sc.ecb_stop.at) and sc.ecb_region.has_point(sc.ecb.door) and sc.ecb_region.has_point(sc.ecb_gate.pad) and sc.ecb_region.has_point(sc.ecb_gate.entrance), "the bank's zone covers the stop, the gate, the shuttle's pad and the door")
	var east := w.transit.vehicle(Scenario.TRAM_QUEST).line
	var breaks: Vector2 = east.stops[east.stop_called(Scenario.TRAM_BREAKS_AT)].at
	check(not sc.ecb_region.has_point(sc.start) and not sc.ecb_region.has_point(breaks) and not sc.ecb_region.has_point(sc.sage_house.door), "and not the first market, nor where the tram breaks down, nor Mr. Nobody's house")
	var machines := w.zones.machines_in(Scenario.ECB_ZONE)
	var kinds := machines.map(func(m): return m.kind)
	check(["tent", "lemonade_stand", "bakery", "thrift_stall", "scrap_camp", "hot_dog_stand"].all(func(k): return k in kinds), "an atom grown at once: its tent city and every founder's stand (%s)" % [kinds])
	var furthest: float = machines.reduce(func(far, m): return maxf(far, m.pos.distance_to(sc.ecb_stop.at)), 0.0)
	check(machines.all(func(m): return m.working == (m.residence != null)) and furthest < 150.0, "the stands all wrecked, and within a short walk of where the tram stops (%.0f m at most)" % furthest)
	var bins: Array = w.zones.bins_in(Scenario.ECB_ZONE).map(func(b): return b.kind)
	check(bins.has("organics") and bins.has("fountain") and w.zones.runners_in(Scenario.ECB_ZONE).size() == 1, "with bins and a fountain to feed them, and a cart runner (%s)" % [bins])
	check(w.hospitals.filter(func(h): return h.zone == Scenario.ECB_ZONE and h.kind == "first_aid").size() == 1 and w.deposit.depot_in(Scenario.ECB_ZONE) != null, "and its first aid post and bottle depot")
	check(w.zones.drones_in(Scenario.ECB_ZONE).filter(func(d): return d.bed == sc.ecb_market.uid).size() == Atom.size(), "its people are its founders and keeper (%d)" % Atom.size())
	check(w.lodging.housed(sc.market).size() == 1 and w.deposit.depot_in(Zones.HOME) == null, "while the first market is only its tent keeper, until the hero puts up tents")


func test_the_stands_stand_clear_of_the_buildings() -> void:
	var sc := _scenario()
	var w := sc.build()
	for m in w.zones.machines_in(Scenario.ECB_ZONE):
		check(_clearance(sc, m.pos) > 1.0 and _clearance(sc, m.post()) > 1.0, "the %s and its keeper are clear of every building (%.1f m)" % [m.display_name().to_lower(), _clearance(sc, m.pos)])
	for b in w.zones.bins_in(Scenario.ECB_ZONE):
		check(_clearance(sc, b.pos) > 1.0, "the %s is clear of every building (%.1f m)" % [b.kind, _clearance(sc, b.pos)])
	for h in w.hospitals:
		check(_clearance(sc, h.pos) > 1.0, "the medical tent is clear of every building (%.1f m)" % _clearance(sc, h.pos))


func test_the_heros_zone_follows_where_they_are() -> void:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.start, 25.0)
	check(w.player.zone == Zones.HOME, "at the start, home")
	w.tick(0.1)
	check(w.player.zone == Zones.HOME, "and still, after a tick")
	w.player.pos = sc.ecb_stop.at
	w.tick(0.1)
	check(w.player.zone == Scenario.ECB_ZONE, "getting off the tram for the bank is the bank's zone")
	w.player.pos = sc.ecb.door
	w.tick(0.1)
	check(w.player.zone == Scenario.ECB_ZONE, "and so is the bank's door")
	w.player.pos = sc.start
	w.tick(0.1)
	check(w.player.zone == Zones.HOME, "back at the first market, home again")
	var a := _scenario().build()
	check(a.player == null, "(no hero, no zone to follow)")


func test_the_first_markets_people_do_not_go_to_the_banks_stands() -> void:
	var sc := _scenario()
	var w := sc.build()
	for m in w.zones.machines_in(Scenario.ECB_ZONE):
		m.working = true
		m.output.add(m.item, 5)
	var hungry: Drone = sc.cast.tent  # (the first market's tent keeper)
	hungry.wallet = 20.0
	check(w.logistics.supply.best_supply(hungry, "food") == null and w.logistics.supply.best_supply(hungry, "drink") == null, "with only the bank's stands open, someone at the first market finds nothing to walk to")
	var local := w.add_drifter(sc.ecb_market.pos + sc.ecb_market.front * 3.0, 20.0)
	local.zone = Scenario.ECB_ZONE
	w.zones.invalidate()
	check(w.logistics.supply.best_supply(local, "drink") != null, "while someone at the bank does")


func test_money_put_into_the_banks_stands_starts_the_economy_there() -> void:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.ecb_stop.at, 25.0)
	var lemonade: Drone = sc.cast.ecb_lemonade
	var stand := w.machine_of(lemonade)
	for i in 20:
		w.tick(1.0)
	check(not stand.working, "left alone, the stand stays wrecked")
	var stake := w.gun.invest(lemonade, 60.0)  # (the most a stranger may own is 49% of what it is worth: the rest is a gift)
	check(stake > 0.0 and stake <= 0.49 + 0.001, "the hero can buy into it (a %.0f%% stake)" % (stake * 100.0))
	w.gun.gift(lemonade, 30.0)
	var waited := 0
	while not stand.working and waited < 900:
		w.tick(1.0)
		waited += 1
	check(stand.working, "the seller fixes it up with what was put in (%d s)" % waited)
	var visitors := _people(w, sc).filter(func(d): return d != lemonade)  # (the bank's market's own people: anyone thirsty)
	for v in visitors:
		v.bars.thirst = 0.1
		v.wallet = 8.0
	for i in 1500:
		w.tick(1.0)
	check(stand.sold_total > 0 or stand.crafted_total > 0, "it makes lemonade (%d made, %d sold) from what the food bank gives it" % [stand.crafted_total, stand.sold_total])
	check(visitors.any(func(v): return v.bars.thirst > 0.3), "and a thirsty visitor has had a drink (%s)" % [visitors.map(func(v): return snappedf(v.bars.thirst, 0.01))])
	# (The first market's owners may have mended their stands meanwhile, on the deposit on their bottles: but nothing of the hero's.)
	var first_market_untouched := w.zones.drones_in(Zones.HOME).filter(func(d): return d.kind == "vendor" and d.label != "" and not d.needless).all(func(d): return d.growth.xp == 0.0)
	check(first_market_untouched, "and none of what the hero put in at the bank reached the first market: the zones do not mix")


func test_money_the_hero_prints_at_the_bank_is_for_the_banks_people() -> void:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.ecb_stop.at + Vector2(2, 2), 25.0)
	w.tick(0.1)
	var visitor: Drone = sc.cast.ecb_runners[0]  # (one of the bank's market's people, who picks up loose money)
	var before := visitor.wallet
	var b := w.gun.fire(2.0, "gift")
	check(b.zone == Scenario.ECB_ZONE, "a bill fired at the bank belongs to the bank's zone")
	w.gun.land(b, visitor.pos + Vector2(1.5, 0))
	for i in 60:
		w.tick(1.0)
	check(visitor.wallet > before or not b.loose, "and a visitor there picks it up (wallet $%.2f -> $%.2f)" % [before, visitor.wallet])
	var far: Drone = sc.cast.tent
	check(far.zone == Zones.HOME and far.wallet == 0.0, "while the first market's people did not take it")


func test_the_banks_people_wait_fresh_until_the_hero_arrives() -> void:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.start)
	var visitors := _people(w, sc)
	var before := visitors.map(func(d): return d.bars.duplicate())
	for i in 600:
		w.tick(1.0)
	check(range(visitors.size()).all(func(i): return visitors[i].bars == before[i]) and not w.is_active(Scenario.ECB_ZONE), "before the hero comes, the bank's people have not aged a second")
	w.player.pos = sc.ecb_stop.at
	w.tick(1.0)
	check(w.is_active(Scenario.ECB_ZONE), "and the zone runs from the moment the hero is in it")
	w.player.pos = sc.start
	w.tick(1.0)
	check(w.is_active(Scenario.ECB_ZONE), "and stays running when they leave")
