## Sim tests: after the letter is delivered the bank sends the hero up in the lift to the instrument room, where a technician has
## a bench that is not in service yet. The room is a zone of its own, far off the map, that wakes when the hero comes.
extends TestCase


func _world() -> Array:
	var sc := Fixtures.scenario()
	var w := sc.build()
	w.add_player(sc.start)
	return [sc, w]


func _deliver(w: World, sc: Scenario) -> void:
	w.quests.state[QuestBook.LETTER] = "active"
	w.player.carry.add("letter", 1)
	for k in ["rode_tram", "repaired", "rode_on", "cleared_gate", "rode_shuttle"]:
		w.quests.set_flag(k)
	w.quests.deliver()


func test_the_lift_goes_up_to_a_room_of_its_own() -> void:
	var s := _world()
	var sc: Scenario = s[0]
	var w: World = s[1]
	check(w.cast.lift != null and w.cast.technician != null and w.cast.lift.twin != null, "the bank has a lift, and a technician upstairs")
	check(w.cast.lift.kind == "lift" and w.cast.lift.twin.zone == Scenario.LIFT_ZONE and w.cast.technician.zone == Scenario.LIFT_ZONE, "the lift goes to a zone of its own")
	check(w.cast.lift.pos.distance_to(sc.ecb_gate.reception) < 8.0, "it stands by the receptionist's desk")
	check(sc.lift.centre.distance_to(sc.start) > 1000.0, "and the room is far off the map")
	check(not w.is_active(Scenario.LIFT_ZONE), "the room sleeps until the hero comes")


func test_the_receptionist_sends_the_hero_up_after_the_letter() -> void:
	var s := _world()
	var sc: Scenario = s[0]
	var w: World = s[1]
	check(w.quests.state.get(QuestBook.UPGRADE, "") == "", "before the letter there is nothing upstairs for them")
	_deliver(w, sc)
	check(w.quests.state[QuestBook.UPGRADE] == "active" and w.quests.objective().text.contains("lift"), "delivering the letter sends them to the lift")
	w.player.pos = w.cast.lift.pos
	w.portals.cross(w.player, w.cast.lift)
	w.tick(1.0)
	check(w.player.zone == Scenario.LIFT_ZONE and w.is_active(Scenario.LIFT_ZONE) and w.quests.done("rode_lift"), "in the lift they arrive in the room, which wakes")
	check(w.quests.objective().text.contains("technician"), "and now the technician is the one to see")
	var t := w.cast.technician
	check(t.pos.distance_to(w.player.pos) < 30.0, "who is there, in the room")
	w.quests.meet_technician()
	check(w.quests.state[QuestBook.UPGRADE] == "done" and w.quests.objective().is_empty(), "talking with him is the end of it, for now")
	var back := w.cast.lift.twin
	w.player.pos = back.pos
	w.portals.cross(w.player, back)
	w.tick(1.0)
	check(w.player.zone == Scenario.ECB_ZONE, "and the lift brings them down again to the plaza")


func test_nobody_asks_for_the_gun_upstairs() -> void:
	var lines: Array = QuestBook.quest(QuestBook.UPGRADE).technician + QuestBook.quest(QuestBook.LETTER).delivery
	var said := " ".join(lines).to_lower()
	check(not said.contains("curse") and not said.contains("hand it over to us") and not said.contains("confiscate"), "the bank never names the curse, and never takes the gun")
