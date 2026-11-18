## Bench: does a town keep itself going once the hero has got it started? The standard cluster (see Cluster) as a block is
## found, every stall wrecked and every vendor broke. The "hero" pays each vendor what their repair costs (and a little over)
## once, and leaves. Then the town runs on its own for DAYS game days (a day is 600 s), and each day prints what happened.
##   godot --headless --path . --script tools/bench_economy.gd [-- summary] [nowelfare] [gift] [<days>]
## With `summary` the town is dormant (TileSummary) instead of in full detail; with `nowelfare` it has no welfare office (the
## economy as it was before the town's purse); with `gift` the hero gives the baker $100 on day 5 (do they keep it?). Each
## day's row ends with who collapsed and what ran out ("had money": they had $3 or more on them).
extends SceneTree

const DAYS := 30
const ZONE := "town"


func _build(welfare: bool) -> World:
	var w := World.new(false)  # (the engine alone: no hero, no story)
	Cluster.found(w, ZONE, Vector2.ZERO)
	if not welfare:
		w.welfare_offices.clear()  # (its clerk stays, a needless bystander)
	w.begin_play()
	return w


func _roles(w: World) -> Dictionary:
	var out := {}
	for d in w.zones.drones_in(ZONE):
		out[d.kind] = float(out.get(d.kind, 0.0)) + d.wallet
	return out


func _initialize() -> void:
	var summary := "summary" in OS.get_cmdline_user_args()
	var w := _build(not "nowelfare" in OS.get_cmdline_user_args())
	Cluster.fund(w, ZONE)  # the hero funds the repairs, once
	if summary:
		w.build_zone = "elsewhere"
		w.add_drifter(Vector2(9000, 0))
		w.zones.active = ["elsewhere"] as Array[String]
	var days := DAYS
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			days = a.to_int()  # (a number among the arguments: run that many days instead)
	print("%s, %d days. Hero's funding: $%.0f; money in the world $%.2f" % ["SUMMARY" if summary else "FULL DETAIL", days, w.ledger.printed, w.total_money()])
	print("day  sales  collapses  no-sale streak  runners broke(s)  mean $   drifters  vendors  runners   keeper  purse  issued   off")
	var last_sold := 0
	var last_events := 0
	var gifted: Drone = null  # with `gift`: the hero gives the baker $100 at the start of day 5, and we watch whether they keep it
	for day in days:
		if day == 4 and "gift" in OS.get_cmdline_user_args():
			gifted = w.zones.drones_in(ZONE).filter(func(d): return w.machine_of(d) != null and w.machine_of(d).kind == "bakery")[0]
			w.gun.gift(gifted, 100.0)
		var streak := 0
		var worst := 0
		var broke := 0
		var why := {}  # what ran out, for everyone who collapsed today: "thirst $1.20" (and what they had on them)
		for s in int(Clock.DAY_SECONDS):
			var before := Fixtures.sold(w, ZONE)
			var up := w.zones.drones_in(ZONE).filter(func(d): return d.care == "")
			w.tick(1.0)
			for d in up:
				if d.care != "":  # (down, or in summary already a patient: the tent takes them in the same tick)
					var bar: String = d.bars.keys().reduce(func(a, b): return a if d.bars[a] <= d.bars[b] else b)
					var who: String = w.machine_of(d).kind if w.machine_of(d) != null else d.kind
					var key := "%s %s%s" % [who, bar, " (had money)" if d.wallet >= 3.0 else ""]
					why[key] = int(why.get(key, 0)) + 1
			streak = 0 if Fixtures.sold(w, ZONE) > before else streak + 1
			worst = maxi(worst, streak)
			for r in w.zones.runners_in(ZONE):
				if r.wallet < 1.0:
					broke += 1
		var sold := Fixtures.sold(w, ZONE)
		var down := 0
		for i in range(last_events, w.events.size()):
			if w.events[i].contains("collapsed"):
				down += 1
		last_events = w.events.size()
		var prices := w.zones.machines_in(ZONE).filter(func(m): return m.working and Catalog.class_of(m.item) in ["food", "drink"]).map(func(m): return m.price)
		var mean: float = prices.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, prices.size())
		var r := _roles(w)
		var other := 0.0
		for k in r:
			if not k in ["drifter", "vendor", "runner", "keeper"]:
				other += r[k]
		print("%3d  %5d  %9d  %13ds  %16d  %6.2f  %8.2f %8.2f %8.2f %8.2f %6.2f %7.2f  %5.2f" % [day + 1, sold - last_sold, down, worst, broke, mean,
			r.get("drifter", 0.0), r.get("vendor", 0.0), r.get("runner", 0.0), r.get("keeper", 0.0), other, w.ledger.issued, w.total_money() - w.ledger.printed] + ("   down: %s" % why if not why.is_empty() else ""))
		last_sold = sold
		if gifted != null:
			print("     (the baker, given $100 on day 5, has $%.2f)" % gifted.wallet)
	print("sold in all: %s" % [w.zones.machines_in(ZONE).map(func(m): return "%s %d at $%.2f" % [m.kind, m.sold_total, m.price])])
	quit()
