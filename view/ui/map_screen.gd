## VIEW. The map (M): a flat 2D picture of the whole district drawn from the same data as the city. North is up
## (the world's -z), so what is higher on the map is further north. It shows streets and buildings, the street
## names, a few places you know of, where the tutorial wants you to go, an arrow for you, and the compass:
## N, E, S and W round the edge and a rose in the corner. Scroll to zoom, drag to pan, C to come back to you,
## M or Esc to close. It only reads the model; nothing in it changes the world.
class_name MapScreen
extends CanvasLayer

signal opened
signal closed

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.93, 0.9, 0.8)
const BUILDING := Color(0.74, 0.69, 0.6)
const MIN_SCALE := 0.12  # pixels per metre
const MAX_SCALE := 5.0
const START_SCALE := 1.6
const WINDS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const ROAD_COLORS := {"primary": Color(0.96, 0.78, 0.45), "secondary": Color(0.97, 0.86, 0.58), "tertiary": Color(0.98, 0.92, 0.72), "pedestrian": Color(0.84, 0.88, 0.76)}
const ROAD_DEFAULT := Color(0.98, 0.96, 0.9)

var world: World
var player: PlayerController
var objective: Callable  # () -> Vector2 or null: where the tutorial wants you to go
var landmarks: Array = []  # [{pos: Vector2, label: String, color: Color}]

var _district: Dictionary
var _roads: ArrayMesh
var _buildings: ArrayMesh
var _names: Array = []  # [{text, pos, major}]
var _root: Control
var _scale := START_SCALE
var _center := Vector2.ZERO
var _dragging := false
var _font: Font


func setup(district: Dictionary, w: World, p: PlayerController, objective_callable: Callable, marks: Array) -> MapScreen:
	_district = district
	world = w
	player = p
	objective = objective_callable
	landmarks = marks
	return self


func _ready() -> void:
	layer = 22
	visible = false
	_font = ThemeDB.fallback_font
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	_root.draw.connect(_draw_map)
	add_child(_root)


func open() -> void:
	if visible:
		return
	_build_meshes()
	_center = player.ground_pos()
	_scale = START_SCALE
	visible = true
	_root.queue_redraw()
	opened.emit()


func close() -> void:
	if visible:
		visible = false
		_dragging = false
		closed.emit()


## Where a point in the world falls on the screen.
func to_screen(pos: Vector2) -> Vector2:
	return (pos - _center) * _scale + _root.size * 0.5


## Which of the eight winds a world direction points to (north is -y, east is +x).
static func compass_name(dir: Vector2) -> String:
	if dir.length() < 0.0001:
		return "N"
	var angle := atan2(dir.x, -dir.y)  # 0 north, clockwise
	return WINDS[posmod(roundi(angle / (TAU / 8.0)), 8)]


## The direction the player faces in the world (x east, y south).
func facing() -> Vector2:
	return Vector2(-sin(player.rotation.y), -cos(player.rotation.y))


func _process(_delta: float) -> void:
	if visible:
		_root.queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("map"):
		close()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_C:
			_center = player.ground_pos()
		elif e.physical_keycode == KEY_EQUAL or e.physical_keycode == KEY_KP_ADD:
			_zoom(1.25, _root.size * 0.5)
		elif e.physical_keycode == KEY_MINUS or e.physical_keycode == KEY_KP_SUBTRACT:
			_zoom(0.8, _root.size * 0.5)


