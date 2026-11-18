## Headless probe: do the food bank's cart runners (and everyone else) keep making progress? Runs the real town for a while
## with the stands open and reports anyone who has a job and has not moved for a long time.
##   godot --headless --path . --script tools/probe_runners.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	for m in w.machines:
		m.working = true
	for d in w.drones:
		d.wallet += 40.0
	var last := {}
	var still := {}
	var reported := {}
	var started := {}  # drone id -> [job target, sim time it began]
	var banker_spots := IntroController.BANKER_SPOTS
	for k in banker_spots.size():  # the helicopter's bankers, hungry, east of the medical tent
		var b := w.add_drifter(sc.offset_on_street(sc.wreck_pos, banker_spots[k].x, banker_spots[k].y), 12.0)
		b.look = "banker"
		b.bars.hunger = 0.3
	for t in 12000:
		w.tick(0.1)
		if t % 10 != 0:
			continue
		for d in w.drones:
			if d.job.is_empty() or d.care != "":
				started.erase(d.uid)
				still[d.uid] = 0
				last[d.uid] = d.pos
				continue
			if last.has(d.uid) and d.pos.distance_to(last[d.uid]) < 0.15:
				still[d.uid] = int(still.get(d.uid, 0)) + 1
			else:
				still[d.uid] = 0
			last[d.uid] = d.pos
			var key = [d.job.get("target"), d.job.get("for"), d.job.get("stage", "")]
			if not started.has(d.uid) or started[d.uid][0] != key:
				started[d.uid] = [key, t / 10]
			var age: int = t / 10 - int(started[d.uid][1])
			if (int(still[d.uid]) == 25 or age == 150) and not reported.has(d.uid):  # 25 s without moving, or one job taking 150 s
				reported[d.uid] = true
				var tgt = d.job.get("target")
				var where: Variant = tgt.pos if tgt != null and "pos" in tgt else null
				print("STUCK t=%ds drone %s (%s) job %s at %s, target at %s, route %d" % [t / 10, d.uid, d.kind, d.job.get("for"), d.pos, where, d.route.size()])
	print("done; stuck reports: ", reported.size())
	quit()
