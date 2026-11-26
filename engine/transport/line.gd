## A line a vehicle runs on, stop to stop (Vehicle.run_on, Transit.ride): a polyline and the stops along it, each by its
## distance along (`s`). It is only geometry: nothing here knows the hero or the world. It is made one of two ways:
##   from the railway (`pick`)  the mapped tracks (OsmRail) joined end to end. The tracks of a tile come in pieces, a way between
##                              each pair of switches, so the line is made by walking from piece to piece where one carries on
##                              from another within a gentle bend, and it is the chain with the most stops (stations and halts,
##                              and trams' stops) on it, then the longest, that is kept. Yards and sidings are not for
##                              passengers' trains, so they are not on a line.
##   along any way (`through`)  a bus's route through the streets (RoadGraph), a path laid out by hand (the bank's golf cart): the
##                              places near it are its stops.
## A line with no two stops on it has its two ends for stops.
class_name Line
extends RefCounted

const SNAP := 0.75         # metres: track ends this near are one point
const BEND := 0.64         # the cosine of the sharpest bend one track carries on from another with (about 50 degrees)
const STOP_REACH := 45.0   # a station this near the line is on it (a station is mapped in its hall, not on its rails)
const STOP_APART := 80.0   # stops nearer than this along the line are one stop (a station's platforms)
const END_INSET := 20.0    # a line with no stops mapped on it: its two ends, this far in
const MIN_LENGTH := 60.0   # a line shorter than this is not worth a train

var name := ""                    # what its vehicles' signs say (the map's, or the story's: "EZB Ostend")
var number := ""                  # ...its number, where it has one ("11")...
var colour := Color(0, 0, 0, 0)   # ...and its colour (none: its vehicles' own)
var pts := PackedVector2Array()
var cum := PackedFloat32Array()   # distance along the line to each point
var length := 0.0
var stops: Array = []             # [{name: String, at: Vector2 (on the line), s: float}], in order along it


## The line along `route`, its stops the `places` ([{at, name}]) within `reach` metres of it, those nearer than `apart` along it
## being one stop. Null if it is too short to ride. (A hand-laid line keeps every place: give them on the route itself.)
static func through(route: PackedVector2Array, places: Array, called := "", reach := STOP_REACH, apart := STOP_APART, shortest := MIN_LENGTH) -> Line:
	var line := _make(route, places, reach, apart, shortest)
	if line != null:
		line.name = called
	return line


## The line of `rail` (OsmRail's district entry) with the most stops, counting `extra` (more places a train stops: a tram's
## stops, mapped in the street layer: [{at, name}]). Null if the rail has no line.
static func pick(rail: Dictionary, extra: Array = []) -> Line:
	var tracks: Array = rail.get("tracks", []).filter(func(t): return not bool(t.get("service", false)) and (t.pts as PackedVector2Array).size() >= 2)
	var places: Array = rail.get("stops", []).duplicate()
	places.append_array(extra)
	var best: Line = null
	var best_score := -1.0
	for chain in _chains(tracks):
		var line := _make(chain, places)
		if line == null:
			continue
		var score := float(line.stops.size()) * 100000.0 + line.length
		if score > best_score:
			best_score = score
			best = line
	return best


## The index of the first stop called `called`, or -1.
func stop_called(called: String) -> int:
	for k in stops.size():
		if str(stops[k].name) == called:
			return k
	return -1


## The point of the line `s` metres along it.
func pos_at(s: float) -> Vector2:
	var k := _at(s)
	var seg := cum[k + 1] - cum[k]
	return pts[k].lerp(pts[k + 1], (clampf(s, 0.0, length) - cum[k]) / maxf(seg, 0.0001))


## The way the line points `s` metres along it (a unit vector, toward its end).
func dir_at(s: float) -> Vector2:
	var k := _at(s)
	return (pts[k + 1] - pts[k]).normalized()


## The way to go from stop `from` to stop `to`: the stop's point, the corners of the line between, and the other stop's point.
func between(from: int, to: int) -> PackedVector2Array:
	return span(stops[from].s, stops[to].s)


