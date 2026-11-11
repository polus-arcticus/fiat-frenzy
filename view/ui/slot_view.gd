## VIEW. One inventory slot: an item icon, a stack count, and a caption under it (a price, or a
## have/capacity). Right-click emits `right_clicked`. An empty slot is just a dim square.
class_name SlotView
extends PanelContainer

signal right_clicked

const INK := Color(0.16, 0.14, 0.2)
const SIZE := Vector2(76, 86)


## `item` empty = an empty slot. `tone` tints the border: "" normal, "good", "bad", "warn".
func setup(item: String, count: int, caption := "", hint := "", tone := "") -> SlotView:
	custom_minimum_size = SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.07) if item == "" else Color(1, 0.99, 0.94, 0.95)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = {"good": Color(0.35, 0.65, 0.35), "bad": Color(0.8, 0.3, 0.25), "warn": Color(0.85, 0.65, 0.2)}.get(tone, Color(INK, 0.35 if item != "" else 0.15))
	sb.set_content_margin_all(3)
	add_theme_stylebox_override("panel", sb)
	tooltip_text = hint
	if item == "":
		return self
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var overlay := Control.new()
	overlay.custom_minimum_size = Vector2(0, 54)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(overlay)
	var icon := ItemIcon.new(item, 54.0)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2(-27, -27) + Vector2(0, 0)
	overlay.add_child(icon)
	if count > 0:
		var n := Label.new()
		n.text = str(count)
		n.add_theme_font_size_override("font_size", 17)
		n.add_theme_color_override("font_color", INK)
		n.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		n.add_theme_constant_override("outline_size", 5)
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.position = Vector2(-18, -22)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(n)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", INK)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cap)
	return self


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()  # before the emit: the handler rebuilds the slots and frees this one
		right_clicked.emit()
