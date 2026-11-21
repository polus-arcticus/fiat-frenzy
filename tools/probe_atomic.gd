## Probe: the atom (see Atom), found and funded once, run on its own in summary. With `grow=N` its tent city is built up to a
## hostel on day one and N tents are put up, so N newcomers come (a weighted roll: see Lodging.NEWCOMERS).
##   godot --headless --path . --script tools/probe_atomic.gd -- [days=60] [grow=N]
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
	w.begin_play()
	Cluster.fund(w, "atom")
	var grow := _arg("grow", "0").to_int()
	if grow > 0:
		city.retier("hostel")
		for i in grow:
			w.lodging.add_tent(city)
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
			elif "built up" in w.events[i]:
				print("     day %d: %s" % [day + 1, w.events[i]])
		seen = w.events.size()
		if (day + 1) % 20 == 0:
			print("day %3d  sold %3d/day  collapses so far %d  people %d (%s)" % [day + 1, Fixtures.sold(w, "atom") - before, down, w.zones.drones_in("atom").size(),
				", ".join(w.zones.drones_in("atom").map(func(d): return "%s $%.0f" % [d.kind.left(6), d.wallet]))])
	print("%d collapses in %d days; money off by %.2f" % [down, days, w.total_money() - w.ledger.printed])
	quit()
