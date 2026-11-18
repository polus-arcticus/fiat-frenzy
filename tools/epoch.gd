## The epoch sim: the standard cluster (see Cluster), found and funded once by the hero, run on its own for a long time, very
## fast, to watch it grow into its final form: every trade built up as far as its tiers go (Trades). By default it runs in
## summary (TileSummary: the same rules, without the walking, in steps of Zones.COARSE_STEP), which is a game year in about
## 12 s (61 hours of play).
##   godot --headless --path . --script tools/epoch.gd -- [days=365] [every=10] [dt=1] [full] [csv=<path>]
##   days   how long to run (a game day is 600 s)
##   every  print a row every this many days (and a line whenever someone builds up)
##   dt     seconds a tick. 1 is faithful; 10 is about twice as fast and close (the same collapses, builds a few days apart);
##          30 is cruder still
##   full   run the cluster in full detail instead (walking, queues: about 150 game days in 10 minutes)
##   csv    also write one row a day to this file (for charts)
##   noup   nobody builds up (the tier 0 cluster on its own, for comparison)
##   nofund the hero never funds it: a block as it is found, left alone (the welfare office's gifts are all it gets)
##   beds   the hero adds this many beds to the tent on day one, and newcomers come for them (see Lodging)
## Each row: what each trade is now, sales that day, collapses since the last row, each owner's money, the residents' money,
## and the books: money issued by the welfare office, and money sunk into building up.
extends SceneTree

