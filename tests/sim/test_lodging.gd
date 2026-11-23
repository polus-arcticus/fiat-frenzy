## Sim tests: the tent city, the cluster's spawn factory (see Lodging). Every test that moves money checks it is all accounted
## for.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


func _city(w: World, zone := "town") -> Machine:
	return w.zones.machines_in(zone).filter(func(m): return m.shelter != null)[0]


## The standard cluster, funded, everyone fed by hand.
func _town() -> Array:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "town")
	return [w, _city(w)]


func _run(w: World, seconds: int) -> void:
	Fixtures.run(w, seconds, true)


func test_everyone_in_a_cluster_has_a_tent_of_their_own() -> void:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	var city := _city(w)
	var people := w.zones.drones_in("town")
	check(city.working, "as a cluster is found, its tent city is standing (everything else is wrecked)")
	var home := city.residence
	check(people.all(func(d): return d.bed == city.uid) and home.tents == people.size(), "a tent each for its %d people" % people.size())
	check(people.any(func(d): return d.kind == "attendant" and d.bed == city.uid), "the bottle depot's attendant too")
	check(city.shelter.capacity == home.tents and people.all(func(d): return w.lodging.is_housed(d)), "each is housed, and so kept warm")
	var spots := people.map(func(d): return w.lodging.bed_of(city, d))
	check(Fixtures.spread(spots) >= Residence.TENT_WIDTH - 0.01, "each sleeps in their own tent, side by side (%.1f m apart)" % Fixtures.spread(spots))
	check(city.solid().enclosure.half.x > (home.tents - 1) * Residence.TENT_WIDTH * 0.5, "and the row's ground takes in every tent")
	check(w.machines.all(func(m): return (m.residence != null) == (m == city)), "the tent city is the one machine with homes (a Residence); the stalls have none")


func test_a_new_tent_brings_someone_new() -> void:
	var t := _town()
	var w: World = t[0]
	var city: Machine = t[1]
	var before := w.drones.size()
	_run(w, int(Lodging.ARRIVE_EVERY) + 2)
	check(w.drones.size() == before, "every tent lived in: nobody new comes")
	city.working = false
	var keeper := w.drone(city.owner)
	var saved := keeper.wallet
	keeper.wallet = 0.0  # (so they cannot put it back up meanwhile)
	w.ledger.printed -= saved
	w.lodging.add_tent(city)
	_run(w, int(Lodging.ARRIVE_EVERY) * 2)
	check(w.drones.size() == before, "nor while the tent city is wrecked, even with a tent empty")
	city.working = true
	keeper.wallet += saved  # (give it back: they may have been given a little meanwhile)
	w.ledger.printed += saved
	_run(w, int(Lodging.ARRIVE_EVERY) + 2)
	var newcomer: Drone = w.drones.back()
	check(w.drones.size() == before + 1 and newcomer.bed == city.uid and newcomer.zone == "town", "a tent empty in a standing tent city: someone new comes to live in it (%s)" % newcomer.label)
	check(w.lodging.free_tents(city) == 0 and newcomer in w.arrivals, "and takes it (and is there for the views)")
	check(_accounted(w), "they brought $%.0f: counted as printed" % Lodging.NEWCOMER_PURSE)
	_run(w, int(Lodging.ARRIVE_EVERY) * 2)
	check(w.drones.size() == before + 1, "and no more come")


func test_a_tent_city_holds_an_atoms_worth_until_it_is_built_up() -> void:
	var w := World.new()
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	w.begin_play()
	check(city.residence.tents == Atom.ROLES.size() and w.lodging.room_for(city) == 0, "an atom's tent city is full at its first tier: %d tents, one per role" % city.residence.tents)
	var printed := w.ledger.printed
	check(is_equal_approx(w.lodging.add_tent(city), 0.0) and city.residence.tents == Atom.ROLES.size() and is_equal_approx(w.ledger.printed, printed), "so no tent can be put up, and nothing is printed")
	city.retier("hostel")
	check(w.lodging.room_for(city) == Atom.ROLES.size(), "built up into a hostel, it has room for an atom's worth more")
	var cost := w.lodging.add_tent(city)
	check(is_equal_approx(cost, Catalog.base_price("tent")) and city.residence.tents == Atom.ROLES.size() + 1, "a tent costs $%.0f" % cost)
	check(is_equal_approx(w.ledger.printed - printed, cost) and is_equal_approx(w.ledger.sunk, cost) and _accounted(w), "the gun prints it, and it is spent (sunk)")


func test_the_atom_keeps_itself_going() -> void:
	var w := World.new(false)
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	var people := w.zones.drones_in("atom")
	var kinds := people.map(func(d): return d.kind)
	check(people.size() == Atom.ROLES.size() and kinds.count("vendor") == 3 and kinds.count("runner") == 2 and kinds.has("attendant") and kinds.has("medic"), "the atom: one of each role, and two runners for the bins (%s)" % [kinds])
	check(w.relief_trucks.is_empty() and not kinds.has("drifter"), "no van, and no drifters: they are each other's customers")
	check(w.hospitals.size() == 1 and w.hospitals[0].kind == "first_aid" and w.hospitals[0].beds() == 1 and w.ambulances.is_empty(), "its care is a medic's first aid post: one bed, no ambulance")
	check(city.working and w.zones.machines_in("atom").filter(func(m): return m.shelter == null).all(func(m): return not m.working), "found with the tent city standing and the stands wrecked")
	w.begin_play()
	Cluster.fund(w, "atom")
	var down := 0
	for i in int(Clock.DAY_SECONDS) * 10:
		w.tick(1.0)
	down = w.events.filter(func(e): return "collapsed" in e).size()
	check(down == 0 and Fixtures.sold(w, "atom") > 100, "funded once, it runs ten days on its own: nobody collapses, %d sold" % Fixtures.sold(w, "atom"))
	check(_accounted(w), "and the money is accounted for")


func test_the_medic_tends_whoever_is_down() -> void:
	var w := World.new()
	Atom.seed(w, "atom", Vector2.ZERO)
	var post: Hospital = w.hospitals[0]
	var people := w.zones.drones_in("atom").filter(func(d): return d.kind != "medic")
	people[0].bars.hunger = 0.0
	people[1].bars.thirst = 0.0
	w.tick(1.0)
	check(post.patients.size() == 1 and people[0].care == "patient" or people[1].care == "patient", "the medic takes the first of the two who went down into the one bed")
	check(people.filter(func(d): return d.care == "down").size() == 1, "the other waits, down, for the bed")


func test_tents_and_homes_are_saved_and_merged() -> void:
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
	for i in 3:
		a.lodging.add_tent(_city(a, tile))
	for i in 120:
		a.tick(1.0)
		b.tick(1.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(a).capture()))
	var fresh: World = build.call([tile])
	fresh.add_player(Vector2.ZERO, 0.0)
	Snapshot.new(fresh).apply(data)
	var city := _city(fresh, tile)
	check(city.residence.tents == _city(a, tile).residence.tents and fresh.lodging.housed(city).size() == a.lodging.housed(_city(a, tile)).size(), "a loaded save has the tent city's tents and who lives in them (%d tents)" % city.residence.tents)
	var m := Merge.combine(Snapshot.new(a).capture(), Snapshot.new(b).capture(), build)
	var merged := _city(m, tile)
	check(merged.residence.tents == _city(a, tile).residence.tents and merged.shelter.capacity == merged.residence.tents, "merged, the tent city has the tents the save that put them up had (Residence's MERGE: the most)")
	check(_accounted(m), "and the money is accounted for")
