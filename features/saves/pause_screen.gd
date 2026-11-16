## VIEW + CONTROLLER (a menu). What Esc opens when nothing else is open: resume, save, back to the title, quit. It registers with
## the ScreenStack like the bag and the map, so the stack owns the mouse and the player's controls, and holds the sim while it is up.
class_name PauseScreen
extends CanvasLayer

signal opened
signal closed
signal save_requested
signal title_requested

var visible_now := false
var _box: VBoxContainer
var _note: Label


func _ready() -> void:
	layer = 30
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.05, 0.12, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 12)
	dim.add_child(_box)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("#fff2cf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_add("Resume", close)
	_add("Save Game", func():
		save_requested.emit())
	_add("Quit to Title", func(): title_requested.emit())
	_add("Quit to Desktop", func(): get_tree().quit())
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", Color("#ffcf3a"))
	_box.add_child(_note)


func _add(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	_box.add_child(b)


func open() -> void:
	if visible:
		return
	visible = true
	_note.text = ""
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## A line under the buttons ("Saved.").
func say(text: String) -> void:
	_note.text = text
