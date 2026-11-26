## Sim tests: an atom grows by the one mechanic there is. Each tent the hero puts up in its tent city brings someone, and the
## first to come are its founders, always in the same order (Lodging.FOUNDERS): the bottle depot, the medic, a runner, the
## lemonade stand, the bakery, the thrift stall, the camp, the hot dog stand. A business comes wrecked and its keeper broke.
## After them the dice (drifters and runners).
extends TestCase

const ORDER := ["bottle_depot", "first_aid", "runner", "lemonade_stand", "bakery", "thrift_stall", "scrap_camp", "hot_dog_stand"]


func _atom() -> Array:
	var w := World.new(false)
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	return [w, city]


## The hero puts up a tent and waits for whoever comes for it. Returns who came (the new drone).
func _arrival(w: World, city: Machine) -> Drone:
	var before := w.drones.size()
	w.lodging.add_tent(city)
	Fixtures.run(w, int(Lodging.ARRIVE_EVERY) + 1, true)
	return w.drones[before] if w.drones.size() > before else null


func _role(w: World, d: Drone) -> String:
	if d == null:
		return "nobody"
	return w.lodging.role_of(d)


func test_an_atom_starts_as_a_tent_city_and_its_keeper() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	check(w.drones.size() == 1 and w.drones[0].bed == city.uid and city.working, "one person: the tent keeper, in the one tent of a standing tent city")
	check(w.bins.size() == 4 and w.fires.size() == 1 and w.bottle_depots.is_empty() and w.hospitals.is_empty(), "its bins and a fire, and nothing else yet")
	check(w.lodging.free_tents(city) == 0 and w.lodging.room_for(city) == Lodging.FOUNDERS.size(), "nobody comes until the hero puts up a tent; there is room for every founder (%d)" % w.lodging.room_for(city))
	check(city.residence.slots.size() == Lodging.FOUNDERS.size(), "a place on the street is kept for each of them")


func test_each_tent_brings_the_next_founder_in_order() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	var came: Array = []
	for i in ORDER.size():
		var d := _arrival(w, city)
		came.append(_role(w, d))
		if d == null:
			break
		check(d.bed == city.uid, "the %s lives in the tent the hero put up" % came[-1])
	check(came == ORDER, "they came in the order: %s" % [came])
	var stalls := w.machines.filter(func(m): return m.residence == null)
	check(stalls.all(func(m): return not m.working and w.drone(m.owner).wallet == 0.0), "every business came wrecked, its keeper broke (%d of them)" % stalls.size())
	check(w.bottle_depots.size() == 1 and w.hospitals.size() == 1 and w.hospitals[0].kind == "first_aid" and w.zones.runners_in("atom").size() == 1, "one bottle depot, one first aid post, one runner")
	check(w.lodging.room_for(city) == 0, "and the tent city is full at its first tier")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "the money adds up (the tents were printed and sunk)")


func test_grown_at_once_it_is_the_same_town() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	var came := Atom.grow(w, city)
	check(came.map(func(d): return _role(w, d)) == ORDER, "Atom.grow brings the same founders in the same order, without the wait")
	check(Atom.grow(w, city).is_empty(), "and once they are all there, no more")


func test_after_the_founders_nobody_comes() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	Atom.grow(w, city)
	w.lodging.set_tents(city, city.residence.tents + 2)  # (as if built up: room past the first tier)
	var people := w.drones.size()
	var stalls := w.machines.size()
	Fixtures.run(w, int(Lodging.ARRIVE_EVERY) * 3, true)
	check(w.drones.size() == people and w.machines.size() == stalls, "the town is its founders: empty tents past them stay empty (%d people)" % w.drones.size())


func test_a_second_tent_city_mirrors_the_first() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	Atom.grow(w, city, 3)  # (the depot, the medic and a runner)
	var second := w.lodging.found(Vector2(60, 20), Vector2(0, -1), "atom")
	var came: Array = []
	for i in 3:
		came.append(_role(w, _arrival(w, second)))
	check(came == ORDER.slice(0, 3), "a tent city put down in the same zone brings its own founders, from the first: %s" % [came])
	check(w.bottle_depots.size() == 2, "its own bottle depot too")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and the money still adds up")


func test_a_park_camp_is_not_the_towns_founder() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	w.build_zone = "atom"
	Camp.pitch(w, Vector2(-40, 30), Vector2(0, -1), Camp.KEEPER_WALLET, "scrap_camp", "Camp keeper", true)  # (with its own fire: its keeper lives by it)
	Atom.grow(w, city)
	check(w.machines.filter(func(m): return m.kind == "scrap_camp").size() == 2, "the atom still brings its own camp: the park's keeper is not housed in its tent city")
