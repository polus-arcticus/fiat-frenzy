## OpenStreetMap to a district's railways: the tracks of trains, light rail and trams, and the stations they stop at, from the
## tile's "land" layer (TileSource) or the story's (tools/story_land.gd). Only looked at and ridden (RailBuilder; a train runs
## along them on a Line); the sim doesn't walk round them. Each track is cut to the square the frame owns and REACH past it, as the water
## is, so two tiles that share a track both draw it and the pieces meet.
##
## What is left out, for now: tunnels (underground), and bridges and viaducts raised above the ground (layer 1 and over): the
## ground has no decks yet to carry them (see the terrain plan), so a track that goes up simply stops where it leaves the ground.
## - `tracks`: [{id, kind, pts: PackedVector2Array}], `kind` one of KINDS;
## - `stops`: [{at: Vector2, name, kind}], the stations and halts (a tram's stop is a street thing: StreetThings, "tram_stop").
class_name OsmRail
extends RefCounted

## The Overpass filters for the tracks (TileSource asks for ways of each, whole: a track is long and is cut here) and the stops
## (nodes).
const WAYS := ["[\"railway\"~\"^(rail|light_rail|tram|narrow_gauge)$\"]"]
const NODES := ["[\"railway\"~\"^(station|halt)$\"]"]
## How high the top of a rail is over the ground it lies on, in metres: a rail on its sleepers, and a tram's flush in the street
## (RailBuilder draws the steel there; a skateboard grinds along it: Kerbs.grindable).
const HEAD := 0.14
const STREET_HEAD := 0.04
## By kind of track: the width of its bed (the ballast, sleepers and all), its gauge (rail to rail, centre to centre), whether it is
## laid in the street (a tram's is: flush, no bed) and how high its rails' tops are (`head`).
const KINDS := {
	"rail": {"bed": 4.4, "gauge": 1.435, "street": false, "head": HEAD},
	"light_rail": {"bed": 3.8, "gauge": 1.435, "street": false, "head": HEAD},
	"narrow_gauge": {"bed": 2.8, "gauge": 1.0, "street": false, "head": HEAD},
	"tram": {"bed": 0.0, "gauge": 1.435, "street": true, "head": STREET_HEAD},
}
## Tracks that are not for passengers' trains: yards and sidings are drawn, but a train does not run on them.
const SERVICE := ["yard", "siding", "spur", "crossover"]
const REACH := 60.0   # metres past the frame's square the tracks go (as the streets and the water do)
const MIN_LENGTH := 6.0  # a piece of track shorter than this is dropped


static func tile(overpass: Dictionary, tile_key: String) -> Dictionary:
	return of(overpass, MapFrame.tile(tile_key))


## The railways of a raw answer in any frame (MapFrame).
static func of(overpass: Dictionary, frame: MapFrame) -> Dictionary:
	var rect := frame.rect.grow(REACH)
	var tracks: Array = []
	var stops: Array = []
	var seen := {}
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var kind := str(tags.get("railway", ""))
		if e.get("type", "") == "node" and e.has("lat") and kind in ["station", "halt"]:
			var at := frame.local(float(e.lat), float(e.lon))
			if rect.has_point(at) and not seen.has(e.get("id", 0)):
				seen[e.get("id", 0)] = true
				stops.append({"at": at, "name": str(tags.get("name", "")), "kind": kind})
		elif e.get("type", "") == "way" and KINDS.has(kind) and _drawn(tags):
			var pts := OsmDressing.points(e.get("geometry", []), frame)
			for piece in _clip(pts, rect):
				tracks.append({"id": int(e.get("id", 0)), "kind": kind, "pts": piece,
					"service": str(tags.get("service", "")) in SERVICE})
	return {"tracks": tracks, "stops": stops}


## Is this track one we draw: above ground at ground level, not in a tunnel, not out of use?
static func _drawn(tags: Dictionary) -> bool:
	if str(tags.get("tunnel", "no")) not in ["no", ""]:
		return false
	if str(tags.get("bridge", "no")) not in ["no", ""] and int(str(tags.get("layer", "1"))) >= 1:
		return false  # (a viaduct or a bridge over something: up in the air, where nothing carries it yet)
	return not tags.has("disused") and not tags.has("abandoned")


## The runs of `pts` inside `rect`, each with the point that leaves it at each end (so the track reaches the edge and a train's
## path carries on past it), and none shorter than MIN_LENGTH.
static func _clip(pts: PackedVector2Array, rect: Rect2) -> Array:
	var out: Array = []
	var run := PackedVector2Array()
	for k in pts.size():
		if rect.has_point(pts[k]):
			if run.is_empty() and k > 0:
				run.append(pts[k - 1])
			run.append(pts[k])
		elif not run.is_empty():
			run.append(pts[k])
			out.append(run)
			run = PackedVector2Array()
	if not run.is_empty():
		out.append(run)
	return out.filter(func(r): return _length(r) >= MIN_LENGTH)


static func _length(pts: PackedVector2Array) -> float:
	var n := 0.0
	for k in pts.size() - 1:
		n += pts[k].distance_to(pts[k + 1])
	return n
