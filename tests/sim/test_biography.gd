## Sim tests: the residents' ID cards and stories (see Biography): the same person always has the same story, different people
## different ones, and a newcomer's card says when they came.
extends TestCase


func test_the_same_person_has_the_same_story() -> void:
	var w := World.new()
	var a := w.add_drifter(Vector2.ZERO, 5.0)
	var b := w.add_drifter(Vector2(3, 0), 5.0)
	check(Biography.of(a, w) == Biography.of(a, w), "asked twice, the same story")
	check(Biography.of(a, w).id != Biography.of(b, w).id, "and someone else has another (%s, %s)" % [Biography.of(a, w).id, Biography.of(b, w).id])
	check(Biography.of(a, w).here != "", "a line about what they do here")


func test_a_stand_keeper_is_told_by_their_stand() -> void:
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2.ZERO, 5.0)
	check(Biography.of(baker, w).here.contains("bread"), "the baker bakes the town's bread")


func test_a_newcomer_has_a_date() -> void:
	var w := World.new(false)
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	w.begin_play()
	check(w.zones.drones_in("atom").all(func(d): return d.arrived_at < 0.0), "the atom's people were there from the start")
	city.residence.tents_cap = city.residence.tents + 1  # (an atom's tent city is full for its tier: room for one more)
	w.lodging.add_tent(city)
	Fixtures.run(w, int(Lodging.ARRIVE_EVERY) + 2)
	var new: Array = w.lodging.housed(city).filter(func(d): return d.arrived_at >= 0.0)
	check(new.size() == 1, "a newcomer's card says when they came (%s)" % [new.map(func(d): return IdCard._when(d.arrived_at))])
