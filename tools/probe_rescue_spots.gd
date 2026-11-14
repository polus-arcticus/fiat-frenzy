## Headless probe: collapse someone at many spots round the market and see whether the ambulance always gets them to a bed.
## Reports any rescue that has not finished in 4 minutes, and how far the ambulance strayed.
##   godot --headless --path . --script tools/probe_rescue_spots.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var tried := 0
	var failed := 0
	for x in range(-30, 90, 12):
		for y in range(-25, 40, 8):
			var w := sc.build()
			if w.ambulances.is_empty():
				print("no ambulance in the town")
				quit()
				return
			var d := w.add_drifter(Vector2(x, y), 20.0)
			if w.nav.unreachable("district", d.pos):
				continue
			tried += 1
			w.rescue.go_down(d)
			var a: Ambulance = w.ambulances[0]
			var far := 0.0
			for t in 2400:
				w.tick(0.1)
				far = maxf(far, a.pos.distance_to(a.hospital.bay()))
				if d.care == "patient" or d.care == "":
					break
			if d.care == "down" or d.care == "carried":
				failed += 1
				print("STUCK at %s: care '%s', ambulance %s job %d, strayed %.0f m" % [Vector2(x, y), d.care, a.pos.round(), a.job, far])
	print("%d collapses tried, %d not rescued in 4 minutes" % [tried, failed])
	quit()
