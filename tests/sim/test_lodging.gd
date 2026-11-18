## Sim tests: the tent as the cluster's drone bay (see Lodging). Every test that moves money checks it is all accounted for.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


## The standard cluster, funded (its tent standing), everyone fed by hand.
func _town() -> Array:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "town")
	var tent: Machine = w.zones.machines_in("town").filter(func(m): return m.shelter != null)[0]
	tent.working = true
	return [w, tent]


func _run(w: World, seconds: int) -> void:
	Fixtures.run(w, seconds, true)


func test_everyone_in_a_cluster_has_a_bed() -> void:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	var tent: Machine = w.zones.machines_in("town").filter(func(m): return m.shelter != null)[0]
	var people := w.zones.drones_in("town").filter(func(d): return not d.needless)
	check(people.all(func(d): return d.bed == tent.uid) and tent.beds == people.size(), "a bed in the tent for each of its %d people" % people.size())
	check(tent.modules() == ceili(people.size() / 4.0) and tent.shelter.capacity == tent.beds, "four to a barrel: %d modules" % tent.modules())
	check(w.zones.drones_in("town").filter(func(d): return d.needless).all(func(d): return d.bed == ""), "(the welfare office's clerk has no needs, and no bed)")
	var k := tent.modules()
	check(tent.solid().enclosure.half.x > (k - 1) * Machine.MODULE_WIDTH * 0.5, "the tent's ground takes in all its modules")


func test_a_free_bed_draws_a_newcomer() -> void:
	var t := _town()
	var w: World = t[0]
	var tent: Machine = t[1]
	var before := w.drones.size()
	_run(w, int(Lodging.ARRIVE_EVERY) + 2)
	check(w.drones.size() == before, "every bed taken: nobody new comes")
	tent.working = false
	var keeper := w.drone(tent.owner)
	var saved := keeper.wallet
	keeper.wallet = 0.0  # (so they cannot put it back up meanwhile)
	w.ledger.printed -= saved
	w.lodging.add_bed(tent)
	_run(w, int(Lodging.ARRIVE_EVERY) * 2)
	check(w.drones.size() == before, "nor while the tent is wrecked, even with a bed free")
	tent.working = true
	keeper.wallet += saved  # (give it back: they may have been given a little meanwhile)
	w.ledger.printed += saved
	_run(w, int(Lodging.ARRIVE_EVERY) + 2)
	var newcomer: Drone = w.drones.back()
	check(w.drones.size() == before + 1 and newcomer.bed == tent.uid and newcomer.zone == "town", "a bed free in a standing tent: a newcomer comes for it (%s)" % newcomer.label)
	check(w.lodging.free_beds(tent) == 0 and newcomer in w.arrivals, "and takes it (and is there for the views)")
	check(_accounted(w), "they brought $%.0f: counted as printed" % Lodging.NEWCOMER_PURSE)
	_run(w, int(Lodging.ARRIVE_EVERY) * 2)
	check(w.drones.size() == before + 1, "and no more come")


func test_adding_a_bed_costs_more_when_it_needs_a_barrel() -> void:
	var t := _town()
	var w: World = t[0]
	var tent: Machine = t[1]
	w.lodging.set_beds(tent, 12)
	var printed := w.ledger.printed
	var sunk := w.ledger.sunk
	check(is_equal_approx(w.lodging.next_bed_cost(tent), Lodging.BED_COST + Lodging.BARREL_COST) and tent.modules() == 3, "12 beds fill three barrels: the 13th needs a new one ($%.0f)" % w.lodging.next_bed_cost(tent))
	var cost := w.lodging.add_bed(tent)
	check(tent.beds == 13 and tent.modules() == 4 and is_equal_approx(cost, Lodging.BED_COST + Lodging.BARREL_COST), "so it costs a bed and a barrel, and the tent grows a module")
	check(is_equal_approx(w.lodging.next_bed_cost(tent), Lodging.BED_COST), "the next one only a bed")
	check(is_equal_approx(w.ledger.printed - printed, cost) and is_equal_approx(w.ledger.sunk - sunk, cost) and _accounted(w), "the gun prints it, and it is spent (sunk)")
	tent.retier("hostel")
	check(tent.beds_per_barrel() == 8 and tent.modules() == 2 and tent.beds == 13, "a hostel's barrels warm eight beds each: the same beds in two modules")


func test_taking_a_bed_away() -> void:
	var t := _town()
	var w: World = t[0]
	var tent: Machine = t[1]
	w.lodging.add_bed(tent)
	var count := w.drones.size()
	check(w.lodging.remove_bed(tent) == null and w.drones.size() == count and w.lodging.free_beds(tent) == 0, "a free bed simply goes")
	var leaver := w.lodging.who_would_leave(tent)
	var money := leaver.wallet
	var sunk := w.ledger.sunk
	var left = w.lodging.remove_bed(tent)
	check(left == leaver and leaver.kind == "drifter" and leaver.gone and not leaver in w.drones, "with every bed taken, the newest drifter packs up and leaves town (%s)" % leaver.label)
	check(is_equal_approx(w.ledger.sunk - sunk, money) and _accounted(w), "with their $%.2f: gone from the world, and accounted for" % money)
	check(w.thing(leaver.uid) == null and tent.beds == w.lodging.housed(tent).size(), "and nobody refers to them any more")
	while w.lodging.who_would_leave(tent) != null:
		w.lodging.remove_bed(tent)
	check(w.lodging.remove_bed(tent) is bool and w.lodging.housed(tent).all(func(d): return d.kind != "drifter"), "those who run the town's businesses never leave this way")


func test_beds_and_homes_are_saved_and_merged() -> void:
	var build := func(tiles: Array) -> World:
		var w := World.new()
		for k in tiles:
			w.zones.add_tile(k)
			Cluster.build(w, k, TileKey.rect(k).get_center())
		return w
	var t0 := TileKey.parse(TileKey.of(50.1086307, 8.6687641))
	var tile := TileKey.key(t0.x, t0.y)
	var a: World = build.call([tile])
	var b: World = build.call([tile])
	for w in [a, b]:
		w.add_player(Vector2.ZERO, 10.0)
		w.gun_owned = true
		w.begin_play()
	var tent_of := func(w: World) -> Machine: return w.zones.machines_in(tile).filter(func(m): return m.shelter != null)[0]
	for i in 3:
		a.lodging.add_bed(tent_of.call(a))
	for i in 120:
		a.tick(1.0)
		b.tick(1.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(a).capture()))
	var fresh: World = build.call([tile])
	fresh.add_player(Vector2.ZERO, 0.0)
	Snapshot.new(fresh).apply(data)
	var tent: Machine = tent_of.call(fresh)
	check(tent.beds == tent_of.call(a).beds and fresh.lodging.housed(tent).size() == a.lodging.housed(tent_of.call(a)).size(), "a loaded save has the tent's beds and who sleeps in them (%d beds)" % tent.beds)
	var m := Merge.combine(Snapshot.new(a).capture(), Snapshot.new(b).capture(), build)
	check(tent_of.call(m).beds == tent_of.call(a).beds and tent_of.call(m).shelter.capacity == tent_of.call(m).beds, "merged, the tent has the beds the save that added them had")
	check(_accounted(m), "and the money is accounted for")
