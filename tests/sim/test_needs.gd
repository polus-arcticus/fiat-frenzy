## Sim tests: needs. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_maslow_demands() -> void:
	note("a drone's demands change with Maslow's order")
	var w := World.new()
	var d := w.add_drifter(Vector2.ZERO, 20.0)
	d.bars = Fixtures.bars(0.4, 0.1, 1.0)
	check(w.needs.demands(d) == ["drink", "food"], "hungry and thirsty: both, the thirstier first")
	d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	check(w.needs.demands(d).is_empty(), "topped up: nothing")
	d.bars = Fixtures.bars(1.0, 1.0, 0.4)
	check(w.needs.demands(d) == ["warmth"], "cold: warmth")
	d.bars = Fixtures.bars(1.0, 1.0, 0.7)
	check(w.needs.demands(d).is_empty(), "a bit cool in the day: fine")
	w.clock.time = 0.7 * Clock.DAY_SECONDS
	check(w.needs.demands(d) == ["warmth"], "the same drone at night: warmth")
	d.bars = Fixtures.bars(0.3, 1.0, 0.7)
	check(w.needs.demands(d) == ["food", "warmth"], "and food comes first because it is lower")
	w.clock.time = 0.0
	d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	d.wallet = 500.0
	check(w.needs.demands(d).is_empty(), "covered: nothing, however much money it has")
	var v := w.add_vendor("hot_dog_stand", Vector2(5, 0), 30.0, false)
	v.bars = Fixtures.bars(1.0, 1.0, 1.0)
	check(w.needs.demands(v).is_empty(), "a vendor with a broken stand and too little to fix it: nothing")
	v.wallet = 60.0
	check(w.needs.demands(v) == ["repair"], "enough: repair, which is its vocation")
	v.bars = Fixtures.bars(0.2, 1.0, 1.0)
	check(w.needs.demands(v) == ["food", "repair"], "but food comes before the repair")
	check(w.logistics.plan(v).is_empty() == false and w.logistics.plan(v)["for"] == "repair", "and with no food for sale anywhere it gets on with the repair instead of waiting")
	var stand := w.machine_of(v)
	stand.working = true
	v.bars = Fixtures.bars(1.0, 1.0, 1.0)
	check(w.needs.demands(v) == ["restock"], "once it works, a stand with two buns in hand wants more bread (protein is delivered, not fetched)")
	stand.input.add("bread", 1)
	check(w.needs.demands(v).is_empty(), "with three in hand it runs")
	stand.input.take("bread", 3)
	v.bars = Fixtures.bars(1.0, 0.3, 1.0)
	check(w.needs.demands(v) == ["drink", "restock"], "and a thirsty vendor drinks before restocking")


func test_most_pressing_need_goes_first() -> void:
	note("the drone targets the supply for its most pressing need")
	var w := World.new()
	w.add_vendor("bakery", Vector2(10, 0))
	w.add_vendor("lemonade_stand", Vector2(-10, 0))
	var d := w.add_drifter(Vector2(0, 0), 20.0)
	d.bars = Fixtures.bars(0.4, 0.1, 1.0)
	var job := w.logistics.plan(d)
	check(job["for"] == "drink" and job.target.kind == "lemonade_stand", "thirstier than hungry: lemonade first")
	d.bars = Fixtures.bars(0.1, 0.4, 1.0)
	job = w.logistics.plan(d)
	check(job["for"] == "food" and job.target.kind == "bakery", "hungrier than thirsty: the bakery")


# ---------------------------------------------------------------- night and shelter


func test_night_is_colder_and_tent_docks_drones() -> void:
	note("night: far colder than day, so drones buy a bed and dock in the tent until they're warm")
	var w := World.new()
	var day_d := w.add_drifter(Vector2(500, 0))
	var night_d := w.add_drifter(Vector2(600, 0))
	day_d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	Fixtures.run(w, 100)
	var day_loss: float = 1.0 - day_d.bars.warmth
	w.clock.time = 0.7 * Clock.DAY_SECONDS
	night_d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	Fixtures.run(w, 100)
	var night_loss: float = 1.0 - night_d.bars.warmth
	note("    warmth lost in 100 s: day %.3f, night %.3f" % [day_loss, night_loss])
	check(is_equal_approx(night_loss / day_loss, Needs.DAY_COOLING / Needs.NIGHT_COOLING), "it drains %.1f times as fast after dark" % (Needs.DAY_COOLING / Needs.NIGHT_COOLING))
	var w2 := World.new()
	var tent := w2.machine_of(w2.add_vendor("tent", Vector2(0, 0)))
	var sleeper := w2.add_drifter(Vector2(12, 0), 20.0)
	sleeper.bars = Fixtures.bars(1.0, 1.0, 0.6)
	w2.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS - 3.0
	check(w2.needs.demands(sleeper).is_empty(), "just before dusk it wants nothing")
	var t := Fixtures.until(w2, func(): return sleeper.sheltered_in != null, 100)
	check(t >= 0 and sleeper in tent.shelter.berths and sleeper.pos.distance_to(tent.pos) < 1.2, "after dusk it walked to the tent and took a seat beside it")
	check(tent.stock() == 1 and is_equal_approx(sleeper.wallet, 20.0 - tent.price), "it paid for the bed and used up one of the two")
	var warmth_in: float = sleeper.bars.warmth
	t = Fixtures.until(w2, func(): return sleeper.sheltered_in == null, 400)
	note("    left the tent at t=%.0f (night ends at %.0f), warmth %.2f -> %.2f" % [w2.clock.time, Clock.DAY_SECONDS, warmth_in, sleeper.bars.warmth])
	check(t >= 0 and sleeper.bars.warmth >= 0.97 and tent.shelter.berths.is_empty(), "it left once the barrel fire had warmed it through")


