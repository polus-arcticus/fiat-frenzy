## The streets as a graph, so drones walk along them instead of through buildings. Polylines are added
## from the district data; points within half a metre of each other are the same junction.
class_name RoadGraph
extends RefCounted

const SNAP := 0.5
const SHORTCUT := 12.0  # closer than this and a drone just walks straight there

var _astar := AStar2D.new()
var _ids := {}  # snapped key -> point id
var _points := PackedVector2Array()


func add_polyline(pts: PackedVector2Array) -> void:
	var prev := -1
	for p in pts:
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
	if _points.is_empty() or from.distance_to(to) < SHORTCUT:
		out.append(to)
		return out
	var a := nearest(from)
	var b := nearest(to)
	if a != b:
		out = _astar.get_point_path(a, b)
	out.append(to)
	return out
