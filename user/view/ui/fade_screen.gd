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


## Fades to `alpha` (1 is black) over `seconds`; returns when it is there.
func fade_to(alpha: float, seconds: float) -> void:
	if seconds <= 0.0:
		_rect.color.a = alpha
		await get_tree().process_frame
		return
	var t := create_tween()
	t.tween_property(_rect, "color:a", alpha, seconds)
	await t.finished


func alpha() -> float:
	return _rect.color.a
