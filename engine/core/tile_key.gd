## Where a patch of the planet is: the grid every save shares, so two players' maps fit together. A **tile** is a web-map tile
## at zoom 16 (about 600 m across at the equator, 390 m at Frankfurt), named "16/x/y"; it is a zone of the sim. A **region** is
## the zoom-10 tile that holds it (64 x 64 tiles, about 25 km at Frankfurt), named "10/x/y"; positions in the sim are metres
## from its north-west corner (x east, y south), so a float32 Vector2 stays good to a few millimetres anywhere in it.
##
## Inside a region every tile is the same square, so neighbours line up exactly. (The map is scaled at the region's middle
## latitude: across 25 km that is off by well under 1%, which nobody walking can see.) Regions meet only through gates.
class_name TileKey
extends RefCounted

const ZOOM := 16
const REGION_ZOOM := 10
const PER_REGION := 64  # tiles along each side of a region (2^(16-10))
const EARTH := 40075016.686  # metres round the equator


## The tile that holds a point on the planet.
static func of(lat: float, lon: float) -> String:
	var t := _tile_coords(lat, lon, ZOOM)
	return key(floori(t[0]), floori(t[1]))


static func key(x: int, y: int) -> String:
	return "%d/%d/%d" % [ZOOM, x, y]


## x and y of a tile (or region) key.
static func parse(k: String) -> Vector2i:
	var p := k.split("/")
	assert(p.size() == 3, "not a tile key: %s" % k)
	return Vector2i(int(p[1]), int(p[2]))


static func is_tile(zone: String) -> bool:
	return zone.begins_with("%d/" % ZOOM) and zone.count("/") == 2


## The region a tile is in.
static func region_of(k: String) -> String:
	var t := parse(k)
	return "%d/%d/%d" % [REGION_ZOOM, t.x / PER_REGION, t.y / PER_REGION]


## How many metres across a tile of `region` is.
static func size_m(region: String) -> float:
	var r := parse(region)
	var mid_lat := _lat_of((r.y + 0.5) / float(1 << REGION_ZOOM))
	return EARTH * cos(deg_to_rad(mid_lat)) / float(1 << ZOOM)


## A point on the planet, in metres from the north-west corner of `region`.
static func local(lat: float, lon: float, region: String) -> Vector2:
	var t := _tile_coords(lat, lon, ZOOM)
	var r := parse(region)
	var s := size_m(region)
	return Vector2((t[0] - r.x * PER_REGION) * s, (t[1] - r.y * PER_REGION) * s)


## Back from metres in `region` to [lat, lon].
static func lat_lon(p: Vector2, region: String) -> Array:
	var r := parse(region)
	var n := float(1 << ZOOM)
	var tx := p.x / size_m(region) + r.x * PER_REGION
	var ty := p.y / size_m(region) + r.y * PER_REGION
	return [_lat_of(ty / n), tx / n * 360.0 - 180.0]


## The square a tile covers, in its region's metres.
static func rect(k: String) -> Rect2:
	var t := parse(k)
	var r := parse(region_of(k))
	var s := size_m(region_of(k))
	return Rect2(Vector2(t - r * PER_REGION) * s, Vector2(s, s))


## The tile of `region` that holds the point `p` (metres in that region).
static func at(region: String, p: Vector2) -> String:
	var r := parse(region)
	var s := size_m(region)
	return key(r.x * PER_REGION + floori(p.x / s), r.y * PER_REGION + floori(p.y / s))


## The four tiles that share an edge with `k`, in the same region (across a region's edge is a gate, not a border).
static func neighbours(k: String) -> Array[String]:
	var t := parse(k)
	var out: Array[String] = []
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := key(t.x + step.x, t.y + step.y)
		if region_of(n) == region_of(k):
			out.append(n)
	return out


## Where tiles `a` and `b` meet: the middle of their shared edge, in region metres (INF if they do not share one).
static func border_point(a: String, b: String) -> Vector2:
	if not b in neighbours(a):
		return Vector2(INF, INF)
	var ra := rect(a)
	var rb := rect(b)
	return (ra.get_center() + rb.get_center()) * 0.5


# Fractional web-map tile coordinates at `zoom`, as [x, y] in 64-bit floats (a Vector2's 32 bits would lose metres out here).
static func _tile_coords(lat: float, lon: float, zoom: int) -> Array[float]:
	var n := float(1 << zoom)
	var la := deg_to_rad(clampf(lat, -85.05112878, 85.05112878))
	var x := (lon + 180.0) / 360.0 * n
	var y := (1.0 - log(tan(la) + 1.0 / cos(la)) / PI) / 2.0 * n
	return [x, y]


# The latitude of a fraction `f` (0 at the top) of the way down the web map.
static func _lat_of(f: float) -> float:
	return rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * f))))
