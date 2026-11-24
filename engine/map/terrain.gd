## The planet's elevation, as Terrarium tiles have it (Mapzen's, on AWS: web-map PNGs at zoom 14, about 6 m a pixel at
## Frankfurt, each pixel's height in its colour: (R*256 + G + B/256) - 32768 metres above the sea). OpenStreetMap has no
## heights worth the name, so this is the second source the map is combined with. Only the reading of it is here: which tiles a
## map needs, where they are, and the height at a point (`sea_level`). The shape of a map's land made from it is Landform's.
class_name Terrain
extends RefCounted

const ZOOM := 14      # the Terrarium zoom a tile is read at
const PIXELS := 256   # a Terrarium tile's side


## Which Terrarium tiles cover `rect` of `frame` (`margin` metres wider): [Vector2i(x, y)], the ones to fetch.
static func tiles_for(frame: MapFrame, rect: Rect2, margin := 0.0) -> Array[Vector2i]:
	var r := rect.grow(margin)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var ll := frame.lat_lon(corner)
		var t := TileKey.web(ll[0], ll[1], ZOOM)
		lo = Vector2i(mini(lo.x, floori(t[0])), mini(lo.y, floori(t[1])))
		hi = Vector2i(maxi(hi.x, floori(t[0])), maxi(hi.y, floori(t[1])))
	var out: Array[Vector2i] = []
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, y))
	return out


## Where a tile is kept and asked for: its file name and the server's address.
static func file_name(t: Vector2i) -> String:
	return "relief_%d_%d_%d.png" % [ZOOM, t.x, t.y]


static func url(t: Vector2i) -> String:
	return "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % [ZOOM, t.x, t.y]


## Metres above the sea of a Terrarium pixel's colour.
static func decode(c: Color) -> float:
	return (c.r8 * 256.0 + c.g8 + c.b8 / 256.0) - 32768.0


## The inverse (for tests, and tools that make a tile): a colour for `metres`.
static func encode(metres: float) -> Color:
	var v := clampf(metres + 32768.0, 0.0, 65535.99)
	var r := floori(v / 256.0)
	var g := floori(v) - r * 256
	var b := floori((v - floorf(v)) * 256.0)
	return Color8(r, g, b)


## The Terrarium pictures among `tiles` ({Vector2i(x, y): PNG bytes}) that decode, as {Vector2i: Image}.
static func images(tiles: Dictionary) -> Dictionary:
	var imgs := {}
	for t in tiles:
		var img := Image.new()
		if img.load_png_from_buffer(tiles[t]) == OK and img.get_width() == PIXELS and img.get_height() == PIXELS:
			imgs[t] = img
	return imgs


## Metres above the sea at `p` (a point of `frame`), bilinear over the pixels of `imgs` (from `images`); NAN where no tile has
## it. A function of where `p` is on the planet only, so two maps that share ground get the same heights.
static func sea_level(frame: MapFrame, p: Vector2, imgs: Dictionary) -> float:
	var ll := frame.lat_lon(p)
	var w := TileKey.web(ll[0], ll[1], ZOOM)
	var px := w[0] * PIXELS - 0.5  # (a pixel's value is at its middle)
	var py := w[1] * PIXELS - 0.5
	var x0 := floori(px)
	var y0 := floori(py)
	var fx := px - x0
	var fy := py - y0
	var v := [0.0, 0.0, 0.0, 0.0]
	for k in 4:
		var c := _pixel(imgs, x0 + (k & 1), y0 + (k >> 1))
		if is_nan(c):
			return NAN
		v[k] = c
	return lerpf(lerpf(v[0], v[1], fx), lerpf(v[2], v[3], fx), fy)


# A pixel by its place on the whole zoom-14 grid (the next tile's pixel past a tile's edge), NAN where no tile has it.
static func _pixel(imgs: Dictionary, x: int, y: int) -> float:
	var t := Vector2i(floori(x / float(PIXELS)), floori(y / float(PIXELS)))
	if not imgs.has(t):
		return NAN
	var img: Image = imgs[t]
	return decode(img.get_pixel(x - t.x * PIXELS, y - t.y * PIXELS))
