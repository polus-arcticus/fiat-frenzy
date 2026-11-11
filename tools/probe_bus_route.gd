## Headless probe: the bus's way from its stop to the traffic jam on Battonnstraße. How long is it, how sharp are the
## turns, and would an 11 m bus clip a building going round them?
##   godot --headless --path . --script tools/probe_bus_route.gd
extends SceneTree


func _initialize() -> void:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	var district: Dictionary = JSON.parse_string(f.get_as_text())
	var sc := Scenario.new(district)
	var w := sc.build()
	var from: Vector2 = sc.bus_stop.pos
	var to: Vector2 = sc.jam.bus.pos
	var route: PackedVector2Array = w.transit._route(from, to)  # as the bus would take it (no doubling back)
	var path := PackedVector2Array([from])
	path.append_array(route)
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	var sm := BusPath.build(path)
	print("smoothed path: %d points, %.0f m; ride time about %.0f s" % [sm.pts.size(), sm.length, _ride_time(sm)])
	path = sm.pts
	print("route: %d points, %.0f m (straight line %.0f m)" % [path.size(), length, from.distance_to(to)])
	var polys: Array = []
	for b in district.buildings:
		polys.append(MapSites.pts(b.poly))
	var worst := 0
	var hits := 0
	var turns := []
	for i in range(1, path.size() - 1):
		var a: Vector2 = (path[i] - path[i - 1]).normalized()
		var b2: Vector2 = (path[i + 1] - path[i]).normalized()
		var ang := rad_to_deg(acos(clampf(a.dot(b2), -1.0, 1.0)))
		if ang > 20.0:
			turns.append("%.0f deg at %s" % [ang, path[i]])
	print("turns over 20 degrees: ", turns)
	# sample the path every 2 m: the bus rectangle (2.5 x 11) pointing along it; does it overlap a building?
	var s := 0.0
	for i in path.size() - 1:
		var seg: Vector2 = path[i + 1] - path[i]
		var n := int(seg.length() / 2.0) + 1
		for k in n:
			var p: Vector2 = path[i] + seg * (float(k) / n)
			var dir := seg.normalized()
			var side := Vector2(-dir.y, dir.x)
			var corners := PackedVector2Array([p + dir * 5.5 + side * 1.25, p + dir * 5.5 - side * 1.25, p - dir * 5.5 - side * 1.25, p - dir * 5.5 + side * 1.25])
			for poly in polys:
				if Geometry2D.intersect_polygons(corners, poly).size() > 0:
					hits += 1
					if hits <= 6:
						print("  bus would clip a building at ", p)
					break
	print("samples that clip a building: ", hits)
	# and the stands, tents and fires the street is dressed with (their footprints, as drones are kept out of them)
	var solid_hits := {}
	var solids := w.zones.solids_in("district")
	for i in path.size() - 1:
		var seg: Vector2 = path[i + 1] - path[i]
		var n := int(seg.length() / 1.0) + 1
		for k in n:
			var p: Vector2 = path[i] + seg * (float(k) / n)
			var dir := seg.normalized()
			var side := Vector2(-dir.y, dir.x)
			var corners := PackedVector2Array([p + dir * 5.5 + side * 1.25, p + dir * 5.5 - side * 1.25, p - dir * 5.5 - side * 1.25, p - dir * 5.5 + side * 1.25])
			for si in solids.size():
				for part in solids[si].parts:
					if part.r > 0.0:
						continue
					var az := Vector2(-part.ax.y, part.ax.x)
					var box := PackedVector2Array([part.c + part.ax * part.half.x + az * part.half.y, part.c + part.ax * part.half.x - az * part.half.y, part.c - part.ax * part.half.x - az * part.half.y, part.c - part.ax * part.half.x + az * part.half.y])
					var overlap := Geometry2D.intersect_polygons(corners, box)
					if overlap.size() > 0:
						var area := 0.0
						for poly in overlap:
							for q in poly.size():
								area += poly[q].cross(poly[(q + 1) % poly.size()]) * 0.5
						solid_hits[si] = [p, snappedf(absf(area), 0.01)]
	print("street dressing the bus would drive through: ", solid_hits.size(), " ", solid_hits)
	quit()


## Simulate the profile: how long the ride takes.
func _ride_time(p: BusPath) -> float:
	var t := 0.0
	var s := 0.0
	var v := 0.0
	while s < p.length - 0.1 and t < 1000.0:
		var target := p.speed_at(minf(s + 1.0 + v * 0.4, p.length))
		v = move_toward(v, target, (BusPath.ACCEL if target > v else BusPath.BRAKE) * 0.1)
		v = maxf(v, 0.15)
		s += v * 0.1
		t += 0.1
	return t
