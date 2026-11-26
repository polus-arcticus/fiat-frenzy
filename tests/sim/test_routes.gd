## Sim tests: public transport routes (OsmRoute: a route relation's ways joined into the way its vehicles run, with its stops),
## the colour along it (RailBuilder), and the street kept clear for a tram's track (Kerbs).
extends TestCase


func _geometry(pts: Array) -> Array:
	return pts.map(func(p): return {"lat": p[1], "lon": p[0]})


func _metres(lat: float, lon: float) -> Vector2:
	return Vector2(lon, lat)


func test_a_routes_ways_are_one_way_with_its_stops() -> void:
	var answer := {"elements": [{"type": "relation", "id": 1, "tags": {"ref": "7", "to": "East"}, "members": [
		{"type": "node", "ref": 11, "role": "stop", "lat": 0.0, "lon": 20.0},
		{"type": "node", "ref": 12, "role": "stop", "lat": 0.0, "lon": 180.0},
		{"type": "node", "ref": 13, "role": "stop", "lat": 0.0, "lon": 900.0},
		{"type": "node", "ref": 14, "role": "platform", "lat": 3.0, "lon": 20.0},
		{"type": "way", "role": "", "geometry": _geometry([[100.0, 0.0], [0.0, 0.0]])},  # (drawn backwards, and first)
		{"type": "way", "role": "", "geometry": _geometry([[100.0, 0.0], [200.0, 0.0]])},
		{"type": "way", "role": "platform", "geometry": _geometry([[10.0, 3.0], [30.0, 3.0]])},
		{"type": "way", "role": "", "geometry": _geometry([[600.0, 0.0], [200.0, 0.0]])}]}]}
	var names := {"elements": [{"type": "node", "id": 11, "tags": {"name": "West Gate"}}, {"type": "node", "id": 12, "tags": {"name": "Middle"}}]}
	var routes := OsmRoute.of(answer, names, _metres, Rect2(-10, -50, 400, 100))
	check(routes.size() == 1 and routes[0].ref == "7" and routes[0].to == "East", "one route, with its number and where it goes")
	check(routes[0].pts == [0.0, 0.0, 100.0, 0.0, 200.0, 0.0], "its ways end to end, its platforms left out, as far as the map goes (%s)" % [routes[0].pts])
	check(routes[0].stops.map(func(s): return s.name) == ["West Gate", "Middle"], "its stops on the map, named (%s)" % [routes[0].stops.map(func(s): return s.name)])


func test_a_coloured_route_is_a_band_along_its_track() -> void:
	var plain := RailBuilder.bake({}, null, 0.0, [{"pts": [0.0, 0.0, 50.0, 0.0]}])
	var banded := RailBuilder.bake({}, null, 0.0, [{"pts": [0.0, 0.0, 50.0, 0.0], "colour": Color.RED}])
	check(plain.rails.v.is_empty(), "a route nobody colours is not drawn")
	var v: PackedVector3Array = banded.rails.v
	check(v.size() >= 4 and Array(v).all(func(p): return absf(p.z) <= RailBuilder.ROUTE_HALF + 0.01 and p.y < OsmRail.STREET_HEAD), "a coloured one is a band between the rails, under their heads")


func test_no_pavement_on_a_trams_track() -> void:
	var street := {"buildings": [], "roads": [{"class": "residential", "w": 4.0, "pave": [8.0, 8.0], "pts": [0.0, 0.0, 60.0, 0.0]}]}
	var track := street.duplicate()
	track["rail"] = {"tracks": [{"id": 1, "kind": "tram", "pts": PackedVector2Array([Vector2(0, 4), Vector2(60, 4)])}]}
	var before := Kerbs.of(street)
	var after := Kerbs.of(track)
	check(before.height_at(Vector2(30, 4)) > 0.0, "beside the carriageway is pavement")
	check(after.height_at(Vector2(30, 4)) == 0.0 and after.height_at(Vector2(30, 4.7)) == 0.0, "but not where a tram's track runs along it")
	check(after.height_at(Vector2(30, 6.5)) > 0.0 and after.height_at(Vector2(30, -4)) > 0.0, "the platform beside it and the far side are as they were")