func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom(1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom(1.0 / 1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_center = player.ground_pos()
	elif e is InputEventMouseMotion and _dragging:
		_center -= e.relative / _scale


## Zooms by `factor` keeping the point under `at` (a screen position) where it is.
func _zoom(factor: float, at: Vector2) -> void:
	var before := (at - _root.size * 0.5) / _scale + _center
	_scale = clampf(_scale * factor, MIN_SCALE, MAX_SCALE)
	_center = before - (at - _root.size * 0.5) / _scale


# ---------------------------------------------------------------- drawing

func _build_meshes() -> void:
	if _roads != null:
		return
	var rv := PackedVector3Array()
	var rc := PackedColorArray()
	for r in _district.roads:
		var pts := PackedVector2Array()
		for k in range(0, r.pts.size(), 2):
			pts.append(Vector2(r.pts[k], r.pts[k + 1]))
		var col: Color = ROAD_COLORS.get(String(r["class"]), ROAD_DEFAULT)
		var half := clampf(float(r.w), 3.0, 12.0) * 0.5
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			if a.distance_to(b) < 0.1:
				continue
			var n := (b - a).normalized().orthogonal() * half
			for v in [a + n, a - n, b - n, a + n, b - n, b + n]:
				rv.append(Vector3(v.x, v.y, 0))
				rc.append(col)
		var name := String(r.name)
		if name != "" and pts.size() >= 2:
			_names.append({"text": name, "pos": pts[pts.size() / 2], "major": String(r["class"]) in ["primary", "secondary", "tertiary"], "n": pts.size()})
	_roads = _mesh(rv, rc)
	var bv := PackedVector3Array()
	var bc := PackedColorArray()
	for b in _district.buildings:
		var pts := PackedVector2Array()
		for k in range(0, b.poly.size(), 2):
			pts.append(Vector2(b.poly[k], b.poly[k + 1]))
		var tris := Geometry2D.triangulate_polygon(pts)
		var shade := 1.0 - float(absi(int(b.id)) % 7) * 0.012
		var col := BUILDING * shade
		col.a = 1.0
		for i in tris:
			bv.append(Vector3(pts[i].x, pts[i].y, 0))
			bc.append(col)
	_buildings = _mesh(bv, bc)
	# one label per street: its longest way (the others repeat it)
	var best := {}
	for n in _names:
		if not best.has(n.text) or n.n > best[n.text].n:
			best[n.text] = n
	_names = best.values()


func _mesh(verts: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = colors
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _draw_map() -> void:
	var size := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_root.draw_set_transform(size * 0.5 - _center * _scale, 0.0, Vector2(_scale, _scale))
	_root.draw_mesh(_roads, null)
	_root.draw_mesh(_buildings, null)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_street_names(size)
	for m in landmarks:
		_draw_landmark(m)
	_draw_objective(size)
	_draw_player()
	_draw_frame(size)


func _draw_street_names(size: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-30)
	for n in _names:
		if not (n.major and _scale > 0.3) and _scale < 1.0:
			continue
		var at := to_screen(n.pos)
		if rect.has_point(at):
			var w := _font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_root.draw_string(_font, at - Vector2(w * 0.5, -4), n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.75))


func _draw_landmark(m: Dictionary) -> void:
	var at := to_screen(m.pos)
	if not Rect2(Vector2.ZERO, _root.size).grow(20).has_point(at):
		return
	_root.draw_circle(at, 6.0, INK)
	_root.draw_circle(at, 4.5, m.color)
	if _scale >= 1.2:  # zoomed out, the market's places would sit on top of each other: dots only
		var w := _font.get_string_size(m.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_root.draw_rect(Rect2(at + Vector2(9, -10), Vector2(w + 6, 20)), Color(PAPER, 0.85))
		_root.draw_string(_font, at + Vector2(12, 5), m.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)


## A gold diamond where the tutorial wants you to go; if it is off the map, an arrow at the edge pointing to it.
func _draw_objective(size: Vector2) -> void:
	var target: Variant = objective.call() if objective.is_valid() else null
	if target == null:
		return
	var at := to_screen(target)
	var dist := int(player.ground_pos().distance_to(target))
	var inner := Rect2(Vector2.ZERO, size).grow(-36)
	var gold := Color(0.95, 0.72, 0.15)
	if inner.has_point(at):
		var d := PackedVector2Array([at + Vector2(0, -11), at + Vector2(9, 0), at + Vector2(0, 11), at + Vector2(-9, 0)])
		_root.draw_colored_polygon(d, gold)
		_root.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), INK, 2.0)
		_root.draw_string(_font, at + Vector2(14, 5), "%d m" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	else:
		var from := size * 0.5
		var dir := (at - from).normalized()
		var edge := from + dir * minf(size.x, size.y) * 0.42
		var tip := edge + dir * 14.0
		var side := dir.orthogonal() * 9.0
		_root.draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), gold)
		_root.draw_polyline(PackedVector2Array([tip, edge + side, edge - side, tip]), INK, 2.0)
		_root.draw_string(_font, edge - dir * 6.0 - Vector2(24, -18), "%d m" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)


## You: a red arrow pointing the way you face, with a white ring.
func _draw_player() -> void:
	var at := to_screen(player.ground_pos())
	var f := facing()
	var side := f.orthogonal()
	var pts := PackedVector2Array([at + f * 15.0, at - f * 9.0 + side * 9.0, at - f * 4.0, at - f * 9.0 - side * 9.0])
	_root.draw_circle(at, 13.0, Color(1, 1, 1, 0.55))
	_root.draw_colored_polygon(pts, Color(0.82, 0.16, 0.14))
	_root.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), INK, 2.0)


func _draw_frame(size: Vector2) -> void:
	_root.draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), INK, false, 3.0)
	# N, E, S, W round the edge
	for pair in [["N", Vector2(size.x * 0.5, 30)], ["S", Vector2(size.x * 0.5, size.y - 14)], ["W", Vector2(22, size.y * 0.5 + 8)], ["E", Vector2(size.x - 30, size.y * 0.5 + 8)]]:
		var tint := Color(0.75, 0.12, 0.12) if pair[0] == "N" else INK
		_root.draw_string(_font, pair[1] - Vector2(8, 0), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, tint)
	# the rose, top right: eight ticks and a north arrow
	var c := Vector2(size.x - 90, 100)
	_root.draw_circle(c, 52.0, Color(PAPER, 0.9))
	_root.draw_arc(c, 52.0, 0, TAU, 48, INK, 2.0)
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(sin(a), -cos(a))
		_root.draw_line(c + d * (38.0 if i % 2 == 0 else 44.0), c + d * 52.0, INK, 2.0)
	_root.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -40), c + Vector2(7, 0), c + Vector2(-7, 0)]), Color(0.75, 0.12, 0.12))
	_root.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 40), c + Vector2(7, 0), c + Vector2(-7, 0)]), INK)
	_root.draw_string(_font, c + Vector2(-6, -57), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.12, 0.12))
	# the title, the way you face, the scale and the keys
	_root.draw_rect(Rect2(Vector2(14, 14), Vector2(640, 42)), Color(PAPER, 0.92))
	_root.draw_string(_font, Vector2(26, 44), "Frankfurt, Bahnhofsviertel to the old town    ·    you are facing %s" % compass_name(facing()), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	var metres := 100.0
	for m in [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0]:
		metres = m
		if m * _scale >= 90.0:
			break
	var y := size.y - 44.0
	_root.draw_line(Vector2(30, y), Vector2(30 + metres * _scale, y), INK, 3.0)
	_root.draw_string(_font, Vector2(30, y - 8), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	_root.draw_rect(Rect2(Vector2(size.x - 580, size.y - 54), Vector2(560, 36)), Color(PAPER, 0.92))
	_root.draw_string(_font, Vector2(size.x - 560, size.y - 30), "scroll: zoom    drag: pan    C: back to you    M or Esc: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK, 0.75))
