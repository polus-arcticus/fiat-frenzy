## Headless probe: can people walk between the places they actually go (every stand, the food bank, the tent door, the
## bus stop), in the real scenario with its street graph? Reports the trips that never arrive.
##   godot --headless --path . --script tools/probe_routes.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	var spots := {}
	for m in w.machines:
		spots[m.display_name()] = m.pos + m.front * 1.6
	for fb in w.food_banks:
		spots["Food bank"] = fb.pos + fb.front * 1.6
	spots["Medical tent door"] = w.hospitals[0].solid().door
	spots["Bus stop"] = w.bus_stop
	for k in IntroController.BANKER_SPOTS.size():  # where the helicopter's bankers land: east of the medical tent
		var spot: Vector2 = IntroController.BANKER_SPOTS[k]
		spots["banker %d" % k] = sc.offset_on_street(sc.wreck_pos, spot.x, spot.y)
	spots["Medical tent door"] = w.hospitals[0].solid().door
	spots["Bus stop"] = w.bus_stop
	for d in w.drones:
		if d.look == "banker":
			spots["banker %d" % d.id] = d.pos
			spots["banker %d, 3 m on" % d.id] = d.pos + Vector2(3, 3)
	spots["Start"] = sc.start
	spots.erase("Bike shop")  # the shops' counters are inside their buildings: not somewhere to walk to
	spots.erase("Skate shop")
	var names := spots.keys()
	var stuck := 0
	var trips := 0
	for a in names:
		for b in names:
			if a == b:
				continue
			var d := w.add_drifter(spots[a], 0.0)
			trips += 1
			var t := 0
			while t < 3000 and d.pos.distance_to(spots[b]) > 0.8:
				w.walking.step(d, spots[b], 0.1)
				t += 1
			if d.pos.distance_to(spots[b]) > 0.8:
				stuck += 1
				print("STUCK %s -> %s: %.1f m short, at %s" % [a, b, d.pos.distance_to(spots[b]), d.pos])
	print("trips %d, never arrived %d" % [trips, stuck])
	quit()
