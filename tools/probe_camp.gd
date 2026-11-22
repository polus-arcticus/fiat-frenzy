## Probe: the atom's baseline with a park camp beside it (SiteFinder.camp, Camp.pitch with its own fire), over many dice. The
## user's target: an expected value of zero collapses, and no real capital formed for at least a month (docs/balance.md).
##   godot --headless --path . --script tools/probe_camp.gd -- [atoms=8] [days=60] [camp=0|1] [walk=40]
## In summary (away from the hero), as the atom bench is; `walk` is how far the camp is from the market.
extends SceneTree


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	var atoms := _arg("atoms", "8").to_int()
	var days := _arg("days", "60").to_int()
	var with_camp := _arg("camp", "1") == "1"
	var off := _arg("walk", "40").to_float()
	var total := 0
	var money30 := 0.0
	var issued := 0.0
	var start_money := 0.0
	var money_end := 0.0
	for k in atoms:
		var w := World.new(false)
		w.rng.seed = 1000 + k
		Atom.seed(w, "atom", Vector2.ZERO)
		if with_camp:
			w.build_zone = "atom"
			Camp.pitch(w, Vector2(-off * 0.6, off * 0.8), Vector2(0, -1), Camp.KEEPER_WALLET, "scrap_camp", "Camp keeper", true)
		w.begin_play()
		Cluster.fund(w, "atom")
		w.build_zone = "elsewhere"
		w.add_drifter(Vector2(9000, 0)).make_needless()
		w.zones.active = ["elsewhere"] as Array[String]
		start_money += _money(w)
		var seen := 0
		var down := 0
		var who := {}
		for day in days:
			for s in int(Clock.DAY_SECONDS):
				w.tick(1.0)
			for i in range(seen, w.events.size()):
				if "collapsed" in w.events[i]:
					down += 1
					var name: String = w.events[i].split(" ", false, 1)[1].trim_suffix(" collapsed")
					who[name] = who.get(name, 0) + 1
				elif "built up" in w.events[i]:
					who["day %d" % (day + 1)] = w.events[i].split(" ", false, 1)[1].left(60)
			seen = w.events.size()
			if day + 1 == 30:
				money30 += _money(w)
				if k == 0:
					print("  day 30 wallets: ", ", ".join(w.drones.filter(func(d): return d.zone == "atom").map(func(d): return "%s $%.0f" % [w.profession_of(d), d.wallet])))
		issued += w.ledger.issued
		total += down
		money_end += _money(w)
		print("atom %d: %d collapses %s, people %d, built: %s" % [k, down, who, w.zones.drones_in("atom").size(),
			", ".join(w.machines.filter(func(m): return m.zone == "atom").map(func(m): return m.kind))])
	print("%d atoms x %d days, camp %s: %.2f collapses per atom; residents' money $%.0f -> $%.0f at day 30 -> $%.0f at day %d; issued $%.0f per atom" % [
		atoms, days, with_camp, float(total) / atoms, start_money / atoms, money30 / atoms, money_end / atoms, days, issued / atoms])
	quit()


func _money(w: World) -> float:
	var m := 0.0
	for d in w.drones:
		if d.zone == "atom":
			m += d.wallet
	return m
