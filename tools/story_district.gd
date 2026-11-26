## Makes the story's district file (its buildings, streets and tram routes, data/bahnhofsviertel.json) from the extracts
## tools/story_map.gd and tools/story_land.gd fetched, by the game's own importer (OsmImport.area), in the story's frame: metres round a fixed origin,
## x east and y south, so that growing the map never moves anything already in it. Offline.
##   godot --headless --path . --script tools/story_district.gd
extends SceneTree

const RAW := "res://data/raw/story_district_raw.json"
const TRAM := "res://data/raw/tram11_raw.json"
const ORIGIN := [50.1086307, 8.6687641]  # (the middle of the first station extract: pinned)
## The square the story's city covers: buildings with their middle in it, and the streets that come near it (the extract holds
## whole ways that run far past it).
const RECT := Rect2(-603.9, -909.5, 3560.1, 1324.5)


func _initialize() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAW))
	var frame := MapFrame.around(ORIGIN[0], ORIGIN[1], Rect2(), "story")
	var d := OsmImport.area(raw, frame.local, RECT)
	d["origin"] = {"lat": ORIGIN[0], "lon": ORIGIN[1]}
	var tram: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRAM))
	var land: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenario.LAND))  # (the stops' names)
	d["routes"] = OsmRoute.of(tram, land, frame.local, RECT)
	for b in d.buildings:  # (a colour is kept as its HTML string, which JSON can hold; numbers to a decimetre)
		_plain(b)
		for p in b.get("parts", []):
			_plain(p)
	for r in d.roads:
		r.pts = _snapped(r.pts)
	for s in d.squares:
		s.poly = _snapped(s.poly)
	var f := FileAccess.open(Scenario.DISTRICT, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var with_parts: Array = d.buildings.filter(func(b): return b.has("parts"))
	print("buildings %d (%d in parts), roads %d, bounds %s" % [d.buildings.size(), with_parts.size(), d.roads.size(), d.bounds])
	quit()


func _plain(b: Dictionary) -> void:
	if b.has("colour"):
		b["colour"] = "#" + (b.colour as Color).to_html(false)
	b.poly = _snapped(b.poly)


func _snapped(flat: Array) -> Array:
	return flat.map(func(v): return snappedf(float(v), 0.1))
