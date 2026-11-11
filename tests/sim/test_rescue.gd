## Sim tests: rescue. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_running_out_of_a_bar_means_collapsing() -> void:
	note("collapse: an empty survival bar puts you down")
	var w := Fixtures.clinic()
	var d := w.add_drifter(Vector2(0, 0), 5.0)
	d.label = "Edda"
	d.bars = {"hunger": 0.002, "thirst": 1.0, "warmth": 1.0}
	check(d.care == "", "fit and well to begin with")
	Fixtures.run(w, 2)
	check(d.care != "", "once hunger ran out, Edda collapsed")
	d.care = "down"
	d.pos = Vector2(0, 0)
	var before := d.pos
	w.tick(1.0)
	check(d.job.is_empty() and d.pos == before, "someone lying in the street makes no plans and goes nowhere")
	var b := d.bars.duplicate()
	d.care = "down"
	w.hospitals.clear()  # no way to be rescued
	w.ambulances.clear()
	Fixtures.run(w, 5)
	check(d.bars == b, "and nothing drains from the bars of someone who is out cold")
	check(w.events.any(func(e): return "Edda collapsed" in e), "the town is told")


func test_the_ambulance_takes_the_collapsed_to_the_medical_tent() -> void:
	note("the ambulance fetches the collapsed and the tent gets them up again")
	var w := Fixtures.clinic()
	var h := w.hospitals[0]
	var amb := w.ambulances[0]
	check(amb.pos.distance_to(h.bay()) < 0.1 and amb.job == Ambulance.Job.IDLE, "the ambulance waits in the bay outside the tent")
	var near := w.add_drifter(Vector2(10, 0), 7.0)
	var far := w.add_drifter(Vector2(-60, 0), 3.0)
	near.label = "Near"
	far.label = "Far"
	near.bars = {"hunger": 0.0, "thirst": 1.0, "warmth": 1.0}
	far.bars = {"hunger": 0.0, "thirst": 1.0, "warmth": 1.0}
	var money := w.ledger.printed
	w.tick(1.0)
	check(near.care == "down" and far.care == "down", "both collapse where they stood")
	Fixtures.run(w, 3)
	check(amb.patient == near, "the ambulance goes for the nearer one first")
	var carried := false
	var arrived_in := -1
	var woke_with := -1.0
	for t in 200:
		w.tick(1.0)
		carried = carried or near.care == "carried"
		if near.care == "patient" and arrived_in < 0:
			arrived_in = t
		if arrived_in >= 0 and near.care == "" and woke_with < 0.0:
			woke_with = near.bars.hunger
	check(carried, "the patient is carried in the ambulance")
	check(arrived_in > 0 and arrived_in < 60, "and is in a bed in a reasonable time (%d s)" % arrived_in)
	check(woke_with >= Hospital.WAKE_AT - 0.01, "Near wakes up with their hunger restored (%.2f)" % woke_with)
	check(near.care == "", "and is on their feet")
	Fixtures.run(w, 100)
	check(far.care == "" and amb.rescues == 2, "the ambulance went back for the one further off: %d rescues" % amb.rescues)
	check(near.wallet == 7.0 and far.wallet == 3.0 and is_equal_approx(w.total_money(), money), "care is free, and money is conserved")


func test_the_player_wakes_in_the_medical_tent() -> void:
	note("the hero passes out and wakes up in the medical tent")
	var w := Fixtures.clinic()
	var h := w.hospitals[0]
	w.add_player(Vector2(30, 0), 25.0)
	w.player.bars = {"hunger": 0.001, "thirst": 1.0, "warmth": 1.0}
	Fixtures.run(w, 2)
	check(w.player.care == "down", "the player collapses when a bar runs out")
	var woke := false
	var was_in_bed := false
	for t in 400:
		w.tick(1.0)
		was_in_bed = was_in_bed or w.player.care == "patient"
		if w.player.care == "" and was_in_bed:
			woke = true
			break
	check(was_in_bed, "the ambulance took them to a bed")
	check(woke and w.player.pos.distance_to(h.pos) < 6.0, "they wake up by the medical tent (%.1f m from it)" % w.player.pos.distance_to(h.pos))
	check(w.player.neediest() >= Hospital.WAKE_AT - 0.01 and w.ledger.player_cash == 0.0, "fit again, and their cash is gone (mugged)")


func test_a_full_tent_keeps_the_ambulance_waiting() -> void:
	note("beds: the ambulance only goes out when there is a bed")
	var w := Fixtures.clinic()
	var h := w.hospitals[0]
	for i in Hospital.BEDS:
		var p := w.add_drifter(Vector2(0, 20), 1.0)
		p.bars = {"hunger": 0.1, "thirst": 0.1, "warmth": 0.1}
		h.admit(p)
	var extra := w.add_drifter(Vector2(5, 0), 1.0)
	extra.bars = {"hunger": 0.0, "thirst": 1.0, "warmth": 1.0}
	Fixtures.run(w, 3)
	check(h.free_beds() == 0 and w.ambulances[0].job == Ambulance.Job.IDLE and extra.care == "down", "every bed taken: the ambulance stays put and the new case waits")
	Fixtures.run(w, 200)
	check(w.ambulances[0].rescues >= 1 and extra.care != "down", "once a bed is free it goes, and they are looked after")


func test_the_hero_wakes_properly_well_and_mugged() -> void:
	note("the hero comes round in the tent with full bars and no cash")
	var w := Fixtures.clinic()
	var thief := w.add_drifter(Vector2(5, 5), 1.0)
	thief.label = "Edda"
	var hero := w.add_player(Vector2(10, 0), 40.0)
	var printed := w.ledger.printed
	hero.bars.hunger = 0.0
	w.tick(1.0)
	check(hero.care == "down", "the hero collapses")
	var asleep := 0
	for t in 300:
		w.tick(1.0)
		if hero.care == "patient":
			asleep += 1
		if hero.care == "" and t > 5:
			break
	check(hero.care == "" and asleep > 0 and asleep < 40, "and is back on their feet after a short sleep (%d s)" % asleep)
	check(hero.neediest() >= 0.9, "with the survival bars right up (%.2f)" % hero.neediest())
	check(w.ledger.player_cash == 0.0 and w.rescue.last_mugged > 30.0, "but their pockets are empty: someone took $%.0f" % w.rescue.last_mugged)
	check(thief.wallet > 30.0 and absf(w.ledger.total(w.drones, w.bills) - w.ledger.printed) < 0.01 and w.ledger.printed == printed, "the money went into a drifter's pocket, and the books still balance")
	check(w.events.any(func(e): return "mugged" in e), "the town is told")


func test_a_collapse_far_from_the_tent_is_not_a_long_wait_in_the_dark() -> void:
	note("the ambulance hurries when it has a long way to go")
	var w := Fixtures.clinic()
	var hero := w.add_player(Vector2(1400, -400), 10.0)
	hero.bars.hunger = 0.0
	w.tick(1.0)
	var in_bed_at := -1
	var up_at := -1
	for t in 400:
		w.tick(1.0)
		if hero.care == "patient" and in_bed_at < 0:
			in_bed_at = t
		if hero.care == "" and in_bed_at >= 0:
			up_at = t
			break
	check(in_bed_at > 0 and in_bed_at < 110, "1.4 km out, they are in a bed within two minutes (%d s)" % in_bed_at)
	check(up_at > 0 and up_at < 140, "and up again soon after (%d s in all)" % up_at)
