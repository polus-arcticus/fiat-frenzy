## VIEW. The tent city's screen (E at it): the cluster's spawn factory. How many tents it has and how many stand empty, its
## barrels, who lives in each tent, and what the hero can do: put up a tent (the money gun pays, and someone new comes to live in
## it), or sit a while by the barrels. It only displays and asks (add_requested, warm_requested); the rules live in Lodging.
class_name TentScreen
extends CanvasLayer

signal opened
signal closed
signal add_requested(city: Machine)
signal warm_requested(city: Machine)

const INK := InventoryScreen.INK
const PAPER := InventoryScreen.PAPER
const ASLEEP := Color(0.35, 0.45, 0.75)
const COLUMNS := 4

var world: World
var tent: Machine  # (the tent city)

var _title: Label
var _tents: Label
var _barrels: Label
var _news: Label
var _who: GridContainer
var _add: Button
var _warm: Button
var _message: Label


func _ready() -> void:
	layer = 20
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.12, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	sb.border_color = INK
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_title = _label(v, "", 26)
	_tents = _label(v, "", 18)
	_barrels = _label(v, "", 16)
	_news = _label(v, "", 15)
	_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(v, "Who lives here", 18)
	_who = GridContainer.new()
	_who.columns = COLUMNS
	_who.add_theme_constant_override("h_separation", 6)
	_who.add_theme_constant_override("v_separation", 6)
	v.add_child(_who)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_add = _button(row, func(): add_requested.emit(tent))
	_warm = _button(row, func(): warm_requested.emit(tent))
	_message = _label(v, "", 16)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := _label(v, "E, Esc or walk away to close.", 13)
	hint.modulate.a = 0.6


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


func _button(parent: Node, pressed: Callable) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


func open(w: World, t: Machine) -> void:
	world = w
	tent = t
	_message.text = ""
	visible = true
	refresh()
	opened.emit()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Redraws from the model. `message` replaces the line at the bottom if given.
func refresh(message := "") -> void:
	if not visible:
		return
	if message != "":
		_message.text = message
	var lodging := world.lodging
	var people := lodging.housed(tent)
	var free := lodging.free_tents(tent)
	_title.text = tent.display_name() + ("" if tent.working else "  ·  wrecked")
	_tents.text = "Tents  %d   ·   lived in %d   ·   empty %d" % [tent.tents, people.size(), free]
	var room := lodging.room_for(tent)
	_barrels.text = "Room for %d more at this tier" % room if room > 0 else "Full for its tier: build it up to grow"
	if not tent.working:
		_news.text = "Wrecked: nobody is kept warm and nobody new will come. Its keeper needs $%d to put it back up." % int(tent.repair_cost + Drone.RESERVE)
	elif free > 0:
		var left := Lodging.ARRIVE_EVERY - float(lodging.waiting.get(tent.uid, 0.0))
		_news.text = "An empty tent: someone will come to live in it in about %d s." % ceili(left)
	else:
		_news.text = "Every tent is lived in. Put up another and someone new will come and join the town."
	for c in _who.get_children():
		_who.remove_child(c)
		c.queue_free()
	for d in people:
		var chip := _label(_who, d.label if d.label != "" else d.kind, 14)
		chip.custom_minimum_size.x = 110
		if d.sheltered_in == tent.shelter:
			chip.add_theme_color_override("font_color", ASLEEP)
			chip.tooltip_text = "asleep in their tent"
	for i in free:
		var chip := _label(_who, "(empty tent)", 14)
		chip.modulate.a = 0.5
	_add.text = "Put up a tent  $%.0f" % lodging.next_tent_cost(tent)
	_add.disabled = not world.gun_owned or room <= 0
	_add.tooltip_text = "You need the money gun to pay for it." if not world.gun_owned else ("The money gun pays for it." if room > 0 else "No room at this tier.")
	_warm.text = "Sit by the barrels"
	_warm.disabled = not tent.working
