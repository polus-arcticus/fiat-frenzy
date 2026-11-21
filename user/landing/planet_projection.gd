## Where the new-game screen's planet is looked at from, and the one rule from a pixel to a place and back. Two ways to see it:
## - **GLOBE**: the Earth as a ball, seen from far off (orthographic), turned so `lat`, `lon` is in the middle.
## - **FLAT**: an azimuthal equidistant map over the north pole (the pole in the middle, every latitude a ring at its true
##   distance from it, the south pole the rim), panned so the plane point `pan` is in the middle.
## The planet shader (assets/shaders/planet.gdshader) draws with the same formulas; this is the copy the clicks are read
## with, and the tests check. Angles are in degrees out here, radians in the shader.
class_name PlanetProjection
extends RefCounted

enum Mode { GLOBE, FLAT }

const MAX_TILE_PX := 1400.0  # how far in: a game tile (TileKey.ZOOM) at most this many pixels across
const DETAIL_PX := 256.0     # a map picture's tiles are fetched at the zoom that shows them at least this big

var mode := Mode.GLOBE
var size := Vector2(1300, 750)  # the view, in pixels
var lat := 50.0                 # GLOBE: the place in the middle
var lon := 8.0
var pan := Vector2.ZERO         # FLAT: the plane point in the middle (the rim is 1 from the pole)
var k := 300.0                  # pixels per radian of latitude, in the middle (the globe's radius, in pixels)


## The scale that shows the whole planet.
func whole() -> float:
	return minf(size.x, size.y) * (0.42 if mode == Mode.GLOBE else 0.47 / PI)


func max_k() -> float:
	return MAX_TILE_PX * float(1 << TileKey.ZOOM) / TAU


## The place in the middle of the view, [lat, lon].
func middle() -> Vector2:
	return Vector2(lat, lon) if mode == Mode.GLOBE else _from_plane(pan)


## The place under pixel `px` as Vector2(lat, lon), or Vector2.INF off the planet.
func lat_lon_at(px: Vector2) -> Vector2:
	var d := px - size * 0.5
	if mode == Mode.FLAT:
		var q := d / (k * PI) + pan
		return Vector2.INF if q.length() > 1.0 else _from_plane(q)
	var u := d.x / k
	var v := -d.y / k
	var r2 := u * u + v * v
	if r2 > 1.0:
		return Vector2.INF
	var f := _frame()
	var p: Vector3 = f[0] * sqrt(1.0 - r2) + f[1] * u + f[2] * v
	return Vector2(rad_to_deg(atan2(p.y, Vector2(p.x, p.z).length())), rad_to_deg(atan2(p.z, p.x)))


## Where a place is on the screen, or Vector2.INF if it is out of sight (the globe's far side).
func screen_of(at_lat: float, at_lon: float) -> Vector2:
	if mode == Mode.FLAT:
		return size * 0.5 + (plane_of(at_lat, at_lon) - pan) * k * PI
	var f := _frame()
	var p := _vec(at_lat, at_lon)
	if p.dot(f[0]) < 0.0:
		return Vector2.INF
	return size * 0.5 + Vector2(p.dot(f[1]), -p.dot(f[2])) * k


## A place on the flat map's plane (the pole at 0, the equator a ring of 0.5, the south pole the rim; 0° east is down).
static func plane_of(at_lat: float, at_lon: float) -> Vector2:
	var r := (90.0 - at_lat) / 180.0
	var l := deg_to_rad(at_lon)
	return Vector2(sin(l), cos(l)) * r


## Moves the view with the mouse: the planet follows the pointer.
func drag(by: Vector2) -> void:
	if mode == Mode.FLAT:
		pan -= by / (k * PI)
		pan = pan.limit_length(1.0)
		return
	lat = clampf(lat + rad_to_deg(by.y / k), -85.0, 85.0)
	lon = wrapf(lon - rad_to_deg(by.x / (k * maxf(cos(deg_to_rad(lat)), 0.05))), -180.0, 180.0)


## Zooms by `factor` keeping the place under `px` where it is (as near as the globe allows).
func zoom_at(px: Vector2, factor: float) -> void:
	var before := lat_lon_at(px)
	k = clampf(k * factor, whole() * 0.8, max_k())
	if before == Vector2.INF:
		return
	for i in 3:  # (the globe bends: a few steps put the place back under the pointer)
		var now := lat_lon_at(px)
		if now == Vector2.INF:
			return
		if mode == Mode.FLAT:
			pan += plane_of(before.x, before.y) - plane_of(now.x, now.y)
		else:
			lat = clampf(lat + before.x - now.x, -85.0, 85.0)
			lon = wrapf(lon + wrapf(before.y - now.y, -180.0, 180.0), -180.0, 180.0)


## Puts `at` (lat, lon) in the middle.
func look_at(at: Vector2) -> void:
	if mode == Mode.FLAT:
		pan = plane_of(at.x, at.y)
	else:
		lat = clampf(at.x, -85.0, 85.0)
		lon = at.y


## Switches between globe and flat map, keeping the same place in the middle at the same scale; from as far out as the whole
## planet, to the whole of the other (the flat map's whole is the disc, the pole in the middle).
func toggle() -> void:
	var at := middle()
	var far := k <= whole() * 1.05
	mode = Mode.FLAT if mode == Mode.GLOBE else Mode.GLOBE
	look_at(at)
	if far or k < whole():
		k = whole()
		if mode == Mode.FLAT:
			pan = Vector2.ZERO


## How many pixels a web-map tile of `zoom` is across, in the middle.
func tile_px(zoom: int) -> float:
	return TAU * cos(deg_to_rad(middle().x)) * k / float(1 << zoom)


## The web-map zoom whose map pictures show at least DETAIL_PX across in the middle.
func detail_zoom() -> int:
	var z := 0
	while z < 18 and tile_px(z + 1) >= DETAIL_PX:
		z += 1
	return z


# The globe's frame for the place in the middle: [toward the viewer, east, north].
func _frame() -> Array[Vector3]:
	var p := deg_to_rad(lat)
	var l := deg_to_rad(lon)
	return [_vec(lat, lon), Vector3(-sin(l), 0.0, cos(l)), Vector3(-sin(p) * cos(l), cos(p), -sin(p) * sin(l))]


static func _vec(at_lat: float, at_lon: float) -> Vector3:
	var p := deg_to_rad(at_lat)
	var l := deg_to_rad(at_lon)
	return Vector3(cos(p) * cos(l), sin(p), cos(p) * sin(l))


static func _from_plane(q: Vector2) -> Vector2:
	return Vector2(90.0 - q.length() * 180.0, rad_to_deg(atan2(q.x, q.y)))
