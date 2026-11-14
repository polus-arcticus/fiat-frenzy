## Headless probe: what does landing a bill cost? (the pocket check floods outward from it)
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	w.nav.enclosed("district", sc.start)  # (the grid is built)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		w.gun.land(w.gun.fire(1.0, "cash"), sc.start + Vector2(i % 20, i / 20) * 2.0)
		w.bills.clear()
	print("average landing: %.2f ms" % ((Time.get_ticks_usec() - t0) / 200.0 / 1000.0))
	quit()
