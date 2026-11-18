## VIEW + CONTROLLER (a menu). What Esc opens when nothing else is open: resume, save, back to the title, quit. It registers with
## the ScreenStack like the bag and the map, so the stack owns the mouse and the player's controls, and holds the sim while it is up.
class_name PauseScreen
extends CanvasLayer

signal opened
signal closed
signal save_requested
signal title_requested
## The player picked a chapter checkpoint (a SaveStore slot) to go back to.
signal chapter_requested(slot)
## Developer tool (debug builds): play the story forward to a stage (one of `stages`).
signal stage_requested(id)

var visible_now := false
## The developer's jumps ahead, as [id, label] pairs: handed in by whoever builds the game (the story's), before it is added.
var stages: Array = []
var _box: VBoxContainer
var _note: Label
var _chapters: VBoxContainer


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
	_chapters = VBoxContainer.new()
	_chapters.add_theme_constant_override("separation", 12)
	_box.add_child(_chapters)
	if OS.is_debug_build() and not stages.is_empty():
		var dev := Label.new()
		dev.text = "Dev: jump forward to"
		dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev.add_theme_color_override("font_color", Color("#9be3ff"))
		_box.add_child(dev)
		for st in stages:
			var id: String = st[0]
			_add(st[1], func(): stage_requested.emit(id)).add_theme_font_size_override("font_size", 16)
	_add("Quit to Title", func(): title_requested.emit())
	_add("Quit to Desktop", func(): get_tree().quit())
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", Color("#ffcf3a"))
	_box.add_child(_note)


## A button for each chapter the player has reached (its checkpoint exists).
func _refresh_chapters() -> void:
	for c in _chapters.get_children():
		_chapters.remove_child(c)
		c.queue_free()
	for slot in SaveStore.CHAPTERS:
		if FileAccess.file_exists(SaveStore.path(slot)):
			var b := _add("Restart  ·  " + SaveStore.CHAPTERS[slot], func(): chapter_requested.emit(slot), _chapters)
			b.add_theme_font_size_override("font_size", 18)


func _add(text: String, action: Callable, into: Container = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	(into if into != null else _box).add_child(b)
	return b


func open() -> void:
	if visible:
		return
	visible = true
	_note.text = ""
	_refresh_chapters()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## A line under the buttons ("Saved.").
func say(text: String) -> void:
	_note.text = text
