## The pictures the new-game screen paints its planet with: OpenStreetMap's standard map tiles (web-map tiles, 256 px), each
## fetched once from tile.openstreetmap.org and kept in user://maptiles (MapTileFetchController fetches them). Two pictures:
## - **the atlas**: the whole world at zoom ATLAS_ZOOM, 8 x 8 tiles, always there;
## - **a patch**: PATCH x PATCH tiles at a closer zoom round the middle of the view, for looking at streets.
## The map is © OpenStreetMap contributors; the screen says so (ATTRIBUTION).
class_name MapTiles
extends RefCounted

const URL := "https://tile.openstreetmap.org/%d/%d/%d.png"
const CACHE := "user://maptiles"
const AGENT := "FiatFrenzy/0.1 (game; new-game map)"
const ATTRIBUTION := "Map © OpenStreetMap contributors"
const TILE := 256
const ATLAS_ZOOM := 3
const PATCH := 8
const SEA := Color("#aad3df")  # OpenStreetMap's own water, where a picture hasn't come yet


static func url(z: int, x: int, y: int) -> String:
	return URL % [z, x, y]


static func path(z: int, x: int, y: int, dir := CACHE) -> String:
	return dir.path_join("%d_%d_%d.png" % [z, x, y])


static func cached(z: int, x: int, y: int, dir := CACHE) -> bool:
	return FileAccess.file_exists(path(z, x, y, dir))


## A cached tile's picture (null if there isn't one, or it won't read).
static func picture(z: int, x: int, y: int, dir := CACHE) -> Image:
	if not cached(z, x, y, dir):
		return null
	var img := Image.load_from_file(path(z, x, y, dir))
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Keeps a fetched tile. False if it is not a PNG picture.
static func store(z: int, x: int, y: int, png: PackedByteArray, dir := CACHE) -> bool:
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(z, x, y, dir), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(png)
	return true


## A blank picture `tiles` tiles across, to lay tiles into (see lay): `fill`, or clear (the shader falls back where clear).
static func blank(tiles: int, fill := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create_empty(tiles * TILE, tiles * TILE, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


## Lays a tile's picture into `into` at tile column `cx`, row `cy`.
static func lay(into: Image, tile: Image, cx: int, cy: int) -> void:
	into.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(cx * TILE, cy * TILE))


## The web-map tile of `zoom` that holds a place, as fractional (x, y), in 64-bit floats ([x, y]).
static func tile_xy(at_lat: float, at_lon: float, zoom: int) -> Array[float]:
	return TileKey._tile_coords(at_lat, at_lon, zoom)


## Where a web-map tile's north-west corner is, as the shader wants it: [longitude (radians), Mercator ψ (radians), tiles per
## radian]. The shader measures from it, so its 32-bit floats stay small and sharp even at zoom 16 (see planet.gdshader).
static func anchor(zoom: int, x: int, y: int) -> Vector3:
	var n := float(1 << zoom)
	return Vector3(x / n * TAU - PI, PI - y / n * TAU, n / TAU)


## The patch's first tile (its north-west) for a view whose middle is in tile (fx, fy) of `zoom`: the middle tile about the
## middle of the patch, kept inside the map.
static func patch_origin(zoom: int, fx: float, fy: float) -> Vector2i:
	var n := 1 << zoom
	var hi := maxi(n - PATCH, 0)
	return Vector2i(clampi(floori(fx) - PATCH / 2, 0, hi), clampi(floori(fy) - PATCH / 2, 0, hi))
