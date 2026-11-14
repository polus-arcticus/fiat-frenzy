## Headless probe: fund the town, then spray the bankers with money. Some bills hit; the misses fly on and land well beyond
## (up to 140 m, as far as a shot goes). Afterwards: did every banker stay in the market, or did one go chasing the strays?
##   godot --headless --path . --script tools/probe_spray.gd
extends SceneTree


func _initialize() -> void:
	seed(7)
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var strays := 0
	var trials := 12
	for trial in trials:
		var w := sc.build()
		for m in w.machines:
			m.working = true
		for d in w.drones:
			d.wallet += 60.0
		var bankers := []
		for s in IntroController.BANKER_SPOTS:
			var b := w.add_drifter(sc.offset_on_street(sc.wreck_pos, s.x, s.y), 12.0)
			b.look = "banker"
			b.bars.hunger = 0.3
			bankers.append(b)
		var hero := Vector2(48.0, -4.0) + Vector2(randf_range(-8, 8), randf_range(-6, 6))
		for t in 600:  # a minute of spraying
			w.tick(0.1)
			if t % 3 == 0:
				var target: Drone = bankers[randi() % 3]
				var b := w.gun.fire(5.0, "gift")
				if randf() < 0.4:
					w.gun.hit(b, target)
				else:
					var dir := (target.pos - hero).normalized().rotated(randf_range(-0.35, 0.35))
					w.gun.land(b, hero + dir * randf_range(20.0, 140.0))
		for t in 3000:  # then leave them to it, five minutes
			w.tick(0.1)
		var far := 0.0
		for b in bankers:
			far = maxf(far, b.pos.distance_to(sc.wreck_pos))
		if far > 70.0:
			strays += 1
		print("trial %d: farthest banker %.0f m from the wreck%s" % [trial, far, "   <== STRAY" if far > 70.0 else ""])
	print("%d of %d trials sent a banker off" % [strays, trials])
	quit()