const ZONE := "cluster"


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	var days := _arg("days", "365").to_int()
	var every := _arg("every", "10").to_int()
	var dt := _arg("dt", "1").to_float()
	var full := "full" in OS.get_cmdline_user_args()
	if full:
		dt = 1.0
	var csv_path := _arg("csv", "")
	var w := World.new(false)  # (the engine alone: no hero, no story)
	Cluster.found(w, ZONE, Vector2.ZERO)
	w.begin_play()
	if not "nofund" in OS.get_cmdline_user_args():
		Cluster.fund(w, ZONE)
	var tent: Machine = w.zones.machines_in(ZONE).filter(func(m): return m.shelter != null)[0]
	for i in _arg("beds", "0").to_int():
		w.lodging.add_bed(tent)  # (the hero adds beds on day one: newcomers come for them)
	if "noup" in OS.get_cmdline_user_args():
		w._end_of_tick.erase(w.trades)  # (nobody builds up: the tier 0 cluster on its own, for comparison)
	if not full:
		w.build_zone = "elsewhere"  # the fence is somewhere else: the cluster is dormant, and runs in summary
		w.add_drifter(Vector2(9000, 0)).make_needless()
		w.zones.active = ["elsewhere"] as Array[String]
	var trades: Array = Catalog.TRADES.keys().filter(func(t): return _premises(w, t) != null)
	print("EPOCH: the standard cluster, %d days, %s (a %.0f s tick). The fountain gives $%.0f a resident a day." % [days, "in full detail" if full else "in summary", dt, Welfare.DOLLARS_A_DAY])
	var head := "day  " + "  ".join(trades.map(func(t): return "%-15s" % t)) + "  sales/d  down   " + "  ".join(trades.map(func(t): return "%7s$" % t.left(7))) + "  residents$   issued    built"
	print(head)
	var csv := FileAccess.open(csv_path, FileAccess.WRITE) if csv_path != "" else null
	if csv != null:
		csv.store_line(",".join(["day", "sales", "down", "residents", "issued", "built"] + trades.map(func(t): return t + "_tier") + trades.map(func(t): return t + "_owner") + trades.map(func(t): return t + "_price") + trades.map(func(t): return t + "_made") + ["bank_flour", "bread_flour", "runners"]))
	var steps_a_day := int(round(Clock.DAY_SECONDS / dt))
	var seen_events := 0
	var down := 0
	var down_row := 0
	var final_day := -1
	var started := Time.get_ticks_msec()
	for day in days:
		var sold_before := Fixtures.sold(w, ZONE)
		var made_before := {}
		for t in trades:
			if _premises(w, t) is Machine:
				made_before[t] = _premises(w, t).crafted_total
		for s in steps_a_day:
			w.tick(dt)
		for i in range(seen_events, w.events.size()):
			var e: String = w.events[i]
			if "collapsed" in e or "goes down" in e:
				down += 1
				down_row += 1
			if "built up" in e:
				print("     day %d: %s" % [day + 1, e.substr(e.find(" ") + 1)])
		seen_events = w.events.size()
		var sales := Fixtures.sold(w, ZONE) - sold_before
		var residents := 0.0
		for d in w.zones.drones_in(ZONE):
			if d.kind in ["drifter", "runner"]:
				residents += d.wallet
		if final_day < 0 and w.zones.machines_in(ZONE).all(func(m): return Catalog.next_tier(m.kind) == ""):
			final_day = day + 1
			print("     day %d: FINAL FORM: every trade is as far up as its tiers go" % final_day)
		if csv != null:
			csv.store_line(",".join([day + 1, sales, down, "%.2f" % residents, "%.2f" % w.ledger.issued, "%.2f" % _built(w)]
				+ trades.map(func(t): return str(_premises(w, t).tier)) + trades.map(func(t): return "%.2f" % _owner_money(w, t))
				+ trades.map(func(t): return "%.2f" % (_premises(w, t).price if _premises(w, t) is Machine else 0.0))
				+ trades.map(func(t): return str(_premises(w, t).crafted_total - int(made_before.get(t, 0)) if _premises(w, t) is Machine else 0))
				+ [w.zones.food_banks_in(ZONE)[0].output.count("flour"), _premises(w, "bread").input.count("flour"),
					"%.2f" % w.zones.runners_in(ZONE).reduce(func(a, r): return a + r.wallet, 0.0)]))
		if (day + 1) % every == 0 or day == days - 1:
			print("%3d  " % (day + 1) + "  ".join(trades.map(func(t): return "%-15s" % _premises(w, t).kind.left(15))) + "  %7d  %4d   " % [sales, down_row]
				+ "  ".join(trades.map(func(t): return "%8.0f" % _owner_money(w, t))) + "  %10.0f  %7.0f  %7.0f" % [residents, w.ledger.issued, _built(w)])
			down_row = 0
	print("%d days in %.1f s. Collapses in all: %d. Money: printed $%.0f (the hero $%.0f, the fountain $%.0f), sunk into building up $%.0f, off by $%.2f." % [days, (Time.get_ticks_msec() - started) / 1000.0,
		down, w.ledger.printed, w.ledger.printed - w.ledger.issued, w.ledger.issued, _built(w), w.total_money() - w.ledger.printed])
	if final_day < 0:
		print("Final form not reached: %s." % ", ".join(w.zones.machines_in(ZONE).filter(func(m): return Catalog.next_tier(m.kind) != "").map(func(m): return "the %s (its owner has $%.0f of the $%.0f it takes)" % [m.display_name(), w.drone(m.owner).wallet, Catalog.machine(Catalog.next_tier(m.kind)).build + Trades.float_for(Catalog.next_tier(m.kind))])))
	print("sold in all: %s" % [w.zones.machines_in(ZONE).map(func(m): return "%s %d at $%.2f" % [m.kind, m.sold_total, m.price])])
	if csv != null:
		csv.close()
	quit()


## The cluster's business in `trade`, or null.
func _premises(w: World, trade: String) -> Premises:
	for m in w.zones.machines_in(ZONE):
		if m.trade == trade:
			return m
	for fb in w.zones.food_banks_in(ZONE):
		if fb.trade == trade:
			return fb
	for o in w.welfare_offices:
		if o.zone == ZONE and o.trade == trade:
			return o
	return null


func _owner_money(w: World, trade: String) -> float:
	return w.drone(_premises(w, trade).owner).wallet


func _built(w: World) -> float:
	var t := 0.0
	for m in w.machines:
		t += m.built_total
	return t
