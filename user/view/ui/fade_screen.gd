## VIEW. Fades the whole screen to black and back, for jumps in place and time (the bus ride).
class_name FadeScreen
extends CanvasLayer

var _rect: ColorRect


func _ready() -> void:
	layer = 40
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func alpha() -> float:
	return _rect.color.a
