## VIEW + CONTROLLER (a menu is both). New Game's first question, as in Planet Crafter: where do you land?
## - **Frankfurt: Bahnhofsviertel**, the story.
## - **Anywhere on Earth**: pick a place on the planet, a globe you turn and zoom (or, toggled, a flat map over the north pole),
##   with the game's tile grid over it (TileKey: everyone who picks a place in the same tile lands in the same tile, with the
##   same market, so their saves fit together). Click to choose, or type "lat, lon".
## It says which landing (`chosen`, a Landing spec) and the title screen starts it. The planet's pictures are OpenStreetMap's
## (MapTiles, fetched by MapTileFetchController and kept); the projection is PlanetProjection, drawn by planet.gdshader.
class_name LandingScreen
extends Control

signal chosen(spec: Dictionary)
signal back

const PANEL := 420.0
const STORY := Vector2(50.1086307, 8.6687641)  # the story's Frankfurt (its map's origin: tools/story_district.gd)
const STORY_K := 120000.0  # how close the planet comes to the story (its region about 500 px across)
const PICK_TILE_PX := 140.0  # how big a game tile is drawn when a typed place is flown to
const CLICK_SLOP := 5.0  # pixels a press may move and still be a click
const SHADER := preload("res://assets/shaders/planet.gdshader")
const INK := TitleScreen.INK
const CREAM := TitleScreen.CREAM
const GOLD := TitleScreen.GOLD
const PINK := TitleScreen.PINK
const GREEN := TitleScreen.GREEN

var proj := PlanetProjection.new()
var fetcher := MapTileFetchController.new()
var story := true            # the story, or a tile of the player's own
var pick := Vector2.INF      # the place chosen (lat, lon), for a tile
var hover := Vector2.INF     # the place under the pointer

var _planet: ColorRect
var _overlay: Control
var _mat := ShaderMaterial.new()
var _atlas := MapTiles.blank(8, MapTiles.SEA)
var _atlas_tex: ImageTexture
var _patch := MapTiles.blank(MapTiles.PATCH)
var _patch_tex: ImageTexture
var _patch_at := Vector3i(-1, 0, 0)  # (zoom, x, y) of the patch's north-west tile
var _dirty := {}                       # "atlas" / "patch" -> true: a picture to send to the shader
var _since_look := 0.0
var _goal := {}                        # {at, k}: where the view is flying
var _press := Vector2.INF              # where the left button went down
var _dragged := false
var _mapped: Array[String] = []

var _story_b: Button
var _tile_b: Button
var _where: LineEdit
var _info: Label
var _view_b: Button
var _go: Button
var _error: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # (anchors alone don't resize a control already in the tree)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fetcher)
	fetcher.arrived.connect(_on_arrived)
	_mapped = TileSource.mapped()
	_planet = ColorRect.new()
	_planet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_planet.offset_left = PANEL
	_planet.material = _mat
	_mat.shader = SHADER
	_planet.gui_input.connect(_on_planet_input)
	_planet.mouse_exited.connect(func(): hover = Vector2.INF)
	add_child(_planet)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = PANEL
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_build_panel()
	_load_atlas()
	proj.size = Vector2(maxf(size.x - PANEL, 400.0), maxf(size.y, 300.0))
	proj.k = proj.whole()
	proj.look_at(Vector2(STORY.x - 15.0, STORY.y))  # the whole planet, Europe facing
	_refresh()


## The title screen couldn't start the landing: say why, and let them pick again.
func failed(why: String) -> void:
	_error.text = why
	_error.show()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			back.emit()
			accept_event()


# ---------------------------------------------------------------- the panel

