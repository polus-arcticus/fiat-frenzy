## Headless probe: where do the bankers go? Runs the real town for a long while with the stands open and loose bills dropped
## among them, and reports any banker who strays far from the landing street, with the job that took them there.
##   godot --headless --path . --script tools/probe_bankers.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	for m in w.machines:
		m.working = true
	var bankers := []
	for k in IntroController.BANKER_SPOTS.size():
		var s: Vector2 = IntroController.BANKER_SPOTS[k]
		var b := w.add_drifter(sc.offset_on_street(sc.wreck_pos, s.x, s.y), [12.0, 150.0, 4000.0][bankers.size()])
		b.look = "banker"
		b.bars.hunger = 0.3
		bankers.append(b)
	var reported := {}
	var seen_jobs := {}
	for t in 15000:
		w.tick(0.2)
		for b in bankers:
			if not b.job.is_empty() and not seen_jobs.has(str(b.id) + str(b.job.get("for")) + str(b.job.get("target"))):
				seen_jobs[str(b.id) + str(b.job.get("for")) + str(b.job.get("target"))] = true
				var tg = b.job.get("target")
				print("  banker %d (wallet %.0f) takes job %s -> %s at %s" % [b.id, b.wallet, b.job.get("for"), tg.get_class() if tg is Object and not (tg is RefCounted and tg.get_script() != null) else (tg.get_script().get_global_name() if tg != null else tg), (tg.pos.round() if tg != null and "pos" in tg else "")])
		if t % 25 == 0:
			for b in bankers:
				if b.pos.distance_to(sc.wreck_pos) > 70.0 and not reported.has(b.id):
					reported[b.id] = true
					var tgt = b.job.get("target")
					print("day %.1f t=%ds banker %d far away at %s job %s target %s at %s route %d care '%s'" % [w.clock.time / Clock.DAY_SECONDS, t / 5, b.id, b.pos.round(), b.job.get("for", "-"), tgt, (tgt.pos if tgt != null and "pos" in tgt else null), b.route.size(), b.care])
	print("collapses so far: ", w.rescue.rescued if "rescued" in w.rescue else "?")
	for b in bankers:
		print("end banker %d at %s job %s" % [b.id, b.pos.round(), b.job.get("for", "-")])
	quit()
