## VIEW (helpers). The HUD's paper-and-ink style, and the small builders every panel uses: a panel, a label, a bar.
class_name Ui
extends RefCounted

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.97, 0.94, 0.86, 0.92)
const BAR_COLORS := {"cash": Color(0.32, 0.74, 0.36), "level": Color(0.32, 0.74, 0.36), "hunger": Color(0.85, 0.55, 0.25), "thirst": Color(0.3, 0.6, 0.85), "warmth": Color(0.9, 0.35, 0.25), "rep": Color(0.45, 0.7, 0.4)}


## A paper panel with a vertical box inside it (`panel.get_child(0)`), anchored by `preset` and pushed in by `offset`.
static func panel(parent: Control, preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	parent.add_child(p)
	p.set_anchors_preset(preset)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if offset.x < 0 or preset == Control.PRESET_CENTER_BOTTOM else Control.GROW_DIRECTION_END
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN if offset.y < 0 else Control.GROW_DIRECTION_END
	p.offset_left = offset.x
	p.offset_right = offset.x
	p.offset_top = offset.y
	p.offset_bottom = offset.y
	return p


## A label in ink. Added to `parent` (inside its box, if it is a panel); `parent` may be null to add it yourself.
static func label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		var target: Node = parent.get_child(0) if parent is PanelContainer else parent
		target.add_child(l)
	return l


## The "level" row: its name and a LevelBar (two layers: how many levels, and how far through this one).
static func level_row(parent: Node) -> LevelBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var l := label(row, "level", 14)
	l.custom_minimum_size.x = 64
	var b := LevelBar.new()
	row.add_child(b)
	return b


## A named bar: a label and a progress bar filled to `value` (0..100).
static func bar(parent: Node, title: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var l := label(row, title, 14)
	l.custom_minimum_size.x = 64
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(190, 14)
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.15)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(b)
	return b


## A row of bars by name: "level" gets the two-layer bar, the rest ordinary ones. Returns {name: bar}.
static func bars(parent: Node, names: Array) -> Dictionary:
	var out := {}
	for k in names:
		out[k] = level_row(parent) if k == "level" else bar(parent, k, BAR_COLORS[k])
	return out
