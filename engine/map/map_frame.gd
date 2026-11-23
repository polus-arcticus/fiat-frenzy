## Where a map's metres are: how a point on the planet becomes a Vector2 in it, the square it owns (what is cut to it), and the
## name its dice are seeded with. Two kinds:
## - a **tile** (`tile`): region metres (TileKey.local), owning the tile's square: what every landing uses, so neighbours line up;
## - **around an origin** (`around`): metres east and south of a fixed point, flat (x = Δlon · 111320 · cos lat₀, y = -Δlat ·
##   110574), owning a box. The story's Frankfurt is in these (tools/osm_to_district.py made it so), so its land layer is
##   brought into the same metres as its buildings and streets.
## The importers (OsmWater, OsmDressing, StreetThings) take a frame; their `tile` functions are the tile frame's shorthand.
class_name MapFrame
extends RefCounted

const KX_EQUATOR := 111320.0
const KZ := 110574.0

var key := ""        # the dice's name (a tile's key; the story's "story")
var rect := Rect2()  # the square or box it owns, in its own metres
var region := ""     # a tile's region ("" around an origin)
var lat0 := 0.0
var lon0 := 0.0
var kx := 0.0


static func tile(tile_key: String) -> MapFrame:
	var f := MapFrame.new()
	f.key = tile_key
	f.region = TileKey.region_of(tile_key)
	f.rect = TileKey.rect(tile_key)
	return f


## Metres around (`lat`, `lon`), owning `box`, its dice named `name`.
static func around(lat: float, lon: float, box: Rect2, name: String) -> MapFrame:
	var f := MapFrame.new()
	f.key = name
	f.lat0 = lat
	f.lon0 = lon
	f.kx = KX_EQUATOR * cos(deg_to_rad(lat))
	f.rect = box
	return f


## The frame of a district file made by tools/osm_to_district.py: around its origin, owning its bounds.
static func of_district(district: Dictionary, name: String) -> MapFrame:
	var b: Array = district.bounds
	return around(float(district.origin.lat), float(district.origin.lon), Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1]), name)


## A point on the planet, in this frame's metres.
func local(lat: float, lon: float) -> Vector2:
	if region != "":
		return TileKey.local(lat, lon, region)
	return Vector2((lon - lon0) * kx, -(lat - lat0) * KZ)


## Back to [lat, lon].
func lat_lon(p: Vector2) -> Array:
	if region != "":
		return TileKey.lat_lon(p, region)
	return [lat0 - p.y / KZ, lon0 + p.x / kx]


## The Overpass bounding box of what it owns, `margin` metres round: "south,west,north,east".
func overpass_box(margin := 0.0) -> String:
	var r := rect.grow(margin)
	var nw := lat_lon(r.position)
	var se := lat_lon(r.end)
	return "%.6f,%.6f,%.6f,%.6f" % [se[0], nw[1], nw[0], se[1]]