func test_barrel_fire_is_free_warmth() -> void:
	note("barrel fires: free warmth without a tent, with room for a ring of eight")
	var w := World.new()
	var fire := w.add_fire(Vector2(0, 0))
	check(fire.shelter.capacity == 8, "a fire has room for eight round it")
	for i in 10:
		var d := w.add_drifter(Vector2(randf_range(-8, 8), randf_range(-8, 8)), 20.0)
		d.bars = Fixtures.bars(1.0, 1.0, 0.3)
	w.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0
	Fixtures.run(w, 30)
	check(fire.shelter.berths.size() == 8, "eight stand at the fire")
	var out := w.drones.filter(func(d): return d.sheltered_in == null)
	check(out.size() == 2, "the other two are left out in the cold")
	check(fire.shelter.berths.all(func(d): return d.wallet == 20.0), "it cost nothing")
	var d0: Drone = fire.shelter.berths[0]
	var w0: float = d0.bars.warmth
	Fixtures.run(w, 20)
	check(d0.bars.warmth > w0, "and they warm up (%.2f -> %.2f)" % [w0, d0.bars.warmth])
	var w2 := World.new()
	w2.add_fire(Vector2(0, 0))
	var tent := w2.machine_of(w2.add_vendor("tent", Vector2(20, 0)))
	for i in 10:
		var d := w2.add_drifter(Vector2(randf_range(-8, 8), randf_range(-8, 8)), 20.0)
		d.bars = Fixtures.bars(1.0, 1.0, 0.3)
	w2.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0
	Fixtures.run(w2, 30)
	check(w2.fires[0].shelter.berths.size() == 8 and tent.shelter.berths.size() == 2, "with a tent too, the overflow buy its two beds: everyone is under cover")


func test_warmth_falls_off_with_the_square_of_distance() -> void:
	note("warmth: strongest beside a source, falling off by an inverse-square law")
	var sh := Shelter.new(8, 0.02, Vector2.ZERO, true)
	var g0 := sh.gain_at_sq(0.0)
	var g_half := sh.gain_at_sq(Shelter.R0_SQ)
	check(is_equal_approx(g0, 0.02) and is_equal_approx(g_half, 0.01), "full strength at the centre, half at 1.5 m")
	var g3 := sh.gain_at_sq(9.0)
	var g6 := sh.gain_at_sq(36.0)
	var g12 := sh.gain_at_sq(144.0)
	note("    gain at 0 / 1.5 / 3 / 6 / 12 m: %.4f %.4f %.4f %.4f %.4f" % [g0, g_half, g3, g6, g12])
	check(g0 > g_half and g_half > g3 and g3 > g6 and g6 > g12, "and it keeps falling with distance")
	check(g3 / g6 > 3.0 and g3 / g6 < 4.2, "doubling the distance cuts it to about a quarter (%.1fx)" % (g3 / g6))
	var w := World.new()
	w.add_fire(Vector2(0, 0))
	w.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0
	var near := w.add_drifter(Vector2(1, 0))
	var mid := w.add_drifter(Vector2(4, 0))
	var far := w.add_drifter(Vector2(11, 0))
	check(w.needs.warmth_gain(near) > 3.0 * w.needs.warmth_gain(mid) and w.needs.warmth_gain(mid) > 0.0 and w.needs.warmth_gain(far) == 0.0, "someone at 1 m feels over three times what someone at 4 m does, and nothing at 11 m")
	var cold := World.new()
	cold.add_fire(Vector2(0, 0))
	cold.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0
	var close := cold.add_drifter(Vector2(1.0, 0))
	var distant := cold.add_drifter(Vector2(7.0, 0))
	close.bars = Fixtures.bars(1.0, 1.0, 0.3)
	distant.bars = Fixtures.bars(1.0, 1.0, 0.3)
	var t := -1
	for i in 120:
		for d in cold.drones:
			d.bars.hunger = 1.0
			d.bars.thirst = 1.0
		cold.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0 + i  # hold it night; they hold still (no stands, no cash)
		cold.drones[0].job = {}
		cold.drones[1].job = {}
		cold.drones[0].pos = Vector2(1.0, 0)
		cold.drones[1].pos = Vector2(7.0, 0)
		cold.needs.decay(close, 1.0)
		cold.needs.decay(distant, 1.0)
		if t < 0 and close.bars.warmth >= 0.9:
			t = i
	note("    from 30%% warmth at night: 1 m from the fire reaches 90%% after %d s; 7 m away it is at %.0f%%" % [t, distant.bars.warmth * 100.0])
	check(t >= 0 and t < 90, "beside the fire a cold person warms through in under 90 s (it took the old fire about 340)")
	check(distant.bars.warmth < 0.3, "seven metres off they just keep getting colder")
