## Sim tests: saving and loading. A saved world, laid over a fresh build of the same scenario, is the same world.
extends TestCase

const DIR := "user://test_saves"


func _scenario() -> Scenario:
	return Scenario.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/bahnhofsviertel.json")))


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
	w.quests.fed[3] = true
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
	check(made == _scenario().build().drones.size(), "it says how many drones the scenario made itself (%d)" % made)
	check(fresh.drones.size() == w.drones.size(), "the latecomer is back (%d drones)" % fresh.drones.size())
	check(fresh.drones[-1].label == "Latecomer" and fresh.drones[-1].wallet == 12.0, "with their name and wallet")
	check(fresh.bills.size() == w.bills.size() and fresh.bills[-1].loose and fresh.bills[-1].pos == Vector2(3, 4), "the loose bill lies where it did")
	check(is_equal_approx(fresh.clock.time, w.clock.time), "the clock reads the same")
	check(is_equal_approx(fresh.ledger.player_cash, w.ledger.player_cash), "so does the player's cash")
	check(fresh.player.pos.is_equal_approx(w.player.pos) and is_equal_approx(fresh.player.bars.hunger, w.player.bars.hunger), "the hero stands where they stood, as hungry")
	check(fresh.quests.flags.get("met") == true and fresh.quests.fed.has(3), "quest flags and int keys come back (3 stays an int)")
	check(fresh.machines[0].working == w.machines[0].working and fresh.machines[0].output.count("bread") == w.machines[0].output.count("bread"), "a stand's shelves are as they were")
	var job: Dictionary = fresh.drones[-1].job
	check(job.get("target") == fresh.machines[0], "a job still points at the stand itself, not a copy")
	check(fresh.drones[0].route_goal == w.drones[0].route_goal, "infinite 'no goal' markers survive")


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
