## VIEW. The 2D overlay. It is a layer that holds a few parts and the odd line of text, and a single place the
## controllers talk to: the player panel (clock, money, gun mode, your bars), the card for whoever you aim at, the
## crosshair and its charge ring, and the loose lines (objective, controls hint, prompt, caption, news feed). It only
## displays what it is told.
class_name Hud
extends CanvasLayer

var player_panel := PlayerPanel.new()
var card := TargetCard.new()
var crosshair := Crosshair.new()

var _objective: Label
var _hint: Label
var _prompt: Label
var _caption: Label
var _caption_tween: Tween
var _feed: Label
var _feed_lines: Array[String] = []


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	player_panel.build(root)
	card.build(root)
	crosshair.build(root)

	var top_right := Ui.panel(root, Control.PRESET_TOP_RIGHT, Vector2(-16, 16))
	top_right.custom_minimum_size.x = 360
	_objective = Ui.label(top_right, "", 17)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 340

	_feed = Ui.label(null, "", 15)
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long line wraps rather than running under the hint bar
	_feed.custom_minimum_size.x = 400
	var feed_box := Ui.panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(16, -16))
	feed_box.get_child(0).add_child(_feed)
	feed_box.modulate.a = 0.85

	_hint = Ui.label(null, "", 14)
	var hint_box := Ui.panel(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -16))
	hint_box.get_child(0).add_child(_hint)
	_hint.text = "WASD move · Shift run · Space jump · hold LMB spray (invest: charge, release) · V view · B board · Tab inventory · Q talk · E use a stand · M map · scroll gun mode · T time speed · F3 inspect · Esc back"

	_prompt = _outlined(root, "", 20, 8)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position = Vector2(-120, 36)

	_caption = _outlined(root, "", 32, 10)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 120
	_caption.offset_bottom = 240
	_caption.offset_left = 120   # inset from the edges (clear of the panels at the top corners), and wrapped
	_caption.offset_right = -120
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0


## Light text with an ink outline, for words that float over the world.
func _outlined(parent: Node, text: String, size: int, outline: int) -> Label:
	var l := Ui.label(parent, text, size)
	l.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	l.add_theme_color_override("font_outline_color", Ui.INK)
	l.add_theme_constant_override("outline_size", outline)
	return l


# What the controllers say to the HUD. The first group is passed on to the parts.

func show_world(w: World, time_scale: float) -> void:
	player_panel.show_world(w, time_scale)


func show_player(p: Drone, cash: float) -> void:
	player_panel.show_player(p, cash)


func show_mode(mode: String) -> void:
	player_panel.show_mode(mode)


func show_target(d: Drone, w: World) -> void:
	card.show_target(d, w)


func show_charge(fraction: float, value: float) -> void:
	crosshair.show_charge(fraction, value)


## A line of story across the top of the screen: fades in, holds, fades out.
func show_caption(text: String, seconds: float) -> void:
	_caption.text = text
	if _caption_tween:
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.3)
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.6)


func show_prompt(text: String) -> void:
	_prompt.text = text


func show_objective(text: String) -> void:
	_objective.text = text


func notify(text: String) -> void:
	_feed_lines.append(text)
	while _feed_lines.size() > 5:
		_feed_lines.pop_front()
	_feed.text = "\n".join(_feed_lines)
