## The streets as a graph, so drones walk along them instead of through buildings. Polylines are added
## from the district data; points within half a metre of each other are the same junction.
class_name RoadGraph
extends RefCounted

const SNAP := 0.5
const SHORTCUT := 12.0  # closer than this and a drone just walks straight there

## Closer than this and a drone walks straight there (the navigation grid takes it round anything in the way). A tile sets it to
## its market's length: the stalls there are nearer each other than to any street.
var shortcut := SHORTCUT
var _astar := AStar2D.new()
var _ids := {}  # snapped key -> point id
var _points := PackedVector2Array()


## `every` > 0 also puts a point every that many metres along each stretch. The map only has points where a street bends, and a
## walker joins the graph at its nearest point: on a long straight street (a square mapped as one line) that can be far off, or
## on another street, and a trip of twenty metres went round the block. (A tile's streets are added this way; the story's
## Frankfurt, laid out round its own, is not.)
func add_polyline(pts: PackedVector2Array, every := 0.0) -> void:
	var prev := -1
	for i in pts.size():
		var stops: Array[Vector2] = [pts[i]]
		if every > 0.0 and i > 0:
			var a := pts[i - 1]
			var n := floori(a.distance_to(pts[i]) / every)
			stops = []
			for k in range(1, n + 1):
				stops.append(a.lerp(pts[i], float(k) / float(n + 1)))
			stops.append(pts[i])
		for p in stops:
			var id := _id_for(p)
			if prev >= 0 and prev != id and not _astar.are_points_connected(prev, id):
				_astar.connect_points(prev, id)
			prev = id


func _id_for(p: Vector2) -> int:
	var key := Vector2i(roundi(p.x / SNAP), roundi(p.y / SNAP))
	if _ids.has(key):
		return _ids[key]
	var id := _points.size()
	_points.append(p)
	_astar.add_point(id, p)
	_ids[key] = id
	return id


func point_count() -> int:
	return _points.size()


func nearest(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in _points.size():
		var d := _points[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## The waypoints from `from` to `to`, ending exactly at `to`.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _points.is_empty() or from.distance_to(to) < shortcut:
		out.append(to)
		return out
	var a := nearest(from)
	var b := nearest(to)
	if a != b:
		out = _astar.get_point_path(a, b)
	out.append(to)
	return out
