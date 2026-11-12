## VIEW. The level bar, in two layers: a thin dark-green strip on top that grows a notch every time you level up
## (so it shows how many levels there are behind you), and the ordinary light-green bar underneath that fills toward
## the next one and starts again from empty each time it dings. Set `level` and `value` (0..100, how far through the level).
class_name LevelBar
extends Control

const DARK := Color(0.12, 0.42, 0.22)
const LIGHT := Color(0.32, 0.74, 0.36)
const BACK := Color(0.16, 0.14, 0.2, 0.15)

var level := 1:
	set(v):
		level = v
		queue_redraw()
## How many notches the dark strip has room for: the levels there are (for a level bar), or Wealth.MAX_TIER (for money).
var steps := Growth.MAX_LEVEL - 1:
	set(v):
		steps = v
		queue_redraw()
var value := 0.0:
	set(v):
		value = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(190, 18)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var tier := clampf(float(level - 1) / float(maxi(steps, 1)), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, 6), BACK)
	draw_rect(Rect2(0, 0, w * tier, 6), DARK)
	draw_rect(Rect2(0, 8, w, 10), BACK)
	draw_rect(Rect2(0, 8, w * clampf(value / 100.0, 0.0, 1.0), 10), LIGHT)
