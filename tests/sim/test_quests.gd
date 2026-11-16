## Sim tests: the quest system and the letter for the bank.
extends TestCase


## A town with the four stands (the bike shop too), and a banker. The stands start wrecked.
func _town() -> Array:
	var w := World.new()
	var stands: Array = []
	for kind in ["hot_dog_stand", "bakery", "lemonade_stand", "tent"]:
		stands.append(w.add_vendor(kind, Vector2(stands.size() * 5, 0), 0.0, false, false))
	w.add_vendor("bike_shop", Vector2(40, 0), 0.0, true, true)
	var banker := w.add_drifter(Vector2(0, 10), 5.0)
	banker.look = "banker"
	banker.label = "Banker"
	w.add_player(Vector2(0, 20))
	return [w, stands, banker]


func test_the_letter_is_offered_once_the_stands_run_and_the_bankers_are_fed() -> void:
	var t := _town()
	var w: World = t[0]
	var banker: Drone = t[2]
	w.tick(1.0)
	check(not w.quests.state.has(QuestBook.LETTER) and w.quests.objective().is_empty(), "nothing at the start")
	for d in t[1]:
		w.machine_of(d).working = true
	banker.bars.hunger = 0.3
	w.tick(1.0)
	check(not w.quests.state.has(QuestBook.LETTER), "stands running but a hungry banker: not yet")
	banker.bars.hunger = 0.9
	w.tick(1.0)
	check(w.quests.fed_count() == 1, "a meal after being hungry counts him as fed")
	check(w.quests.state.get(QuestBook.LETTER, "") == "offered" and w.quests.giver == banker, "all running and a banker who has had a meal: he has a favour to ask")
	check(w.quests.objective().text.contains("press Q") and w.quests.objective().at == banker.pos, "and the objective sends you to him")
	check(w.events.any(func(e): return e.contains("want a word")), "with a note in the feed")
	check(banker.label == "Banker with a letter", "he is labelled")


func test_a_stand_still_wrecked_holds_the_letter_back() -> void:
	var t := _town()
	var w: World = t[0]
	for d in t[1]:
		w.machine_of(d).working = true
	w.machine_of(t[1][3]).working = false
	w.tick(1.0)
	check(not w.quests.state.has(QuestBook.LETTER), "one wrecked stand is enough to wait")
	var empty := World.new()
	empty.add_vendor("bike_shop", Vector2.ZERO, 0.0, true, true)
	empty.add_player(Vector2.ZERO)
	empty.tick(1.0)
	check(not empty.quests.state.has(QuestBook.LETTER), "and with no bankers at all there is nobody to ask")


func test_accepting_gives_the_letter_and_the_objectives_go_in_order() -> void:
	var t := _town()
	var w: World = t[0]
	for d in t[1]:
		w.machine_of(d).working = true
	(t[2] as Drone).bars.hunger = 0.2
	w.tick(1.0)
	(t[2] as Drone).bars.hunger = 0.9
	w.tick(1.0)
	check(not w.quests.accept("nonsense") and w.quests.active() == "", "only a quest on offer can be accepted")
	check(w.quests.accept(QuestBook.LETTER) and w.quests.active() == QuestBook.LETTER, "accepting makes it the active one")
	check(w.player.carry.count("letter") == 1 and not Catalog.is_consumable("letter"), "you are handed the letter, and it is not something to eat")
	check(not w.quests.accept(QuestBook.LETTER), "and you can't accept it twice")
	w.bus_stop = Vector2(-16, 0)
	check(w.quests.objective().text.contains("bus") and w.quests.objective().at == Vector2(-16, 0), "first, the bus: the beacon is at the stop")
	w.quests.set_flag("rode_bus")
	var sage := w.add_sage(Vector2(500, 0))
	check(w.quests.objective().text.contains("stuck in traffic") and w.quests.objective().at == sage.pos, "then you are stuck in traffic, and someone is watching")
	w.sage.tell(Stories.FIRST)
	check(w.quests.objective().text.contains("farewell") and w.quests.objective().at == sage.pos, "once you have met him, he is the next stop: say farewell when you are ready")
	check(not w.quests.done("jam_cleared"), "the traffic is still stuck")
	w.add_bus(Vector2(300, 0), 0.0)
	check(w.quests.farewell_to_sage() and w.quests.done("jam_cleared") and not w.quests.farewell_to_sage(), "saying farewell clears the jam, once")
	check(w.quests.objective().text.contains("bus is waiting") and w.quests.objective().at == Vector2(300, 0), "and the bus, waiting in the cleared street, is where to go")
	w.quests.set_flag("rode_on")
	check(w.quests.objective().text.contains("European Central Bank") and w.quests.objective().at == null, "then on to the bank (no doorman in this town to point at)")
	var door := w.add_doorman(Vector2(2500, 0))
	check(w.quests.objective().text.contains("security gate") and w.quests.objective().at == door.pos, "the doorman at the gate is who to see first")
	check(w.quests.clear_gate() and not w.quests.clear_gate(), "he lets you through, once")
	w.add_shuttle(Vector2(2510, 20), 0.0)
	check(w.quests.objective().text.contains("shuttle") and w.quests.objective().at == w.shuttle.pos, "then the shuttle inside the gate")
	w.quests.set_flag("rode_shuttle")
	var desk := w.add_receptionist(Vector2(2600, 100))
	check(w.quests.objective().text.contains("receptionist") and w.quests.objective().at == desk.pos, "and the receptionist at the door")


func test_the_letter_is_handed_to_the_receptionist_after_the_gate_and_the_quest_is_done() -> void:
	var t := _town()
	var w: World = t[0]
	for d in t[1]:
		w.machine_of(d).working = true
	(t[2] as Drone).bars.hunger = 0.2
	w.tick(1.0)
	(t[2] as Drone).bars.hunger = 0.9
	w.tick(1.0)
	var door := w.add_doorman(Vector2(2500, 0))
	var desk := w.add_receptionist(Vector2(2600, 100))
	check(not w.quests.can_deliver() and not w.quests.deliver(), "with no letter there is nothing to hand over")
	w.quests.accept(QuestBook.LETTER)
	w.quests.set_flag("rode_bus")
	w.sage.tell(Stories.FIRST)
	w.quests.set_flag("jam_cleared")
	w.quests.set_flag("rode_on")
	check(w.quests.objective().at == door.pos and w.quests.can_clear_gate() and not w.quests.can_deliver(), "the last leg starts at the gate: the doorman first, not the desk")
	check(not w.quests.deliver(), "the letter cannot be handed over before the gate")
	check(w.quests.clear_gate() and w.quests.can_deliver() and w.quests.objective().text.contains("shuttle"), "through the gate, the way on is the shuttle (and the desk will take the letter, shuttle or not)")
	check(w.quests.deliver(), "handing it over works")
	check(w.player.carry.count("letter") == 0 and w.quests.state[QuestBook.LETTER] == "done" and w.quests.active() == "", "the letter leaves the bag and the quest is done")
	check(w.quests.objective().is_empty() and not w.quests.deliver(), "nothing more to do, and it can't be done twice")
	check(door.needless and door.aloof and door.kind == "clerk" and desk.needless and desk.aloof, "the doorman and the receptionist stay at their posts")