## The way from `a` to `b` metres along the line (either way round): the points at each, and the line's corners between.
func span(a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array([pos_at(a)])
	if a <= b:
		for k in pts.size():
			if cum[k] > a + 0.01 and cum[k] < b - 0.01:
				out.append(pts[k])
	else:
		for k in range(pts.size() - 1, -1, -1):
			if cum[k] < a - 0.01 and cum[k] > b + 0.01:
				out.append(pts[k])
	out.append(pos_at(b))
	return out


## The way a train at stop `i` faces to go toward stop `toward` (+1: on along the line, -1: back): an angle, as Vehicle.heading.
func heading_at(i: int, toward: int) -> float:
	return (dir_at(stops[i].s) * float(toward)).angle()


func _at(s: float) -> int:
	var k := 0
	while k < pts.size() - 2 and cum[k + 1] < s:
		k += 1
	return k


# ---------------------------------------------------------------- making a line


## The tracks joined into chains: from each track, on from its end to whichever track carries on most nearly straight (within
## BEND), then the same from its start. A chain is a polyline.
static func _chains(tracks: Array) -> Array:
	var ends := {}  # where a track starts or finishes -> [[track, 0 (its start) or 1 (its finish)]]
	for i in tracks.size():
		var p: PackedVector2Array = tracks[i].pts
		for e in 2:
			var k := _key(p[0] if e == 0 else p[p.size() - 1])
			if not ends.has(k):
				ends[k] = []
			ends[k].append([i, e])
	var out: Array = []
	for first in tracks.size():
		var chain := PackedVector2Array(tracks[first].pts)
		var taken := {first: true}
		for turn in 2:
			var carried := true
			while carried:
				carried = false
				var tip := chain[chain.size() - 1]
				var heading := _heading(chain)
				var pick := PackedVector2Array()
				var pick_at := -1
				var pick_dot := BEND
				for c in ends.get(_key(tip), []):
					if taken.has(c[0]):
						continue
					var q: PackedVector2Array = tracks[c[0]].pts
					var cand := q if c[1] == 0 else _reversed(q)
					var d := heading.dot((cand[1] - cand[0]).normalized())
					if d > pick_dot:
						pick_dot = d
						pick = cand
						pick_at = c[0]
				if pick_at >= 0:
					taken[pick_at] = true
					chain.append_array(pick.slice(1))
					carried = true
			chain = _reversed(chain)
		out.append(chain)
	return out


## The line along `chain` with the stops of `places` that lie on it, or null if there is nothing to ride.
static func _make(chain: PackedVector2Array, places: Array, reach := STOP_REACH, apart := STOP_APART, shortest := MIN_LENGTH) -> Line:
	var line := Line.new()
	for p in chain:
		if line.pts.is_empty() or p.distance_to(line.pts[line.pts.size() - 1]) > 0.01:
			line.pts.append(p)
	if line.pts.size() < 2:
		return null
	line.cum.append(0.0)
	for k in range(1, line.pts.size()):
		line.cum.append(line.cum[k - 1] + line.pts[k].distance_to(line.pts[k - 1]))
	line.length = line.cum[line.cum.size() - 1]
	if line.length < shortest:
		return null
	var found: Array = []
	for pl in places:
		var hit := line._project(pl.at)
		if hit.d <= reach:
			found.append({"name": str(pl.get("name", "")), "at": hit.at, "s": hit.s})
	found.sort_custom(func(a, b): return a.s < b.s)
	for f in found:
		if not line.stops.is_empty() and f.s - float(line.stops[line.stops.size() - 1].s) < apart:
			if str(line.stops[line.stops.size() - 1].name) == "":
				line.stops[line.stops.size() - 1].name = f.name
			continue
		line.stops.append(f)
	if line.stops.size() < 2:  # too little mapped on it to ride between: its ends are stops too (all of them, where nothing is)
		for e in [[END_INSET, "the end of the line"], [line.length - END_INSET, "the other end"]]:
			if line.stops.all(func(s): return absf(float(s.s) - float(e[0])) >= STOP_APART):
				line.stops.append({"name": e[1], "at": line.pos_at(e[0]), "s": e[0]})
		line.stops.sort_custom(func(a, b): return a.s < b.s)
	return line


## The nearest point of the line to `p`: {at, s (distance along), d (how far off)}.
func _project(p: Vector2) -> Dictionary:
	var best := {"at": pts[0], "s": 0.0, "d": INF}
	for k in pts.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])
		var d := c.distance_to(p)
		if d < best.d:
			best = {"at": c, "s": cum[k] + pts[k].distance_to(c), "d": d}
	return best


static func _heading(chain: PackedVector2Array) -> Vector2:
	var k := chain.size() - 1
	while k > 0 and chain[k].distance_to(chain[k - 1]) < 0.01:
		k -= 1
	return (chain[k] - chain[maxi(k - 1, 0)]).normalized()


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / SNAP), roundi(p.y / SNAP))


static func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(p.size() - 1, -1, -1):
		out.append(p[k])
	return out