func _build_panel() -> void:
	var bg := ColorRect.new()
	bg.color = Color(INK, 0.94)
	bg.position = Vector2.ZERO
	bg.size = Vector2(PANEL, 4000)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.position = Vector2(28, 36)
	col.custom_minimum_size = Vector2(PANEL - 56, 0)
	col.size = Vector2(PANEL - 56, 0)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(_label("WHERE DO YOU LAND?", 30, GOLD))
	_story_b = _option(col, "Frankfurt · Bahnhofsviertel", "The story: the bank, the station, and a gun that prints money.", _choose_story)
	_tile_b = _option(col, "Anywhere on Earth", "A tile of your own: its streets from OpenStreetMap, a tent city and a market. No story yet.", _choose_tile_mode)
	_where = LineEdit.new()
	_where.placeholder_text = "lat, lon   (or click the map)"
	_where.custom_minimum_size = Vector2(0, 42)
	_where.add_theme_font_size_override("font_size", 18)
	_where.text_submitted.connect(_on_typed)
	col.add_child(_where)
	_info = _label("", 16, CREAM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(PANEL - 56, 150)
	col.add_child(_info)
	_view_b = _button(col, "Flat map (north pole)", _toggle_view, CREAM)
	_go = _button(col, "Begin the story", _on_go, GOLD)
	_button(col, "Back", func(): back.emit(), PINK)
	_error = _label("", 16, PINK)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.hide()
	col.add_child(_error)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(parent: Control, text: String, action: Callable, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	TitleScreen.style(b, accent)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## A landing to choose: a toggle with a line under it saying what it is.
func _option(parent: Control, title: String, says: String, action: Callable) -> Button:
	var b := _button(parent, title, action, GOLD)
	b.toggle_mode = true
	var l := _label(says, 15, Color(CREAM, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL - 56, 0)
	parent.add_child(l)
	return b


func _choose_story() -> void:
	story = true
	_refresh()
	_fly(STORY, STORY_K)


func _choose_tile_mode() -> void:
	story = false
	_refresh()
	if pick != Vector2.INF:
		_fly(pick, maxf(proj.k, _k_for_tile_px(PICK_TILE_PX, pick.x)))


## Chooses the place `at` (lat, lon) for a tile of one's own.
func choose(at: Vector2) -> void:
	pick = Vector2(clampf(at.x, -85.0, 85.0), wrapf(at.y, -180.0, 180.0))
	story = false
	_where.text = "%.5f, %.5f" % [pick.x, pick.y]
	_error.hide()
	_refresh()


## What starting now would land on (a Landing spec).
func spec() -> Dictionary:
	if story or pick == Vector2.INF:
		return {"kind": "story"}
	return {"kind": "tile", "key": TileKey.of(pick.x, pick.y), "lat": pick.x, "lon": pick.y}


func _refresh() -> void:
	_story_b.set_pressed_no_signal(story)
	_tile_b.set_pressed_no_signal(not story)
	_where.editable = true
	if story:
		_info.text = "Frankfurt am Main, the Bahnhofsviertel: the streets between the station and the bank.\n\nOr choose anywhere on Earth: click the map."
		_go.text = "Begin the story"
		_go.disabled = false
		return
	if pick == Vector2.INF:
		_info.text = "Click the map to choose where you land, or type a latitude and longitude.\n\nDrag to turn the planet; scroll to zoom in until the tile grid shows."
		_go.text = "Land here"
		_go.disabled = true
		return
	var key := TileKey.of(pick.x, pick.y)
	var region := TileKey.region_of(key)
	var lines := [
		"Tile %s  ·  about %d m across" % [key, roundi(TileKey.size_m(region))],
		"in region %s" % region,
		"",
		("Its map is here already." if TileSource.ready(key) else "Its streets and water come from OpenStreetMap when you land."),
		"Anyone who lands in this tile gets the same streets and the same market: your saves fit together.",
	]
	_info.text = "\n".join(lines)
	_go.text = "Land here"
	_go.disabled = false


func _on_typed(text: String) -> void:
	var at := parse_lat_lon(text)
	if at == Vector2.INF:
		_error.text = "That isn't a place: type a latitude and a longitude, like 50.1109, 8.6821."
		_error.show()
		return
	choose(at)
	_fly(at, _k_for_tile_px(PICK_TILE_PX, at.x))


## "50.11, 8.68", "50.11 8.68" or "50.11;8.68" as Vector2(lat, lon); Vector2.INF if it isn't one.
static func parse_lat_lon(text: String) -> Vector2:
	var parts := text.replace(";", " ").replace(",", " ").split(" ", false)
	if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return Vector2.INF
	var la := parts[0].to_float()
	var lo := parts[1].to_float()
	if absf(la) > 85.0 or absf(lo) > 180.0:
		return Vector2.INF
	return Vector2(la, lo)


func _toggle_view() -> void:
	_goal = {}
	proj.toggle()
	_view_b.text = "Globe" if proj.mode == PlanetProjection.Mode.FLAT else "Flat map (north pole)"


func _on_go() -> void:
	_error.hide()
	chosen.emit(spec())


# ---------------------------------------------------------------- the planet

func _on_planet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_goal = {}
			proj.zoom_at(mb.position, 1.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_goal = {}
			proj.zoom_at(mb.position, 1.0 / 1.2)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragged = false
			else:
				if not _dragged and _press != Vector2.INF:
					var at := proj.lat_lon_at(mb.position)
					if at != Vector2.INF:
						choose(at)
				_press = Vector2.INF
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		hover = proj.lat_lon_at(mm.position)
		if _press != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if _dragged or mm.position.distance_to(_press) > CLICK_SLOP:
				if not _dragged:
					_goal = {}
				_dragged = true
				proj.drag(mm.relative)


func _fly(at: Vector2, to_k: float) -> void:
	_goal = {"at": at, "k": clampf(to_k, proj.whole() * 0.8, proj.max_k())}


func _k_for_tile_px(px: float, at_lat: float) -> float:
	return px * float(1 << TileKey.ZOOM) / (TAU * cos(deg_to_rad(at_lat)))


func _process(delta: float) -> void:
	proj.size = _planet.size if _planet.size.x > 10.0 else proj.size
	if not _goal.is_empty():
		var f := 1.0 - exp(-delta * 4.0)
		var from := proj.middle()
		var to: Vector2 = _goal.at
		var d := Vector2(to.x - from.x, wrapf(to.y - from.y, -180.0, 180.0))
		proj.look_at(from + d * f if d.length() > 0.00001 else to)
		proj.k = exp(lerpf(log(proj.k), log(float(_goal.k)), f))
		if d.length() < 0.00001 and absf(log(proj.k / float(_goal.k))) < 0.002:
			_goal = {}
	_since_look += delta
	if _since_look > 0.2:
		_since_look = 0.0
		_look_for_tiles()
		_send_pictures()
	_feed_shader()
	_overlay.queue_redraw()


func _feed_shader() -> void:
	var mid := proj.middle()
	_mat.set_shader_parameter("view_size", proj.size)
	_mat.set_shader_parameter("k", proj.k)
	_mat.set_shader_parameter("flat_map", 1.0 if proj.mode == PlanetProjection.Mode.FLAT else 0.0)
	_mat.set_shader_parameter("middle", Vector2(deg_to_rad(proj.lat), deg_to_rad(proj.lon)))
	_mat.set_shader_parameter("pan", proj.pan)
	var t := MapTiles.tile_xy(mid.x, mid.y, TileKey.ZOOM)
	var anchor := Vector2i(floori(t[0]), floori(t[1]))
	_mat.set_shader_parameter("grid_anchor", MapTiles.anchor(TileKey.ZOOM, anchor.x, anchor.y))
	_mat.set_shader_parameter("chosen", _offset(pick, anchor) if not story else Vector2(1e9, 1e9))
	_mat.set_shader_parameter("hovered", _offset(hover, anchor))
	var on := _patch_at.x > MapTiles.ATLAS_ZOOM
	_mat.set_shader_parameter("patch_tiles", float(MapTiles.PATCH) if on else 0.0)
	if on:
		_mat.set_shader_parameter("patch_anchor", MapTiles.anchor(_patch_at.x, _patch_at.y, _patch_at.z))


# A place's game tile, in tiles from the anchor tile (far off when there's no place).
func _offset(at: Vector2, anchor: Vector2i) -> Vector2:
	if at == Vector2.INF:
		return Vector2(1e9, 1e9)
	var t := MapTiles.tile_xy(at.x, at.y, TileKey.ZOOM)
	return Vector2(floori(t[0]) - anchor.x, floori(t[1]) - anchor.y)


func _load_atlas() -> void:
	var z := MapTiles.ATLAS_ZOOM
	for y in 1 << z:
		for x in 1 << z:
			var img := MapTiles.picture(z, x, y, fetcher.dir)
			if img != null:
				MapTiles.lay(_atlas, img, x, y)
	_atlas.generate_mipmaps()
	_atlas_tex = ImageTexture.create_from_image(_atlas)
	_patch_tex = ImageTexture.create_from_image(_patch)
	_mat.set_shader_parameter("atlas", _atlas_tex)
	_mat.set_shader_parameter("atlas_px", float(_atlas.get_width()))
	_mat.set_shader_parameter("patch", _patch_tex)


## Every so often: the closer pictures the view wants (a patch round its middle at the zoom that shows streets), those in
## sight fetched first, nearest the middle first.
func _look_for_tiles() -> void:
	var z := proj.detail_zoom()
	if z <= MapTiles.ATLAS_ZOOM:
		_patch_at = Vector3i(-1, 0, 0)
		fetcher.want(_atlas_tiles())
		return
	var mid := proj.middle()
	var t := MapTiles.tile_xy(mid.x, mid.y, z)
	var origin := MapTiles.patch_origin(z, t[0], t[1])
	var at := Vector3i(z, origin.x, origin.y)
	if at != _patch_at:
		_patch_at = at
		_patch.fill(Color(0, 0, 0, 0))
		for y in MapTiles.PATCH:
			for x in MapTiles.PATCH:
				var img := MapTiles.picture(z, origin.x + x, origin.y + y, fetcher.dir)
				if img != null:
					MapTiles.lay(_patch, img, x, y)
		_dirty["patch"] = true
	fetcher.want(_in_sight(z, origin) + _atlas_tiles())


# Every tile of the atlas (the fetcher skips those it has).
func _atlas_tiles() -> Array[Vector3i]:
	var z := MapTiles.ATLAS_ZOOM
	var out: Array[Vector3i] = []
	for y in 1 << z:
		for x in 1 << z:
			out.append(Vector3i(z, x, y))
	return out


# The patch's tiles in sight, nearest the middle first.
func _in_sight(z: int, origin: Vector2i) -> Array[Vector3i]:
	var seen := {}
	var step := 48.0
	var y := 0.0
	while y <= proj.size.y:
		var x := 0.0
		while x <= proj.size.x:
			var px := Vector2(x, y)
			var at := proj.lat_lon_at(px)
			if at != Vector2.INF:
				var t := MapTiles.tile_xy(at.x, at.y, z)
				var c := Vector2i(floori(t[0]), floori(t[1])) - origin
				if c.x >= 0 and c.y >= 0 and c.x < MapTiles.PATCH and c.y < MapTiles.PATCH:
					var key := Vector3i(z, origin.x + c.x, origin.y + c.y)
					var d := px.distance_squared_to(proj.size * 0.5)
					seen[key] = minf(seen.get(key, INF), d)
			x += step
		y += step
	var out: Array[Vector3i] = []
	out.assign(seen.keys())
	out.sort_custom(func(a, b): return seen[a] < seen[b])
	return out


func _on_arrived(z: int, x: int, y: int) -> void:
	var img := MapTiles.picture(z, x, y, fetcher.dir)
	if img == null:
		return
	if z == MapTiles.ATLAS_ZOOM:
		MapTiles.lay(_atlas, img, x, y)
		_dirty["atlas"] = true
	elif z == _patch_at.x:
		var c := Vector2i(x - _patch_at.y, y - _patch_at.z)
		if c.x >= 0 and c.y >= 0 and c.x < MapTiles.PATCH and c.y < MapTiles.PATCH:
			MapTiles.lay(_patch, img, c.x, c.y)
			_dirty["patch"] = true


func _send_pictures() -> void:
	if _dirty.has("atlas"):
		_atlas.clear_mipmaps()
		_atlas.generate_mipmaps()
		_atlas_tex.update(_atlas)
	if _dirty.has("patch"):
		_patch_tex.update(_patch)
	_dirty.clear()


# ---------------------------------------------------------------- what's drawn over the planet

func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	for key in _mapped:  # tiles someone has landed in on this machine
		var m: Array = TileKey.middle(key)
		var p := proj.screen_of(m[0], m[1])
		if p != Vector2.INF:
			_overlay.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), GREEN)
			_overlay.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), INK, false, 1.5)
	var s := proj.screen_of(STORY.x, STORY.y)
	if s != Vector2.INF:
		_pin(s, GOLD, "THE STORY: FRANKFURT", story)
	if not story and pick != Vector2.INF:
		var p := proj.screen_of(pick.x, pick.y)
		if p != Vector2.INF:
			_pin(p, PINK, "YOU LAND HERE  ·  " + TileKey.of(pick.x, pick.y), true)
	if hover != Vector2.INF:
		var line := "%.4f, %.4f" % [hover.x, hover.y]
		if proj.tile_px(TileKey.ZOOM) > 6.0:
			line += "   ·   tile " + TileKey.of(hover.x, hover.y)
		_overlay.draw_string_outline(font, Vector2(16, 30), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, INK)
		_overlay.draw_string(font, Vector2(16, 30), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CREAM)
	var hint := "drag to turn  ·  scroll to zoom  ·  click to choose"
	if proj.tile_px(TileKey.ZOOM) <= 6.0:
		hint += "  ·  zoom in to see the tiles"
	var h := proj.size.y - 14.0
	_overlay.draw_string_outline(font, Vector2(16, h), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, INK)
	_overlay.draw_string(font, Vector2(16, h), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(CREAM, 0.85))
	var credit := MapTiles.ATTRIBUTION
	var w := font.get_string_size(credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_overlay.draw_rect(Rect2(proj.size.x - w - 16, proj.size.y - 26, w + 16, 26), Color(1, 1, 1, 0.75))
	_overlay.draw_string(font, Vector2(proj.size.x - w - 8, proj.size.y - 8), credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)


func _pin(at: Vector2, color: Color, text: String, loud: bool) -> void:
	var font := ThemeDB.fallback_font
	var head := at - Vector2(0, 26)
	_overlay.draw_line(at, head, INK, 4.0)
	_overlay.draw_line(at, head, color, 2.0)
	_overlay.draw_circle(head, 9.0, INK)
	_overlay.draw_circle(head, 7.0, color)
	if loud:
		_overlay.draw_string_outline(font, head + Vector2(14, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, INK)
		_overlay.draw_string(font, head + Vector2(14, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
