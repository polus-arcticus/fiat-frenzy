## Where a tile's map comes from: the cache in user://tiles (the raw OpenStreetMap answers, kept as they came, so a tile is
## fetched once and is the same every time after), or else the public Overpass API (TileFetchController asks, with backoff).
## Nothing about the player goes with a request. Two layers, both before anyone lands (the sim uses both):
## - **"osm"**: the tile's buildings and the kinds of street the game draws, with a margin round the tile for the streets that
##   cross its edge and the pavements measured to the buildings over the road.
## - **"land"**: what the ground is, besides streets and buildings: its water (lakes, ponds, river areas and waterways:
##   OsmWater, solid), its green (parks, grass, woods: OsmDressing, where camps go and trees grow), and its street furniture
##   (lamps, stops, signs, bike stands, benches, bins, recycling, hedges and walls: StreetThings). Areas are cut to the
##   tile's box by the server (`out geom(box)`); a waterway's centre line comes whole (a way is a few km), so its band reaches
##   the tile's edge. Trees aren't asked for (a tile can have thousands of mapped ones): they are scattered in the green, the
##   same for everyone.
## At most two requests per tile to Overpass, ever, and one to four for its relief (shared with its neighbours).
class_name TileSource
extends RefCounted

const CACHE := "user://tiles"
const OVERPASS := "https://overpass-api.de/api/interpreter"
const MARGIN := 60.0  # metres round the tile that are asked for too (OsmImport.STREET_REACH)
const TIMEOUT := 90   # seconds the server may take
const AGENT := "FiatFrenzy/0.1 (game; tile import)"


## Which version of a layer's query the cache holds: when a layer asks for more (the land's street furniture, say), its number
## goes up, and a tile cached with the older answer fetches it once more, the next time anyone lands there.
const VERSIONS := {"land": 4}  # (3: drinking fountains, for the town's water; 4: railways and stations: OsmRail)


## The cached raw answer's file for `key` and `layer` ("osm" or "land").
static func path(key: String, dir := CACHE, layer := "osm") -> String:
	var v := str(VERSIONS[layer]) if VERSIONS.has(layer) else ""
	return dir.path_join(key.replace("/", "_") + "." + layer + v + ".json")


static func cached(key: String, dir := CACHE, layer := "osm") -> bool:
	return FileAccess.file_exists(path(key, dir, layer))


## Keeps a raw answer for `key`'s `layer`. False if it is not an Overpass answer.
static func store(key: String, raw: String, dir := CACHE, layer := "osm") -> bool:
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary and parsed.has("elements")):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(key, dir, layer), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(raw)
	return true


## Every tile whose map is in the cache (someone has landed there on this machine), as keys.
static func mapped(dir := CACHE) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".osm.json"):
			var k := f.trim_suffix(".osm.json").replace("_", "/")
			if TileKey.is_tile(k):
				out.append(k)
	return out


## The layers a tile needs before anyone lands on it (TileFetchController fetches them, Launch waits).
const BEFORE_LANDING := ["osm", "land"]


## **Relief** is a third source, apart from the two layers: the Terrarium elevation PNGs (Terrain) over the tile and RELIEF_REACH
## metres round it, one to four of them (1.5 km each), kept as they came in the same cache, and shared by every tile they cover.
## A tile needs it before anyone lands (`ready`), as it needs its map: the shape of its land (Landform) decides where its market
## and camp go, and that must be the same for everyone who lands there.
const RELIEF_REACH := 300.0  # metres round the tile that the terrain covers (its streets reach 60, the picture beyond them)


## The square of `key`'s metres that its terrain covers.
static func relief_rect(key: String) -> Rect2:
	return TileKey.rect(key).grow(RELIEF_REACH)


## The relief tiles `key` needs.
static func relief_needed(key: String) -> Array[Vector2i]:
	return Terrain.tiles_for(MapFrame.tile(key), TileKey.rect(key), RELIEF_REACH)


static func relief_path(t: Vector2i, dir := CACHE) -> String:
	return dir.path_join(Terrain.file_name(t))


## The relief tiles of `key` that are not in the cache yet.
static func relief_missing(key: String, dir := CACHE) -> Array[Vector2i]:
	return relief_needed(key).filter(func(t): return not FileAccess.file_exists(relief_path(t, dir)))


