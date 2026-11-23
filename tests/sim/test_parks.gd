## Sim tests: a tile's parks (OsmDressing's green, World.parks) and the homeless camps in them: the one a tile's nearest park
## gets at landing (SiteFinder.camp, by one rule, the same for everyone, near enough on foot), the ones the hero founds with a
## camp kit (Placing, Camp.found), each with its own fire; and the night wind in a park (Cold.PARK_NIGHT, the hero only).
extends TestCase


# The fixture tile with a park over all of it (where the camp goes is then the rule's to say).
func _parked() -> Dictionary:
	var d := Fixtures.tile_district()
	var r := TileKey.rect(Fixtures.tile_key())
	d["green"] = {"areas": [{"kind": "green", "poly": PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])}],
		"trees": PackedVector2Array()}
	return d


func test_a_tile_s_park_gets_a_camp_near_its_market() -> void:
	var d := _parked()
	var landing := TileLanding.new(Fixtures.tile_key(), d, Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var w := landing.build()
	var camps: Array = w.machines.filter(func(m): return m.kind == "scrap_camp")
	check(camps.size() == 1 and w.parks.size() == 1, "one camp, in the park")
	var camp: Machine = camps[0]
	var walk := TileLanding.walked(w, landing.market, camp.pos)
	check(walk <= SiteFinder.CAMP_WALK, "a short walk from the market (%.0f m)" % walk)
	var near_fire: bool = w.fires.any(func(f): return f.pos.distance_to(camp.pos) < 4.0)
	check(near_fire and w.drone(camp.owner).bed == "", "with a fire of its own, which its keeper lives by")
	var things: Array = w.machines + w.hospitals + w.bottle_depots
	check(things.all(func(o): return o == camp or o.pos.distance_to(camp.pos) >= SiteFinder.CAMP_APART), "clear of the market's stalls")
	check(landing.landmarks(w).any(func(m): return m.label == "camp"), "and on the map")
	var again := TileLanding.new(Fixtures.tile_key(), _parked(), Fixtures.TILE_LAT, Fixtures.TILE_LON)
	again.build()
	check(again.camp.at == landing.camp.at, "the same spot every time, for everyone")


func test_no_camp_without_a_park_near_enough() -> void:
	var bare := TileLanding.new(Fixtures.tile_key(), Fixtures.tile_district(), Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var w := bare.build()
	check(bare.camp.is_empty() and not w.machines.any(func(m): return m.kind == "scrap_camp"), "no park: no camp")
	var far := SiteFinder.camp(_parked(), Fixtures.tile_key(), bare.market, func(_at: Vector2) -> float: return 500.0)
	check(far.is_empty(), "a park that's a long walk round: no camp (its people would spend their day on the road)")


func test_the_hero_pitches_a_camp_in_a_park() -> void:
	var w := World.new()
	w.parks.append(PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)]))
	w.add_player(Vector2(60, 0)).make_needless()
	w.player.carry.add("camp_kit", 1)
	check(Catalog.item("camp_kit").use() == "place", "a camp kit is put down")
	check(w.placing.why_not("camp_kit", Vector2(64, 0)) == "A camp goes in a park.", "not in the street")
	w.player.pos = Vector2(40, 0)
	var people := w.drones.size()
	var fires := w.fires.size()
	var r := w.placing.place("camp_kit", Vector2(36, 0), Vector2(1, 0))
	var camp: Machine = w.machines.back()
	check(r.ok and camp.kind == "scrap_camp" and w.player.carry.count("camp_kit") == 0, "in the park, it's a camp (%s)" % r.text)
	check(w.drones.size() == people + 1 and w.drone(camp.owner).arrived_at >= 0.0, "kept by a newcomer")
	check(w.fires.size() == fires + 1 and w.arrivals.has(camp) and w.arrivals.has(w.fires.back()), "with its own fire; the views are told")
	var bare := World.new()
	bare.add_player(Vector2.ZERO).make_needless()
	bare.player.carry.add("camp_kit", 1)
	check(bare.placing.why_not("camp_kit", Vector2(3, 0)) == "There's no park here for a camp.", "a map with no parks says so")


func test_the_tent_keeper_makes_camp_kits_of_scrap() -> void:
	var tent := Catalog.machine("tent")
	check(tent.wares.has("camp_kit") and tent.wares.camp_kit.has("scrap"), "the tent keeper makes them, of scrap (%s)" % tent.wares.get("camp_kit"))


func test_the_night_wind_in_a_park() -> void:
	check(Cold.spans(true).y < Cold.spans().y and Cold.spans(true).x == Cold.spans().x, "a park is colder at night, not by day")
	var w := World.new()
	w.parks.append(PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)]))
	w.add_player(Vector2.ZERO)
	w.clock.time = 0.6 * Clock.DAY_SECONDS  # (night)
	check(w.clock.is_night(), "(it is night)")
	w.hero.step(0.1)
	check(is_equal_approx(w.player.cold_spans.y, Cold.spans(true).y), "in the park the hero's bar lasts less")
	check(w.events.any(func(e): return "wind comes across the park" in e), "and the feed says so, once")
	w.player.pos = Vector2(200, 0)
	w.hero.step(0.1)
	check(is_equal_approx(w.player.cold_spans.y, Cold.spans().y), "out of it, as it was")
	w.player.cold_spans = Vector2.ZERO
	w.hero.step(0.1)
	check(w.player.cold_spans == Vector2.ZERO, "and a hero hardened to it (a test's) stays hardened")
