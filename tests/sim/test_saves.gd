## Sim tests: saving and loading. A saved world, laid over a fresh build of the same scenario, is the same world.
extends TestCase

const DIR := "user://test_saves"


func _scenario() -> Scenario:
	return Fixtures.scenario()


func _started() -> World:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.start, 25.0)
	for i in 600:
		w.tick(0.1)
	var d := w.add_drifter(sc.start + Vector2(2, 2), 12.0)  # one who turns up later, as the bankers do
	d.label = "Latecomer"
	w.bills.append(Bill.new(5.0, "cash"))
	w.quests.flags["met"] = true
	w.quests.fed["someone"] = true
	w.quests.flags["count"] = 3
	w.ledger.player_cash += 17.5
	for i in 300:
		w.tick(0.1)
	d.job = {"for": "hunger", "target": w.machines[0], "item": "bread"}
	w.bills[-1].pos = Vector2(3, 4)
	w.bills[-1].loose = true
	return w


func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func test_a_snapshot_survives_json_and_comes_back_the_same() -> void:
	var w := _started()
	var data := _through_json(Snapshot.new(w).capture())
	var fresh := _scenario().build()
	fresh.add_player(Vector2.ZERO, 0.0)
	var made := Snapshot.new(fresh).apply(data)
	check(made.size() == 1 and made[0].label == "Latecomer", "it says which drones it had to make: the latecomer (%d)" % made.size())
	check(fresh.drones.size() == w.drones.size(), "the latecomer is back (%d drones)" % fresh.drones.size())
	check(fresh.drones[-1].label == "Latecomer" and is_equal_approx(fresh.drones[-1].wallet, w.drones[-1].wallet), "with their name and wallet ($%.2f: they may have handed some bottles in meanwhile)" % fresh.drones[-1].wallet)
	check(fresh.bills.size() == w.bills.size() and fresh.bills[-1].loose and fresh.bills[-1].pos == Vector2(3, 4), "the loose bill lies where it did")
	check(is_equal_approx(fresh.clock.time, w.clock.time), "the clock reads the same")
	check(is_equal_approx(fresh.ledger.player_cash, w.ledger.player_cash), "so does the player's cash")
	check(fresh.player.pos.is_equal_approx(w.player.pos) and is_equal_approx(fresh.player.bars.hunger, w.player.bars.hunger), "the hero stands where they stood, as hungry")
	check(fresh.quests.flags.get("met") == true and fresh.quests.fed.has("someone") and typeof(fresh.quests.flags.count) == TYPE_INT, "quest flags come back (3 stays an int)")
	check(fresh.machines[0].working == w.machines[0].working and fresh.machines[0].output.count("bread") == w.machines[0].output.count("bread"), "a stand's shelves are as they were")
	var job: Dictionary = fresh.drones[-1].job
	check(job.get("target") == fresh.machines[0], "a job still points at the stand itself, not a copy")
	check(fresh.drones[0].route_goal == w.drones[0].route_goal, "infinite 'no goal' markers survive")
	var uids := func(world: World): return world.drones.map(func(x): return x.uid)
	check(uids.call(fresh) == uids.call(w), "everyone has the same name, in the same order")
	check(fresh.machine_of(fresh.drones[0]) == fresh.machines[0] and fresh.drone(fresh.machines[0].owner) == fresh.drones[0], "a vendor and their stand still know each other by uid")


func test_someone_in_a_tent_bed_is_still_in_it_after_loading() -> void:
	var make := func() -> World:
		var w := World.new()
		w.add_vendor("tent", Vector2(0, 0), 5.0, true, true)
		w.add_drifter(Vector2(3, 0), 5.0)
		return w
	var w: World = make.call()
	var tent: Machine = w.machines[0]
	tent.shelter.admit(w.drones[1])
	var fresh: World = make.call()
	Snapshot.new(fresh).apply(_through_json(Snapshot.new(w).capture()))
	var s: Shelter = fresh.machines[0].shelter
	check(s.berths.size() == 1 and s.berths[0] == fresh.drones[1] and fresh.drones[1].sheltered_in == s, "the bed and the sleeper still know each other")


func test_a_bill_that_was_picked_up_is_gone_after_loading() -> void:
	var sc := _scenario()
	var w := sc.build()
	w.add_player(sc.start, 25.0)
	var fresh := _scenario().build()
	fresh.add_player(Vector2.ZERO, 0.0)
	fresh.bills.append(Bill.new(3.0, "cash"))  # one the fresh world has and the save does not
	Snapshot.new(fresh).apply(_through_json(Snapshot.new(w).capture()))
	check(fresh.bills.is_empty(), "what the save does not have, the loaded world does not have")


func test_a_loaded_world_goes_on_exactly_like_the_one_that_was_saved() -> void:
	var w := _started()
	var data := _through_json(Snapshot.new(w).capture())
	var fresh := _scenario().build()
	fresh.add_player(Vector2.ZERO, 0.0)
	Snapshot.new(fresh).apply(data)
	seed(99)
	for i in 200:
		w.tick(0.1)
	seed(99)
	for i in 200:
		fresh.tick(0.1)
	check(is_equal_approx(w.total_money(), fresh.total_money()), "after 20 more seconds the money in the world agrees (%.2f)" % fresh.total_money())
	check(w.drones[2].pos.distance_to(fresh.drones[2].pos) < 0.01, "and a walker is in the same place")


func test_a_save_file_is_written_whole_and_read_back() -> void:
	var w := _started()
	check(SaveStore.write("slot_a", w, {"yaw": 1.5}, DIR), "a save is written")
	var doc := SaveStore.read("slot_a", DIR)
	check(not doc.is_empty() and doc.hero.yaw == 1.5 and doc.summary.day == 1, "it reads back with its hero and its summary")
	SaveStore.write("slot_a", w, {"yaw": 2.5}, DIR)
	check(FileAccess.file_exists(SaveStore.path("slot_a", DIR) + ".bak"), "saving over it keeps the old one as a backup")
	var broken := FileAccess.open(SaveStore.path("slot_a", DIR), FileAccess.WRITE)
	broken.store_string("{ not json")
	broken.close()
	check(SaveStore.read("slot_a", DIR).hero.yaw == 1.5, "a damaged save falls back to the backup")
	check(SaveStore.list(DIR).size() == 1, "the list shows the slot once")
	SaveStore.delete("slot_a", DIR)
	check(SaveStore.list(DIR).is_empty(), "and deleting it empties the list")
