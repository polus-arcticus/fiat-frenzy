## VIEW. The look of a civic building the map has no particular style for: a church, a station, a fire station, a town hall, a
## police station, a hospital. OsmImport.civic says which kind a building is; this makes its Landmarks style from the kind and the
## shape of its footprint (how long it is, how wide), so the same outline always gives the same building, anywhere.
##
## The styles are the ones Landmarks draws (height, walls, roof, tower, split). A building with a hand-made style there keeps that.
class_name Archetypes
extends RefCounted

const WEST := Vector2.LEFT


## The Landmarks style of a `civic` kind standing on `pts`, or {} if the kind is not one.
static func style(civic: String, pts: PackedVector2Array) -> Dictionary:
	var m := measure(pts)
	match civic:
		"church":
			return _church(m)
		"station":
			return _station(m)
		"fire":
			return _fire(m)
		"townhall":
			return _townhall(m)
		"police":
			return {"height": 11.0, "walls": Color(0.55, 0.63, 0.74), "roof_col": Color(0.45, 0.46, 0.48)}
		"hospital":
			return {"height": 15.0, "walls": Color(0.88, 0.88, 0.86), "roof_col": Color(0.60, 0.62, 0.64)}
	return {}


## A footprint's size: {length (its reach along its long axis), span (its reach across it), width (its area over its length: how
## thick it is on average), area, axis}. A square has a length and a span the same, whichever way its axis falls.
static func measure(pts: PackedVector2Array) -> Dictionary:
	var sk := Landmarks.skew(pts)
	var side := Vector2(-sk.axis.y, sk.axis.x)
	var across := 0.0
	var area := 0.0
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		area += p.x * q.y - q.x * p.y
		across = maxf(across, absf((p - sk.c).dot(side)))
	area = absf(area) * 0.5
	var length: float = sk.half * 2.0
	return {"length": length, "span": across * 2.0, "width": area / maxf(length, 1.0), "area": area, "axis": sk.axis}


## A nave under a gable with its tower at the west end (the way churches are built, the altar to the east), or for a small
## chapel just the nave: a squat one under a hip.
static func _church(m: Dictionary) -> Dictionary:
	var w: float = m.width
	var nave := clampf(w * 0.85, 7.0, 15.0)
	var long: bool = m.length >= m.span * 1.25
	var st := {"height": nave, "walls": Color(0.78, 0.72, 0.62), "roof": "gable" if long else "hip",
		"rise": clampf(w * 0.4, 3.0, 9.0), "roof_col": Color(0.40, 0.45, 0.48)}
	if m.area >= 120.0 and long:
		var size := clampf(w * 0.4, 4.0, 10.0)
		st["tower"] = {"size": size, "height": clampf(nave + w * 1.2 + 10.0, 20.0, 55.0), "spire": size * 2.4, "dir": _toward(m.axis, WEST)}
	return st


## A hall under a gable; a big one is cut like the Hauptbahnhof, a reception building at one end and the train halls arching behind.
static func _station(m: Dictionary) -> Dictionary:
	var w: float = m.width
	var h := clampf(w * 0.5, 8.0, 14.0)
	var front := {"height": h + 6.0 if m.length >= 90.0 else h, "walls": Color(0.82, 0.74, 0.60), "roof": "gable",
		"rise": clampf(w * 0.3, 3.0, 8.0), "roof_col": Color(0.40, 0.55, 0.48)}
	if m.length >= 90.0 and w >= 25.0:
		return {"split": {"end": "east", "depth": clampf(m.length * 0.3, 25.0, 55.0)}, "front": front,
			"rest": {"height": 11.0, "walls": Color(0.76, 0.72, 0.66), "roof": "vaults", "rise": 8.0,
				"strip": clampf(w * 0.5, 12.0, 38.0), "roof_col": Color(0.58, 0.72, 0.76)}}
	return front


## Red brick under a flat roof, with a hose tower (where it is big enough to have one).
static func _fire(m: Dictionary) -> Dictionary:
	var st := {"height": 10.0, "walls": Color(0.66, 0.32, 0.27), "roof_col": Color(0.45, 0.45, 0.47)}
	if m.area >= 150.0:
		st["tower"] = {"size": 4.0, "height": 17.0, "spire": 2.5, "dir": m.axis}
	return st


## Pale stone under a hip, with a clock tower at one end where it is big enough.
static func _townhall(m: Dictionary) -> Dictionary:
	var w: float = m.width
	var h := clampf(w * 0.9, 11.0, 18.0)
	var st := {"height": h, "walls": Color(0.84, 0.78, 0.66), "roof": "hip", "rise": clampf(w * 0.25, 3.0, 7.0), "roof_col": Color(0.42, 0.55, 0.48)}
	if m.area >= 250.0:
		st["tower"] = {"size": clampf(w * 0.25, 5.0, 8.0), "height": h + 16.0, "spire": 10.0, "dir": m.axis}
	return st


## `axis` turned to point toward `way` rather than away (an axis has no sign of its own).
static func _toward(axis: Vector2, way: Vector2) -> Vector2:
	return axis if axis.dot(way) >= 0.0 else -axis
