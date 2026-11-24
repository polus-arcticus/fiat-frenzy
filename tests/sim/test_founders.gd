## Sim tests: the first arrivals to a tent city are makers (Lodging.FOUNDERS): the tailor's thrift stall, then a camp that puts boards
## together, each in the tent that was waiting; after them the dice (drifters and runners). Without this a grown atom is only mouths.
extends TestCase


func _atom() -> Array:
	var w := World.new(false)
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	return [w, city]


## Frees a tent and waits for whoever comes for it. Returns who came (the new drone).
func _arrival(w: World, city: Machine) -> Drone:
	var before := w.drones.size()
	w.lodging.set_tents(city, city.residence.tents + 1)
	Fixtures.run(w, int(Lodging.ARRIVE_EVERY) + 1, true)
	return w.drones[before] if w.drones.size() > before else null


func test_the_first_two_arrivals_found_a_thrift_stall_and_a_camp() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	var first := _arrival(w, city)
	check(first != null and first.kind == "vendor" and w.machine_of(first).kind == "thrift_stall", "the first arrival keeps a thrift stall (the tailor)")
	check(first != null and first.bed == city.uid, "and lives in the tent that was waiting")
	var second := _arrival(w, city)
	check(second != null and second.kind == "vendor" and w.machine_of(second).kind == "scrap_camp", "the second keeps a camp")
	check(city.residence.founded == 2, "the city has brought both founders")
	var stalls: Array = w.machines.filter(func(m): return m.kind in ["thrift_stall", "scrap_camp"])
	check(stalls.size() == 2 and stalls[0].pos.distance_to(stalls[1].pos) > Lodging.STALL_ROOM, "two stalls, clear of each other")


func test_after_the_founders_it_is_drifters_and_runners() -> void:
	var s := _atom()
	var w: World = s[0]
	var city: Machine = s[1]
	_arrival(w, city)
	_arrival(w, city)
	var stalls := w.machines.size()
	for i in 4:
		var d := _arrival(w, city)
		check(d != null and d.kind in ["drifter", "runner"], "later arrivals are %s" % (d.kind if d != null else "nobody"))
	check(w.machines.size() == stalls, "no more stalls")


func test_a_tent_city_put_down_in_the_street_does_the_same() -> void:
	var w := World.new(false)
	var city := w.lodging.found(Vector2.ZERO, Vector2(0, 1), "atom")
	var d := _arrival(w, city)
	check(d != null and w.machine_of(d).kind == "thrift_stall", "the first arrival to a tent of the hero's keeps a thrift stall")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and the money still adds up")
