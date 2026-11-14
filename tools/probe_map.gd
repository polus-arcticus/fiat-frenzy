## Headless probe: an ASCII map of who can walk where from the landing street. '.' reachable, 'x' open but cut off, '#' solid.
##   godot --headless --path . --script tools/probe_map.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	var from: Vector2 = sc.start
	print("start ", from, " blocked? ", w.nav.blocked("district", from))
	for y in range(-70, 71, 5):
		var line := "%4d " % y
		for x in range(-80, 141, 3):
			var p := Vector2(x, y)
			if w.nav.blocked("district", p):
				line += "#"
			elif w.nav.path("district", from, p).is_empty():
				line += "x"
			else:
				line += "."
		print(line)
	quit()
