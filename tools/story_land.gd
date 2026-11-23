## Fetches the story's Frankfurt's "land" layer (its water, green and street furniture: TileSource.land_query) for the whole of
## the district file's bounds, in one request to the public Overpass API (TileSource.OVERPASS), with the game's generic
## User-Agent and nothing else about anyone, asked again with backoff while the server is busy. The raw answer is kept as it
## came in data/raw/story_land.json, beside the extracts the district was made from; Scenario.load_district brings it into the
## district's metres (MapFrame.of_district) every time the story is built. Run it again only to refresh it.
##   godot --headless --path . --script tools/story_land.gd
extends SceneTree

const OUT := "res://data/raw/story_land.json"
const MARGIN := 60.0  # metres round the bounds (TileSource.MARGIN)
const TIMEOUT := 180  # seconds the server may take: it is about thirty tiles' worth


func _initialize() -> void:
	_run()


func _run() -> void:
	var district: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenario.DISTRICT))
	var frame := MapFrame.of_district(district, "story")
	var box := frame.overpass_box(MARGIN)
	print("asking %s for the land in %s" % [TileSource.OVERPASS, box])
	var http := RetryingFetchController.new()
	http.timeout = TIMEOUT + 30.0
	root.add_child(http)
	await process_frame  # (in the tree before it can ask)
	var headers := PackedStringArray(["User-Agent: " + TileSource.AGENT, "Content-Type: application/x-www-form-urlencoded"])
	var body := "data=" + TileSource.land_query(box, TIMEOUT).uri_encode()
	var got: Dictionary = await http.fetch(TileSource.OVERPASS, headers, HTTPClient.METHOD_POST, body)
	var text := (got.body as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text) if got.ok else null
	if not (parsed is Dictionary and parsed.has("elements")):
		printerr("no answer (%s, code %d, %d attempts)" % [got.error, got.code, got.attempts])
		quit(1)
		return
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("kept %d elements (%d KB) in %s" % [parsed.elements.size(), text.length() / 1024, OUT])
	quit()
