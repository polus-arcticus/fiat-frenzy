## Headless probe: the street route from each banker landing spot to every stand, fire and the food bank; flags detours.
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	var goals := {}
	for m in w.machines:
		goals["%s" % m.pos.round()] = m.pos + m.front * 2.0
	for fi in w.fires:
		goals["fire"] = fi.pos + Vector2(1.5, 0)
	for s in IntroController.BANKER_SPOTS:
		var from := sc.offset_on_street(sc.wreck_pos, s.x, s.y)
		for k in goals:
			var r := w.roads.route(from, goals[k])
			var len := 0.0
			var at := from
			var far := 0.0
			for p in r:
				len += at.distance_to(p)
				far = maxf(far, p.distance_to(from))
				at = p
			var direct := from.distance_to(goals[k])
			print("from %s to %s: direct %.0f m, route %.0f m, farthest %.0f m%s" % [from.round(), k, direct, len, far, "   <== DETOUR" if len > direct * 1.8 + 15 else ""])
	quit()
