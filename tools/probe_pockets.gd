## Headless probe: can everyone reach every place a bill can end up? Drops a bill on a grid of spots round the landing street,
## as the gun does (relocated if it came down on a roof), and checks there is a way to it from the street.
##   godot --headless --path . --script tools/probe_pockets.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	var from: Vector2 = sc.start
	var tried := 0
	var cut_off := 0
	var worst := []
	var near := 0
	for x in range(-60, 120, 3):
		for y in range(-60, 60, 3):
			var at := Vector2(x, y)
			var b := w.gun.land(w.gun.fire(1.0, "cash"), at)
			tried += 1
			var path := w.nav.path("district", from, b.pos)
			if path.is_empty():
				cut_off += 1
				if b.pos.distance_to(from) < 110.0:
					near += 1
					if worst.size() < 14:
						worst.append("NEAR dropped %s -> lies %s" % [at, b.pos.round()])
				elif worst.size() < 14:
					pass
			w.bills.erase(b)
	print("%d drops, %d with no way to them from the start, %d of those within 110 m" % [tried, cut_off, near])
	for s in worst:
		print("  ", s)
	quit()
