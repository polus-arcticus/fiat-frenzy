## OpenStreetMap to a public transport route: a route relation's ways joined in order into the polyline its vehicles run, and
## its stops, clipped to the part of the map that is drawn. A district keeps them as `routes`:
## [{ref, from, to, pts: [x, y, ...], stops: [{name, at: [x, y]}]}], one for each direction mapped. A line is made of one
## (Line.through) and its way is coloured along the track (RailBuilder), where whoever lays it gives it a `colour`.
class_name OsmRoute
extends RefCounted

const JOIN := 1.0   # metres: ways whose ends are this near meet


## The routes of a raw answer (`out geom`) in any frame (`local`: lat, lon -> metres), the part of each inside `rect` (its
## longest run there). A stop's name comes from the node of the same id in `names` (a raw answer with tagged nodes: the land's).
static func of(overpass: Dictionary, names: Dictionary, local: Callable, rect: Rect2) -> Array:
	var called := {}
	for e in names.get("elements", []):
		var name := str((e.get("tags", {}) as Dictionary).get("name", ""))
		if e.get("type", "") == "node" and name != "":
			called[int(e.id)] = name
	var out: Array = []
	for e in overpass.get("elements", []):
		if e.get("type", "") != "relation":
			continue
		var tags: Dictionary = e.get("tags", {})
		var way := _longest_inside(_joined(e.get("members", []), local), rect)
		if way.size() < 2:
			continue
		var stops: Array = []
		for m in e.get("members", []):
			if m.get("type", "") == "node" and str(m.get("role", "")).begins_with("stop") and m.has("lat"):
				var at: Vector2 = local.call(float(m.lat), float(m.lon))
				if rect.has_point(at):
					stops.append({"name": str(called.get(int(m.get("ref", 0)), "")), "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]})
		var flat: Array = []
		for p in way:
			flat.append(snappedf(p.x, 0.1))
			flat.append(snappedf(p.y, 0.1))
		out.append({"ref": str(tags.get("ref", "")), "from": str(tags.get("from", "")), "to": str(tags.get("to", "")), "pts": flat, "stops": stops})
	return out


## The route's own ways (not its platforms) end to end, each turned the way that carries on from the one before.
static func _joined(members: Array, local: Callable) -> PackedVector2Array:
	var ways: Array = []
	for m in members:
		if m.get("type", "") != "way" or str(m.get("role", "")) not in ["", "forward", "backward"]:
			continue
		var pts := PackedVector2Array()
		for p in m.get("geometry", []):
			if p is Dictionary and p.has("lat"):
				pts.append(local.call(float(p.lat), float(p.lon)))
		if pts.size() >= 2:
			ways.append(pts)
	var out := PackedVector2Array()
	for k in ways.size():
		var pts: PackedVector2Array = ways[k]
		var turned := false
		if out.is_empty():  # (the first: its end is the one nearer the second)
			if ways.size() > 1:
				var next: PackedVector2Array = ways[1]
				turned = minf(pts[0].distance_to(next[0]), pts[0].distance_to(next[next.size() - 1])) \
					< minf(pts[pts.size() - 1].distance_to(next[0]), pts[pts.size() - 1].distance_to(next[next.size() - 1]))
		else:
			turned = out[out.size() - 1].distance_to(pts[pts.size() - 1]) < out[out.size() - 1].distance_to(pts[0])
		if turned:
			pts = pts.duplicate()
			pts.reverse()
		var from := 1 if not out.is_empty() and out[out.size() - 1].distance_to(pts[0]) <= JOIN else 0
		out.append_array(pts.slice(from))
	return out


static func _longest_inside(pts: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_length := 0.0
	var run := PackedVector2Array()
	var length := 0.0
	for k in pts.size() + 1:
		if k < pts.size() and rect.has_point(pts[k]):
			if not run.is_empty():
				length += run[run.size() - 1].distance_to(pts[k])
			run.append(pts[k])
			continue
		if length > best_length:
			best = run
			best_length = length
		run = PackedVector2Array()
		length = 0.0
	return best
