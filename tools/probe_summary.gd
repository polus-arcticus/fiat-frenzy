## Probe: one market town run for an hour in full detail, and the same town run dormant (in summary), side by side, stand by
## stand. Shows where the summary's trade differs from the real one.
##   godot --headless --path . --script tools/probe_summary.gd
extends SceneTree

const PURSE := 200.0


func _row(w: World) -> Array:
	var out := []
	for m in w.zones.machines_in("a"):
		out.append("%-15s sold %3d crafted %3d out %2d price %5.2f working %s inputs %s" % [m.kind, m.sold_total, m.crafted_total, m.stock(), m.price, m.working, m.input.counts])
	for b in w.zones.bins_in("a"):
		out.append("%-15s holds %3d" % [b.kind, b.output.count(b.item)])
	return out


func _people(w: World) -> String:
	var by := {}
	for d in w.zones.drones_in("a"):
		var e: Array = by.get(d.kind, [0, 0.0, 0.0, 0.0])
		by[d.kind] = [e[0] + 1, e[1] + d.wallet, e[2] + d.bars.hunger, e[3] + d.bars.thirst]
	var parts := []
	for k in by:
		var e: Array = by[k]
		parts.append("%s x%d wallet %.0f hunger %.2f thirst %.2f" % [k, e[0], e[1], e[2] / e[0], e[3] / e[0]])
	return " | ".join(parts)


func _initialize() -> void:
	var full := World.new()
	Cluster.build(full, "a", Vector2.ZERO, 6, true, PURSE, false)
	var summed := World.new()
	Cluster.build(summed, "a", Vector2.ZERO, 6, true, PURSE, false)
	summed.build_zone = "hero's"
	summed.add_drifter(Vector2(5000, 0))
	summed.zones.active = ["hero's"] as Array[String]
	for minute in 61:
		if minute % 5 == 0:
			for pair in [["F", full], ["S", summed]]:
				var w: World = pair[1]
				var bins: Array = w.zones.bins_in("a").map(func(b): return "%s %d" % [b.kind, b.output.count(b.item)])
				var lem: Machine = w.zones.machines_in("a")[2]
				var runners: Array = w.zones.runners_in("a").map(func(r): return "$%.0f %s %s %s" % [r.wallet, r.runner.cart.counts, r.care, r.job.get("for", "-")])
				print("%s m%02d bins %s | lemonade crafted %2d sold %2d out %2d in %s | runners %s" % [pair[0], minute, bins, lem.crafted_total, lem.sold_total, lem.stock(), lem.input.counts, runners])
		if minute % 15 == 0:
			print("--- minute %d" % minute)
			print("FULL    ", _people(full))
			print("SUMMARY ", _people(summed))
			if minute == 60:
				for pair in [["FULL", full], ["SUMMARY", summed]]:
					print(pair[0])
					for line in _row(pair[1]):
						print("   ", line)
		for s in 60:
			full.tick(1.0)
			summed.tick(1.0)
	quit()
