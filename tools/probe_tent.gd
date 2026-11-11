## Headless probe: do walkers get stuck on the medical tent? Sends a drifter from points all round it to points on
## the far side, in the real scenario (street graph and all), and reports the ones that make no progress.
##   godot --headless --path . --script tools/probe_tent.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var sc := Scenario.new(JSON.parse_string(f.get_as_text()))
	var w := sc.build()
	if "--noroads" in OS.get_cmdline_user_args():
		w.roads = null
	var h: Hospital = w.hospitals[0]
	print("hospital at ", h.pos, " front ", h.front)
	var stuck := 0
	var tried := 0
	for a in 24:
		for r_goal in [4.0, 7.0, 12.0]:
			var ang: float = TAU * a / 24.0
			var start: Vector2 = h.pos + Vector2.from_angle(ang) * 4.5
			var goal: Vector2 = h.pos + Vector2.from_angle(ang + PI) * r_goal
			if w.zones.solids_in("district").any(func(s): return s.parts.any(func(p): return p.contains(start, 0.0) or p.contains(goal, 0.0))):
				continue
			var d := w.add_drifter(start, 0.0)
			d.speed = 1.5
			tried += 1
			var best := start.distance_to(goal)
			var t := 0
			while t < 900 and d.pos.distance_to(goal) > 0.6:
				w.walking.step(d, goal, 0.1)
				t += 1
			if d.pos.distance_to(goal) > 0.6:
				stuck += 1
				print("STUCK angle %3d goal r %2.0f: ended %.1f m from goal at %s" % [rad_to_deg(ang), r_goal, d.pos.distance_to(goal), d.pos])
	print("tried %d, stuck %d" % [tried, stuck])
	quit()
