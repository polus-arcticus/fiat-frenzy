## Fetches what the story's Frankfurt is re-made from, over the district file's bounds, from the public Overpass API
## (TileSource.OVERPASS) with the game's generic User-Agent and nothing about anyone, asked again with backoff while the server
## is busy. Two requests, each kept as it came:
##   district   data/raw/story_district_raw.json: every building and building part, every way you can walk or drive (footways and
##              squares too), covered things and subway entrances
##   tram       data/raw/tram11_raw.json: tram line 11's route relations, their ways' geometry and their stops
## (The land layer, with the tracks, is tools/story_land.gd.) Run it again only to refresh them.
##   godot --headless --path . --script tools/story_map.gd -- [district] [tram]
extends SceneTree

const DISTRICT_OUT := "res://data/raw/story_district_raw.json"
const TRAM_OUT := "res://data/raw/tram11_raw.json"
const MARGIN := 60.0  # metres round the bounds (TileSource.MARGIN)
const TIMEOUT := 180


func _initialize() -> void:
	_run()


func _run() -> void:
	var district: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenario.DISTRICT))
	var box := MapFrame.of_district(district, "story").overpass_box(MARGIN)
	var queries := {
		"district": [DISTRICT_OUT, "[out:json][timeout:%d];(way[\"building\"](%s);way[\"building:part\"](%s);relation[\"building\"](%s);way[\"highway\"](%s);relation[\"highway\"](%s);way[\"place\"=\"square\"](%s);relation[\"place\"=\"square\"](%s);way[\"covered\"](%s);way[\"man_made\"~\"^(canopy|monument)$\"](%s);node[\"railway\"=\"subway_entrance\"](%s);node[\"historic\"~\"^(monument|memorial)$\"](%s););out geom;" % [TIMEOUT, box, box, box, box, box, box, box, box, box, box, box]],
		"tram": [TRAM_OUT, "[out:json][timeout:%d];relation[\"route\"=\"tram\"][\"ref\"=\"11\"](%s);out geom;" % [TIMEOUT, box]],
	}
	var wanted: Array = OS.get_cmdline_user_args()
	if wanted.is_empty():
		wanted = queries.keys()
	var http := RetryingFetchController.new()
	http.timeout = TIMEOUT + 30.0
	root.add_child(http)
	await process_frame  # (in the tree before it can ask)
	var headers := PackedStringArray(["User-Agent: " + TileSource.AGENT, "Content-Type: application/x-www-form-urlencoded"])
	var failed := 0
	for name in wanted:
		var out: String = queries[name][0]
		print("asking %s for the %s in %s" % [TileSource.OVERPASS, name, box])
		var got: Dictionary = await http.fetch(TileSource.OVERPASS, headers, HTTPClient.METHOD_POST, "data=" + str(queries[name][1]).uri_encode())
		var text := (got.body as PackedByteArray).get_string_from_utf8()
		var parsed = JSON.parse_string(text) if got.ok else null
		if not (parsed is Dictionary and parsed.has("elements")):
			printerr("no answer for the %s (%s, code %d, %d attempts)" % [name, got.error, got.code, got.attempts])
			failed += 1
			continue
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("kept %d elements (%d KB) in %s" % [parsed.elements.size(), text.length() / 1024, out])
	quit(failed)
