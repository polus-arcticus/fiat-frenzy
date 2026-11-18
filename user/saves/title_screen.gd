## VIEW + CONTROLLER (a menu is both). The welcome screen: the game's name over a drifting shower of bills, and what to do
## about it: Continue (the newest save), New Game, Load Game (every slot, with how far it got) and Quit. It never touches the
## game: it only says which slot to start (see Launch), and the loading cinematic does the rest.
class_name TitleScreen
extends Control

const INK := Color("#120d1f")
const CREAM := Color("#fff2cf")
const GOLD := Color("#ffcf3a")
const PINK := Color("#ff4f81")
const GREEN := Color("#58c26a")

var _saves: Array[Dictionary] = []
var _menu: VBoxContainer
var _bills: Array[Dictionary] = []
var _t := 0.0
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		_bills.append({"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(30.0, 90.0), "rot": rng.randf() * TAU,
			"spin": rng.randf_range(-1.2, 1.2), "size": rng.randf_range(0.7, 1.7), "sway": rng.randf() * TAU})
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.offset_top = 90
	_menu.offset_bottom = 90
	add_child(_menu)
	_show_main()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	for i in 20:  # the dusk, in bands
		var f := float(i) / 20.0
		draw_rect(Rect2(0, f * s.y, s.x, s.y / 20.0 + 1.0), Color("#1b1236").lerp(Color("#8e2f5c"), pow(f, 1.8)))
	for b in _bills:
		var y := fposmod(b.y * s.y + _t * b.speed, s.y + 80.0) - 40.0
		var x: float = b.x * s.x + sin(_t * 0.8 + b.sway) * 36.0
		var r: float = b.rot + _t * b.spin
		var k: float = b.size
		draw_set_transform(Vector2(x, y), r, Vector2(k, k * (0.35 + 0.65 * absf(cos(r * 0.9)))))
		draw_rect(Rect2(-22, -11, 44, 22), Color(GREEN, 0.55))
		draw_rect(Rect2(-22, -11, 44, 22), Color(INK, 0.6), false, 2.0)
		draw_circle(Vector2.ZERO, 6.0, Color(INK, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	var cx := s.x * 0.5
	draw_set_transform(Vector2(cx, s.y * 0.2), -0.04, Vector2.ONE)
	draw_string(font, Vector2(-316, 8), "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 104, INK)
	draw_string_outline(font, Vector2(-322, 0), "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 104, 14, INK)
	draw_string(font, Vector2(-322, 0), "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 104, CREAM)
	draw_string(font, Vector2(-250, 50), "A  GAME  ABOUT  MONEY", HORIZONTAL_ALIGNMENT_LEFT, 600, 28, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the menus

func _clear() -> void:
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()


func _button(text: String, action: Callable, accent := CREAM) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(INK, 0.85) if state == "normal" else Color(accent, 0.95) if state != "focus" else Color(INK, 0.85)
		sb.set_border_width_all(3)
		sb.border_color = accent
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.pressed.connect(action)
	_menu.add_child(b)
	return b


func _show_main() -> void:
	_clear()
	_saves = SaveStore.list()
	var first: Button = null
	if not _saves.is_empty():
		var newest: Dictionary = _saves[0]
		first = _button("Continue   ·   %s" % _describe(newest), func(): _start(newest.slot), GOLD)
	var fresh := _button("New Game", func(): _start(""))
	if first == null:
		first = fresh
	var load_b := _button("Load Game", _show_saves)
	load_b.disabled = _saves.is_empty()
	_button("Quit", func(): get_tree().quit(), PINK)
	first.grab_focus()


func _show_saves() -> void:
	_clear()
	_saves = SaveStore.list()
	for entry in _saves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_menu.add_child(row)
		var slot: String = entry.slot
		var go := Button.new()
		go.text = "%s   ·   %s" % [_slot_name(slot), _describe(entry)]
		go.custom_minimum_size = Vector2(500, 50)
		go.add_theme_font_size_override("font_size", 20)
		go.pressed.connect(func(): _start(slot))
		row.add_child(go)
		var del := Button.new()
		del.text = "Delete"
		del.custom_minimum_size = Vector2(90, 50)
		del.pressed.connect(func():
			SaveStore.delete(slot)
			_show_saves())
		row.add_child(del)
	_button("Back", _show_main, PINK)


## "Day 3  ·  $42.50  ·  saved 2 minutes ago"
func _describe(entry: Dictionary) -> String:
	var sm: Dictionary = entry.summary
	return "Day %d  ·  $%.2f  ·  %s" % [int(sm.get("day", 1)), float(sm.get("cash", 0.0)), _ago(float(entry.saved_at))]


func _slot_name(slot: String) -> String:
	return {"autosave": "Autosave", "quicksave": "Quicksave", "manual": "Saved game"}.get(slot, SaveStore.CHAPTERS.get(slot, slot))


func _ago(then: float) -> String:
	var secs := int(Time.get_unix_time_from_system() - then)
	if secs < 90:
		return "just now"
	if secs < 5400:
		return "%d min ago" % (secs / 60)
	if secs < 129600:
		return "%d h ago" % (secs / 3600)
	return "%d days ago" % (secs / 86400)


func _start(slot: String) -> void:
	if _busy:
		return
	_busy = true
	Launch.skip_intro = false
	Launch.begin(get_tree(), slot)
