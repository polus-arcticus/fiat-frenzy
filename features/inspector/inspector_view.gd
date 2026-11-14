## VIEW. The inspector's screen: a panel at the right with what the inspector says about the drone you picked, a ring
## round them, and lines along where they are going (white: the route they are walking; cyan: the stand they will stand at;
## yellow: the thing they are after).
class_name InspectorView
extends CanvasLayer

var _panel: PanelContainer
var _label: Label
var _hint: Label
var _lines: MeshInstance3D
var _mesh := ImmediateMesh.new()


func setup(world_root: Node) -> InspectorView:
	name = "InspectorView"
	layer = 5
	_panel = PanelContainer.new()
	_panel.offset_left = 14.0
	_panel.offset_top = 320.0
	_panel.add_theme_stylebox_override("panel", _backing())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	add_child(_panel)
	var hint_box := PanelContainer.new()
	hint_box.anchor_left = 0.5
	hint_box.anchor_right = 0.5
	hint_box.offset_left = -400.0
	hint_box.offset_right = 400.0
	hint_box.offset_top = 8.0
	hint_box.add_theme_stylebox_override("panel", _backing())
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_box)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.text = "INSPECTOR  WASD fly · Q/E down/up · Shift fast · right-drag look · click someone · N/P next · G go to · F3 leave"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.add_child(_hint)
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.extra_cull_margin = 16384.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	_lines.material_override = mat
	world_root.add_child(_lines)
	show_it(false)
	return self


static func _backing() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	return s


func show_it(on: bool) -> void:
	visible = on
	_lines.visible = on
	if not on:
		_mesh.clear_surfaces()


func show_text(lines: PackedStringArray) -> void:
	_label.text = "\n".join(lines) if not lines.is_empty() else "Click someone to inspect them."
	_panel.visible = true


## Draws the picked drone's ring and what they are heading for. Positions are on the ground, (x, z) in the world.
func draw(drone: Drone) -> void:
	_mesh.clear_surfaces()
	if drone == null:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_ring(_at(drone.pos, 0.05), 0.9, Color(1, 0.3, 0.2))
	_line(_at(drone.pos, 0.0), _at(drone.pos, 7.0), Color(1, 0.3, 0.2))
	var at := _at(drone.pos, 0.3)
	for p in drone.route:
		_line(at, _at(p, 0.3), Color.WHITE)
		at = _at(p, 0.3)
	var stand: Vector2 = drone.job.get("stand", Vector2.INF)
	if stand.is_finite():
		_line(_at(drone.pos, 0.6), _at(stand, 0.6), Color(0.2, 0.9, 1.0))
		_ring(_at(stand, 0.05), 0.5, Color(0.2, 0.9, 1.0))
		_line(_at(stand, 0.0), _at(stand, 7.0), Color(0.2, 0.9, 1.0))
	var target = drone.job.get("target")
	if target != null and "pos" in target:
		_line(_at(drone.pos, 0.9), _at(target.pos, 0.9), Color(1, 0.9, 0.2))
		_ring(_at(target.pos, 0.05), 0.7, Color(1, 0.9, 0.2))
		_line(_at(target.pos, 0.0), _at(target.pos, 7.0), Color(1, 0.9, 0.2))
	_mesh.surface_end()


static func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


func _ring(centre: Vector3, radius: float, c: Color) -> void:
	for k in 24:
		var a0 := TAU * k / 24.0
		var a1 := TAU * (k + 1) / 24.0
		_line(centre + Vector3(cos(a0), 0, sin(a0)) * radius, centre + Vector3(cos(a1), 0, sin(a1)) * radius, c)
