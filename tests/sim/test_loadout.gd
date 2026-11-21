## Sim tests: the hero's loadout (see Loadout). Generic slots beside the bag for whatever is ridden or worn; a bike or board in it
## goes wherever the hero goes.
extends TestCase


func _hero() -> World:
	var w := World.new()
	w.add_player(Vector2(10, 10), 0.0)
	w.player.carry.counts.clear()
	return w


func test_gear_goes_on_and_comes_off() -> void:
	var w := _hero()
	w.player.carry.add("old_skateboard", 1)
	w.player.carry.add("bread", 2)
	check(not w.loadout.equip("bread").ok and w.player.carry.count("bread") == 2, "bread is not gear: it stays in the bag")
	check(not w.loadout.equip("bicycle").ok, "nor can you equip what you don't have")
	var r := w.loadout.equip("old_skateboard")
	check(r.ok and w.player.gear.count("old_skateboard") == 1 and w.player.carry.count("old_skateboard") == 0, "a board goes from the bag into a slot: %s" % r.text)
	check(w.loadout.used() == 1 and Array(w.loadout.items()) == ["old_skateboard"], "one slot taken")
	r = w.loadout.unequip("old_skateboard")
	check(r.ok and w.player.carry.count("old_skateboard") == 1 and w.loadout.used() == 0, "and comes off into the bag again")
	check(not w.loadout.unequip("old_skateboard").ok, "you can't take off what you don't have on")


func test_the_slots_are_generic_and_few() -> void:
	var w := _hero()
	for g in ["bicycle", "old_bike", "skateboard", "old_skateboard"]:
		w.player.carry.add(g, 1)
		check(w.loadout.equip(g).ok, "%s goes in any free slot" % g)
	check(w.loadout.used() == Loadout.SLOTS and not w.loadout.has_room(), "%d slots, and they are full" % Loadout.SLOTS)
	w.player.carry.add("skateboard", 1)
	check(not w.loadout.equip("skateboard").ok and w.player.carry.count("skateboard") == 1, "a fifth won't go on")
	check(w.loadout.ride("vehicle") == "bicycle" and w.loadout.ride("board") == "skateboard", "of two bikes and two boards, the best of each is ridden")


func test_bought_gear_goes_into_the_loadout_while_there_is_room() -> void:
	var w := _hero()
	check(w.loadout.receive("skateboard") == "gear" and w.player.gear.count("skateboard") == 1, "a new board goes straight on")
	check(w.loadout.receive("bread") == "bag", "bread to the bag")
	for i in Loadout.SLOTS - 1:
		w.loadout.receive("old_skateboard")
	check(w.loadout.receive("old_bike") == "bag" and w.player.carry.count("old_bike") == 1, "with the loadout full, the bag")


func test_a_bike_in_the_loadout_is_ridden_from_anywhere() -> void:
	var w := _hero()
	check(not w.riding.mount().ok, "no bike, no riding")
	w.player.carry.add("old_bike", 1)
	check(not w.riding.mount().ok, "a bike in the bag isn't one you can ride")
	w.loadout.equip("old_bike")
	w.player.pos = Vector2(-300, 250)
	var r := w.riding.mount()
	check(r.ok and w.riding.riding(), "equipped, you get on where you stand: %s" % r.text)
	var slow := w.riding.speed_factor()
	check(slow > 1.0 and slow < Riding.RIDE_FACTOR, "an old bike: x%.2f" % slow)
	check(not w.loadout.unequip("old_bike").ok and w.player.gear.count("old_bike") == 1, "you can't take off the bike you're on")
	w.riding.dismount()
	check(w.loadout.unequip("old_bike").ok, "off it, you can")


func test_the_loadout_is_saved() -> void:
	var w := _hero()
	w.loadout.receive("old_bike")
	var data = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))  # (through JSON, as a save file is)
	var w2 := _hero()
	Snapshot.new(w2).apply(data)
	check(w2.player.gear.count("old_bike") == 1 and w2.riding.bike() == "old_bike", "a save keeps what the hero has on")
