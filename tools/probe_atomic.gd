## Probe: the atom (see Atom), grown through its founders (a tent for each, as the hero would: Atom.grow), found and funded once,
## run on its own in summary (or `full`: in full detail). With `founders=N` only the first N come. Prints who collapses, what is
## built up, and everyone's money every 20 days.
##   godot --headless --path . --script tools/probe_atomic.gd -- [days=60] [founders=N] [full]
extends SceneTree


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	var days := _arg("days", "60").to_int()
	var w := World.new(false)
	var city := Atom.seed(w, "atom", Vector2.ZERO)
	Atom.grow(w, city, _arg("founders", "-1").to_int())
	w.begin_play()
	Cluster.fund(w, "atom")
	if not OS.get_cmdline_user_args().has("full"):
		w.build_zone = "elsewhere"
		w.add_drifter(Vector2(9000, 0)).make_needless()
		w.zones.active = ["elsewhere"] as Array[String]
	var seen := 0
	var down := 0
	for day in days:
		var before := Fixtures.sold(w, "atom")
		for s in int(Clock.DAY_SECONDS):
			w.tick(1.0)
		for i in range(seen, w.events.size()):
			if "collapsed" in w.events[i]:
				down += 1
				var who: Array = w.drones.filter(func(d): return d.label != "" and d.label in w.events[i])
				var what := "%s %s, $%.2f, bars %s" % [who[0].kind, w.profession_of(who[0]), who[0].wallet, who[0].bars] if not who.is_empty() else ""
				print("     day %d: %s (%s)" % [day + 1, w.events[i], what])
			elif "built up" in w.events[i]:
				print("     day %d: %s" % [day + 1, w.events[i]])
		seen = w.events.size()
		if (day + 1) % 20 == 0:
			print("day %3d  sold %3d/day  collapses so far %d  people %d (%s)" % [day + 1, Fixtures.sold(w, "atom") - before, down, w.zones.drones_in("atom").size(),
				", ".join(w.zones.drones_in("atom").map(func(d): return "%s $%.0f" % [d.kind.left(6), d.wallet]))])
	print("%d collapses in %d days; money off by %.2f" % [down, days, w.total_money() - w.ledger.printed])
	quit()