## Keeps a relief tile as it came. False if it is not a Terrarium picture (a 256 px PNG).
static func store_relief(t: Vector2i, bytes: PackedByteArray, dir := CACHE) -> bool:
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK or img.get_width() != Terrain.PIXELS or img.get_height() != Terrain.PIXELS:
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(relief_path(t, dir), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	return true


## The landform of `key` (its `district`, from `district`): the land's shape from its cached relief and the city on it. Flat
## unless all its relief is there (a save from before the hills; a fetch cut short): never half made up, so it is the same for
## everyone who has it.
static func landform(key: String, district: Dictionary, dir := CACHE) -> Landform:
	var tiles := {}
	for t in relief_needed(key):
		var file := relief_path(t, dir)
		if not FileAccess.file_exists(file):
			tiles = {}
			break
		tiles[t] = FileAccess.get_file_as_bytes(file)
	return Landform.of(MapFrame.tile(key), relief_rect(key).grow(-Landform.INSET), district, Terrain.images(tiles))


## Whether everything needed to land on `key` is in the cache: its layers and its relief.
static func ready(key: String, dir := CACHE) -> bool:
	return BEFORE_LANDING.all(func(l): return cached(key, dir, l)) and relief_missing(key, dir).is_empty()


## The tile's district from the cache ({} if it is not there), with its water (OsmWater) and its green (OsmDressing: the parks
## and their trees) when its land is cached.
static func district(key: String, dir := CACHE) -> Dictionary:
	var raw := raw_of(key, dir)
	if raw.is_empty():
		return {}
	var d := OsmImport.tile(raw, key)
	if cached(key, dir, "land"):
		var land := raw_of(key, dir, "land")
		d["water"] = OsmWater.tile(land, key, d)
		d["green"] = OsmDressing.tile(land, key, d)
		d["street"] = StreetThings.points(land, key)  # (its lamps, stops, signs, benches, recycling, hedges: StreetThings)
		d["rail"] = OsmRail.tile(land, key)           # (its tracks and stations: OsmRail)
	return d


## A layer's raw answer from the cache ({} if it hasn't come).
static func raw_of(key: String, dir := CACHE, layer := "osm") -> Dictionary:
	var file := path(key, dir, layer)
	if not FileAccess.file_exists(file):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
	return parsed if parsed is Dictionary else {}


## The query for a layer of `key`.
static func query(key: String, layer := "osm") -> String:
	var box := _box(key)
	if layer == "land":
		return land_query(box)
	var kinds := "|".join(OsmImport.ROAD_WIDTH.keys())
	return "[out:json][timeout:%d];(way[\"building\"](%s);way[\"highway\"~\"^(%s)$\"](%s););out geom;" % [TIMEOUT, box, kinds, box]


## The "land" query for an Overpass box ("south,west,north,east"): a tile's, or the story's whole map (tools/story_land.gd).
static func land_query(box: String, timeout := TIMEOUT) -> String:
	var areas := _areas(OsmWater.AREAS + OsmDressing.AREAS, box)
	for f in StreetThings.NODES:  # (the street's furniture: points, and a few lines)
		areas += "node%s(%s);" % [f, box]
	for f in StreetThings.LINES:
		areas += "way%s(%s);" % [f, box]
	for f in OsmRail.NODES:  # (stations and halts)
		areas += "node%s(%s);" % [f, box]
	var ways := "way[\"waterway\"~\"^(%s)$\"](%s);" % ["|".join(OsmWater.RIVER_WIDTH.keys()), box]
	for f in OsmRail.WAYS:  # (a track whole too: OsmRail cuts it to the tile)
		ways += "way%s(%s);" % [f, box]
	# (the areas cut to the box; a waterway's centre line whole, so its band reaches the tile's edge: a way is a few km)
	return "[out:json][timeout:%d];(%s);out geom(%s);%sout geom;" % [timeout, areas, box, ways]


static func _areas(filters: Array, box: String) -> String:
	var parts := PackedStringArray()
	for f in filters:
		parts.append("way%s(%s);relation%s(%s);" % [f, box, f, box])
	return "".join(parts)


static func _box(key: String) -> String:
	var region := TileKey.region_of(key)
	var r := TileKey.rect(key).grow(MARGIN)
	var nw: Array = TileKey.lat_lon(r.position, region)
	var se: Array = TileKey.lat_lon(r.end, region)
	return "%.6f,%.6f,%.6f,%.6f" % [se[0], nw[1], nw[0], se[1]]  # (south, west, north, east)
