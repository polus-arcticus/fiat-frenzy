## Headless probe: what happens to a walker beyond the navigation grid? Reports the grid's extent and walks a drone to far goals.
##   godot --headless --path . --script tools/probe_edge.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	var g = w.nav._grid("district")
	print("grid origin %s size %s => x %.0f..%.0f, y %.0f..%.0f" % [g.origin, g.size, g.origin.x, g.origin.x + g.size.x * 0.5, g.origin.y, g.origin.y + g.size.y * 0.5])
	print("district bounds from data: ", sc.district.bounds if "district" in sc else "?")
	for goal in [Vector2(60, -95), Vector2(60, -60), Vector2(-100, 10), Vector2(200, 0)]:
		var d := w.add_drifter(sc.wreck_pos, 0.0)
		var inside_wall := 0
		var steps := 0
		while d.pos.distance_to(goal) > 0.6 and steps < 4000:
			w.walking.step(d, goal, 0.1)
			steps += 1
			if w.nav.unreachable("district", d.pos):
				inside_wall += 1
		print("to %s: %s after %d steps, %d steps inside a wall, ended at %s" % [goal, "arrived" if d.pos.distance_to(goal) <= 0.6 else "NOT arrived", steps, inside_wall, d.pos.round()])
	quit()
