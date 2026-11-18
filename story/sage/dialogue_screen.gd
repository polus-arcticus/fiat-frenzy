## VIEW. A conversation: the speaker's name, a page of what they say (typed out letter by letter), and either
## "keep reading" or a list of things to ask about. It only displays and asks: it says when a page run is
## finished (`finished`) and what was chosen (`chosen`), and the controller decides what happens next.
## Esc closes it through the ScreenStack (`close()`), like the inventory screen.
class_name DialogueScreen
extends CanvasLayer

signal opened
signal closed
signal finished         # the last page of a run has been read
signal chosen(id: String)  # a topic, or "farewell"

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.97, 0.94, 0.86, 0.97)
const CHARS_PER_SECOND := 75.0
const FAREWELL := "farewell"

## Whoever is running this conversation (a controller). They are told, by method name, when a run of pages is
## finished (`dialogue_finished()`), what was chosen (`dialogue_chosen(id)`) and when it closed (`dialogue_closed()`);
## any of them may be left out. Set it before `read` or `menu`; it is let go when the screen closes. This way two
## conversations never answer each other's screens.
var handler: Object = null
## Show whole pages at once (the headless tests).
var instant := false
var speaker := ""
var mode := ""  # "read", "menu" or ""

var _pages: Array = []
var _page := 0
var _typed := 0.0
var _root: Control
var _name: Label
var _text: Label
var _hint: Label
var _choices: GridContainer
var _topic_ids: Array[String] = []


func _ready() -> void:
	layer = 21
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui_input)
	finished.connect(func(): _tell("dialogue_finished", []))
	chosen.connect(func(id: String): _tell("dialogue_chosen", [id]))
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.12, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = -1  # smaller than the contents need, so it grows upward to fit them
	panel.offset_bottom = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.y = 230
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_name = _label(box, "", 26)
	_name.add_theme_color_override("font_color", Color(0.62, 0.1, 0.12))
	_text = _label(box, "", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choices = GridContainer.new()  # two columns: the list of stories gets long, and must not run off the screen
	_choices.columns = 2
	_choices.add_theme_constant_override("h_separation", 10)
	_choices.add_theme_constant_override("v_separation", 4)
	box.add_child(_choices)
	_hint = _label(box, "", 15)
	_hint.modulate.a = 0.7


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


## Starts reading `pages` (a list of paragraphs) as `who`.
func read(who: String, pages: Array) -> void:
	speaker = who
	mode = "read"
	_pages = pages
	_page = 0
	_clear_choices()
	_show_page()
	_show()


## Shows what the speaker will talk about: `topics` is [{id, title, told}], and there is always a farewell.
func menu(who: String, intro: String, topics: Array) -> void:
	speaker = who
	mode = "menu"
	_name.text = who
	_text.text = intro
	_text.visible_characters = -1
	_hint.text = "Press a number, or click.  Esc to go."
	_clear_choices()
	_topic_ids.clear()
	var n := 1
	for t in topics:
		_add_choice("%d.  %s%s" % [n, t.title, "   (heard)" if t.told else ""], t.id)
		_topic_ids.append(t.id)
		n += 1
	_add_choice("%d.  Farewell" % n, FAREWELL)
	_topic_ids.append(FAREWELL)
	_show()


## Finishes the page being typed, or goes on to the next, or (after the last) says it's finished.
func advance() -> void:
	if mode != "read":
		return
	if _typing():
		_typed = float(_text.text.length())
		_text.visible_characters = -1
	elif _page < _pages.size() - 1:
		_page += 1
		_show_page()
	else:
		finished.emit()


func close() -> void:
	if visible:
		visible = false
		mode = ""
		closed.emit()
		_tell("dialogue_closed", [])
		handler = null


func _tell(method: String, args: Array) -> void:
	if handler != null and handler.has_method(method):
		handler.callv(method, args)


func _show() -> void:
	if not visible:
		visible = true
		opened.emit()


func _show_page() -> void:
	_name.text = speaker
	_text.text = String(_pages[_page])
	_typed = 0.0
	_text.visible_characters = -1 if instant else 0
	_hint.text = "E, Space or click to go on" if _page < _pages.size() - 1 else "E, Space or click to finish"


func _typing() -> bool:
	return not instant and _text.visible_characters >= 0 and _text.visible_characters < _text.text.length()


func _add_choice(label: String, id: String) -> void:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): chosen.emit(id))
	_choices.add_child(b)


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _process(delta: float) -> void:
	if visible and mode == "read" and _typing():
		_typed += CHARS_PER_SECOND * delta
		_text.visible_characters = mini(int(_typed), _text.text.length())


func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and mode == "read":
		advance()
		_root.accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if mode == "read" and (e.is_action_pressed("interact") or e.is_action_pressed("skip")):
		advance()
		get_viewport().set_input_as_handled()
	elif mode == "menu" and e is InputEventKey and e.pressed and not e.echo:
		var n: int = int(e.physical_keycode) - int(KEY_1)
		if n >= 0 and n < _topic_ids.size():
			chosen.emit(_topic_ids[n])
			get_viewport().set_input_as_handled()
