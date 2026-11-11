## VIEW. A small pictogram for an item, drawn in code in the same flat, paper-and-ink style as the HUD:
## a loaf, a hot dog, a cup, a flour sack, a bottle and so on.
class_name ItemIcon
extends Control

const INK := Color(0.16, 0.14, 0.2)

var item := ""


func _init(item_id := "", px := 48.0) -> void:
	item = item_id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	match item:
		"bread":
			_blob(o, s, Vector2(0.5, 0.58), Vector2(0.4, 0.24), Color(0.80, 0.56, 0.28))
			for k in 3:
				_line(o, s, Vector2(0.32 + k * 0.17, 0.42), Vector2(0.4 + k * 0.17, 0.62), Color(0.62, 0.4, 0.18), 2.5)
		"hot_dog":
			_blob(o, s, Vector2(0.5, 0.58), Vector2(0.44, 0.2), Color(0.9, 0.74, 0.46))
			_blob(o, s, Vector2(0.5, 0.52), Vector2(0.46, 0.1), Color(0.78, 0.28, 0.2))
			_line(o, s, Vector2(0.28, 0.46), Vector2(0.7, 0.5), Color(0.95, 0.8, 0.2), 2.0)
		"lemonade":
			var cup := PackedVector2Array([o + Vector2(0.26, 0.24) * s, o + Vector2(0.74, 0.24) * s, o + Vector2(0.66, 0.84) * s, o + Vector2(0.34, 0.84) * s])
			draw_colored_polygon(cup, Color(0.98, 0.9, 0.35))
			draw_polyline(PackedVector2Array([cup[0], cup[1], cup[2], cup[3], cup[0]]), INK, 2.0)
			_line(o, s, Vector2(0.58, 0.1), Vector2(0.5, 0.5), Color(0.85, 0.3, 0.3), 3.0)
		"bed":
			var tent := PackedVector2Array([o + Vector2(0.1, 0.8) * s, o + Vector2(0.5, 0.2) * s, o + Vector2(0.9, 0.8) * s])
			draw_colored_polygon(tent, Color(0.42, 0.55, 0.78))
			draw_polyline(PackedVector2Array([tent[0], tent[1], tent[2], tent[0]]), INK, 2.0)
		"bicycle":
			for cx in [0.28, 0.72]:
				draw_arc(o + Vector2(cx, 0.66) * s, 0.17 * s, 0, TAU, 20, INK, 2.2)
			_line(o, s, Vector2(0.28, 0.66), Vector2(0.48, 0.4), Color(0.86, 0.24, 0.2), 2.5)
			_line(o, s, Vector2(0.48, 0.4), Vector2(0.72, 0.66), Color(0.86, 0.24, 0.2), 2.5)
			_line(o, s, Vector2(0.48, 0.4), Vector2(0.62, 0.38), Color(0.86, 0.24, 0.2), 2.5)
			_line(o, s, Vector2(0.62, 0.38), Vector2(0.72, 0.66), INK, 2.0)
			_line(o, s, Vector2(0.58, 0.3), Vector2(0.68, 0.3), INK, 2.5)
		"skateboard":
			var deck := PackedVector2Array([o + Vector2(0.1, 0.5) * s, o + Vector2(0.22, 0.42) * s, o + Vector2(0.78, 0.42) * s, o + Vector2(0.9, 0.5) * s, o + Vector2(0.78, 0.56) * s, o + Vector2(0.22, 0.56) * s])
			draw_colored_polygon(deck, Color(0.9, 0.55, 0.2))
			draw_polyline(PackedVector2Array([deck[0], deck[1], deck[2], deck[3], deck[4], deck[5], deck[0]]), INK, 2.0)
			for wx in [0.3, 0.7]:
				draw_circle(o + Vector2(wx, 0.68) * s, 0.07 * s, Color(0.95, 0.95, 0.9))
				draw_arc(o + Vector2(wx, 0.68) * s, 0.07 * s, 0, TAU, 12, INK, 1.6)
		"flour":
			_blob(o, s, Vector2(0.5, 0.6), Vector2(0.3, 0.3), Color(0.96, 0.94, 0.88))
			draw_rect(Rect2(o + Vector2(0.4, 0.18) * s, Vector2(0.2, 0.14) * s), Color(0.96, 0.94, 0.88))
			_line(o, s, Vector2(0.38, 0.32), Vector2(0.62, 0.32), Color(0.75, 0.3, 0.3), 3.0)
		"protein":
			_blob(o, s, Vector2(0.5, 0.55), Vector2(0.38, 0.26), Color(0.92, 0.55, 0.55))
			_blob(o, s, Vector2(0.4, 0.5), Vector2(0.1, 0.08), Color(0.98, 0.78, 0.76))
		"bottled_water":
			draw_rect(Rect2(o + Vector2(0.34, 0.3) * s, Vector2(0.32, 0.56) * s), Color(0.6, 0.82, 0.96))
			draw_rect(Rect2(o + Vector2(0.43, 0.14) * s, Vector2(0.14, 0.18) * s), Color(0.6, 0.82, 0.96))
			draw_rect(Rect2(o + Vector2(0.42, 0.1) * s, Vector2(0.16, 0.06) * s), Color(0.2, 0.4, 0.8))
		"sugar":
			for c in [Vector2(0.28, 0.5), Vector2(0.52, 0.5), Vector2(0.4, 0.28)]:
				draw_rect(Rect2(o + c * s, Vector2(0.22, 0.22) * s), Color(0.98, 0.98, 0.96))
				draw_rect(Rect2(o + c * s, Vector2(0.22, 0.22) * s), INK, false, 1.5)
		"letter":
			draw_rect(Rect2(o + Vector2(0.14, 0.28) * s, Vector2(0.72, 0.46) * s), Color(0.97, 0.94, 0.86))
			draw_rect(Rect2(o + Vector2(0.14, 0.28) * s, Vector2(0.72, 0.46) * s), INK, false, 2.0)
			_line(o, s, Vector2(0.14, 0.28), Vector2(0.5, 0.54), INK, 2.0)
			_line(o, s, Vector2(0.86, 0.28), Vector2(0.5, 0.54), INK, 2.0)
			_blob(o, s, Vector2(0.5, 0.56), Vector2(0.06, 0.05), Color(0.78, 0.1, 0.12))
		"scrap":
			var junk := PackedVector2Array([o + Vector2(0.15, 0.7) * s, o + Vector2(0.3, 0.25) * s, o + Vector2(0.62, 0.38) * s, o + Vector2(0.85, 0.72) * s])
			draw_colored_polygon(junk, Color(0.55, 0.55, 0.6))
		_:
			draw_rect(Rect2(o + Vector2(0.2, 0.2) * s, Vector2(0.6, 0.6) * s), Color(0.7, 0.7, 0.7))
			draw_string(ThemeDB.fallback_font, o + Vector2(0.3, 0.62) * s, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.5), INK)


func _blob(o: Vector2, s: float, centre: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		pts.append(o + (centre + Vector2(cos(a) * radii.x, sin(a) * radii.y)) * s)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0)


func _line(o: Vector2, s: float, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(o + a * s, o + b * s, color, width)
