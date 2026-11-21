## Where a tile's map comes from: the cache in user://tiles (the raw OpenStreetMap answer, kept as it came, so the tile is
## fetched once and is the same every time after), or else one request to the public Overpass API (TileFetchController
## makes it). It asks for the tile's
## buildings and the kinds of street the game draws, with a margin round the tile (for the streets that cross its edge and the
## pavements measured to the buildings over the road). Nothing about the player goes with the request.
class_name TileSource
extends RefCounted

const CACHE := "user://tiles"
const OVERPASS := "https://overpass-api.de/api/interpreter"
const MARGIN := 60.0  # metres round the tile that are asked for too (OsmImport.STREET_REACH)
const TIMEOUT := 90   # seconds the server may take
const AGENT := "FiatFrenzy/0.1 (game; tile import)"


## The cached raw answer's file for `key`.
static func path(key: String, dir := CACHE) -> String:
	return dir.path_join(key.replace("/", "_") + ".osm.json")


static func cached(key: String, dir := CACHE) -> bool:
	return FileAccess.file_exists(path(key, dir))


## Keeps a raw answer for `key`. False if it is not an Overpass answer.
static func store(key: String, raw: String, dir := CACHE) -> bool:
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary and parsed.has("elements")):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(key, dir), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(raw)
	return true


## Every tile whose map is in the cache (someone has landed there on this machine), as keys.
static func mapped(dir := CACHE) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".osm.json"):
			var k := f.trim_suffix(".osm.json").replace("_", "/")
			if TileKey.is_tile(k):
				out.append(k)
	return out


## The tile's district from the cache ({} if it is not there).
static func district(key: String, dir := CACHE) -> Dictionary:
	if not cached(key, dir):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path(key, dir)))
	return OsmImport.tile(parsed, key) if parsed is Dictionary else {}


## The Overpass query for `key`: its buildings and drawn streets, in its box and the margin round it.
static func query(key: String) -> String:
	var region := TileKey.region_of(key)
	var r := TileKey.rect(key).grow(MARGIN)
	var nw: Array = TileKey.lat_lon(r.position, region)
	var se: Array = TileKey.lat_lon(r.end, region)
	var box := "%.6f,%.6f,%.6f,%.6f" % [se[0], nw[1], nw[0], se[1]]  # (south, west, north, east)
	var kinds := "|".join(OsmImport.ROAD_WIDTH.keys())
	return "[out:json][timeout:%d];(way[\"building\"](%s);way[\"highway\"~\"^(%s)$\"](%s););out geom;" % [TIMEOUT, box, kinds, box]
