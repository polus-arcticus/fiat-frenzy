## VIEW. The tent's screen (E at a tent): the cluster's home, as a drone bay. How many beds it has and how many are free, its
## barrels and how many beds each warms, who sleeps there, and what the hero can do: add a bed (the money gun pays), take one
## away (and who would leave for it), or sit a while by the barrels. It only displays and asks (add_requested,
## remove_requested, warm_requested); the rules live in Lodging.
class_name TentScreen
extends CanvasLayer

signal opened
signal closed
signal add_requested(tent: Machine)
signal remove_requested(tent: Machine)
signal warm_requested(tent: Machine)

const INK := InventoryScreen.INK
const PAPER := InventoryScreen.PAPER
const ASLEEP := Color(0.35, 0.45, 0.75)
const COLUMNS := 4

var world: World
var tent: Machine

var _title: Label
var _beds: Label
var _barrels: Label
var _news: Label
var _who: GridContainer
var _add: Button
var _remove: Button
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
	_beds = _label(v, "", 18)
	_barrels = _label(v, "", 16)
	_news = _label(v, "", 15)
	_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(v, "Who sleeps here", 18)
	_who = GridContainer.new()
	_who.columns = COLUMNS
	_who.add_theme_constant_override("h_separation", 6)
	_who.add_theme_constant_override("v_separation", 6)
	v.add_child(_who)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_add = _button(row, func(): add_requested.emit(tent))
	_remove = _button(row, func(): remove_requested.emit(tent))
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
	var free := lodging.free_beds(tent)
	_title.text = tent.display_name() + ("" if tent.working else "  ·  wrecked")
	_beds.text = "Beds  %d   ·   taken %d   ·   free %d" % [tent.beds, people.size(), free]
	_barrels.text = "Barrels  %d   ·   each warms %d beds" % [tent.modules(), tent.beds_per_barrel()]
	if not tent.working:
		_news.text = "Wrecked: its barrels are cold and nobody new will come. Its keeper needs $%d to put it back up." % int(tent.repair_cost + Needs.RESERVE)
	elif free > 0:
		var left := Lodging.ARRIVE_EVERY - float(lodging.waiting.get(tent.uid, 0.0))
		_news.text = "A free bed: someone will come for it in about %d s." % ceili(left)
	else:
		_news.text = "Every bed is taken. Add one and a newcomer will come and join the town."
	for c in _who.get_children():
		_who.remove_child(c)
		c.queue_free()
	for d in people:
		var chip := _label(_who, d.label if d.label != "" else d.kind, 14)
		chip.custom_minimum_size.x = 110
		if d.sheltered_in == tent.shelter:
			chip.add_theme_color_override("font_color", ASLEEP)
			chip.tooltip_text = "asleep in their bed"
	for i in free:
		var chip := _label(_who, "(free bed)", 14)
		chip.modulate.a = 0.5
	var cost := lodging.next_bed_cost(tent)
	var new_barrel := cost > Lodging.BED_COST
	_add.text = "Add a bed  $%.0f%s" % [cost, "  (and a barrel)" if new_barrel else ""]
	_add.disabled = not world.gun_owned
	_add.tooltip_text = "The money gun pays for it." if world.gun_owned else "You need the money gun to pay for it."
	var leaver := lodging.who_would_leave(tent)
	_remove.text = "Take a bed away" + ("" if free > 0 or leaver == null else "  (%s leaves)" % (leaver.label if leaver.label != "" else "a drifter"))
	_remove.disabled = tent.beds <= 0 or (free <= 0 and leaver == null)
	_warm.text = "Sit by the barrels"
	_warm.disabled = not tent.working
