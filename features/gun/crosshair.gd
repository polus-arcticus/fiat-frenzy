## VIEW (HUD part). The crosshair, and the ring round it that fills while a contract charges, with what it would be worth.
class_name Crosshair
extends RefCounted

var label: Label

var _dot: Control
var _ring: Control
var _fraction := 0.0


func build(root: Control) -> void:
	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func():
		_dot.draw_circle(Vector2.ZERO, 3.5, Color(1, 0.98, 0.9, 0.95))
		_dot.draw_arc(Vector2.ZERO, 8.0, 0, TAU, 24, Ui.INK, 1.6))
	root.add_child(_dot)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	root.add_child(_ring)
	label = Ui.label(_ring, "", 22)  # under the ring (the ring's Control sits at the screen's centre)
	label.position = Vector2(-90, 36)
	label.size = Vector2(180, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _draw_ring() -> void:
	if _fraction <= 0.0:
		return
	_ring.draw_arc(Vector2.ZERO, 24.0, 0, TAU, 40, Color(0.16, 0.14, 0.2, 0.35), 5.0)
	var ready := _fraction >= GunController.MIN_CHARGE
	var col := Color(0.95, 0.78, 0.25) if _fraction >= 0.999 else (Color(0.4, 0.78, 0.45) if ready else Color(0.7, 0.7, 0.72))
	_ring.draw_arc(Vector2.ZERO, 24.0, -PI / 2.0, -PI / 2.0 + TAU * _fraction, 48, col, 5.0)


## The charge ring and its dollar amount (nothing while `fraction` is 0).
func show_charge(fraction: float, value: float) -> void:
	_fraction = fraction
	_ring.queue_redraw()
	label.text = "" if fraction <= 0.0 else ("$%d contract" % roundi(value) if fraction >= GunController.MIN_CHARGE else "keep holding...")
