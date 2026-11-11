## VIEW. The Planet Crafter-style inventory screen. Your inventory on the left, the stand's on the right
## (or just yours, when opened with no stand).
## Right-click an item in the stand's stock to buy one; right-click an item in your own to use it. The
## stand's *input* inventory is shown too: what it is waiting for, and how short it is. This view only
## displays and asks (it emits `buy_requested` and `consume_requested`); the rules live in Commerce.
class_name InventoryScreen
extends CanvasLayer

signal buy_requested(machine: Machine, item: String)
signal consume_requested(item: String)
signal opened
signal closed

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.97, 0.94, 0.86, 0.97)
const BAR_COLORS := {"hunger": Color(0.85, 0.55, 0.25), "thirst": Color(0.3, 0.6, 0.85), "warmth": Color(0.9, 0.35, 0.25)}
const COLUMNS := 5      # slots across in a stand's stock
const BAG_COLUMNS := 4  # and in your bag

var world: World
var machine: Machine

var _root: Control
var _right: PanelContainer
var _left_bars := {}
var _wallet: Label
var _bag: GridContainer
var _title: Label
var _status: Label
var _sale: GridContainer
var _wants: VBoxContainer
var _message: Label


func _ready() -> void:
	layer = 20
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.12, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)  # also swallows clicks, so they don't re-capture the mouse
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 36)
	_root.add_child(row)
	row.add_child(_build_left())
	_right = _build_right()
	row.add_child(_right)
	_message = _label(_root, "", 20)
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.offset_top = -110
	_message.offset_bottom = -70
	_message.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	_message.add_theme_color_override("font_outline_color", INK)
	_message.add_theme_constant_override("outline_size", 8)


func _build_left() -> PanelContainer:
	var panel := _panel()
	var v: VBoxContainer = panel.get_child(0)
	_label(v, "Your inventory", 24)
	_wallet = _label(v, "", 17)
	for k in ["hunger", "thirst", "warmth"]:
		_left_bars[k] = _bar(v, k)
	_label(v, "", 8)
	_bag = _grid(v, BAG_COLUMNS)
	var hint := _label(v, "Right-click something to eat or drink it.", 14)
	hint.modulate.a = 0.7
	return panel


func _build_right() -> PanelContainer:
	var panel := _panel()
	var v: VBoxContainer = panel.get_child(0)
	_title = _label(v, "", 24)
	_status = _label(v, "", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 340
	_label(v, "For sale", 18)
	_sale = _grid(v)
	var hint := _label(v, "Right-click to buy one.", 14)
	hint.modulate.a = 0.7
	_label(v, "Wants (its input inventory)", 18)
	_wants = VBoxContainer.new()
	_wants.add_theme_constant_override("separation", 6)
	v.add_child(_wants)
	return panel


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	sb.border_color = INK
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(380, 480)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return p


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


func _grid(parent: Node, columns := COLUMNS) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	return g


func _bar(parent: Node, key: String) -> ProgressBar:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := _label(h, key, 14)
	l.custom_minimum_size.x = 60
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(220, 14)
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.15)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLORS[key]
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


## `m` null opens just your own inventory.
func open(w: World, m: Machine = null) -> void:
	world = w
	machine = m
	_right.visible = m != null
	visible = true
	refresh("")
	opened.emit()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Redraws both panels from the model. `message` replaces the line at the bottom if given.
func refresh(message := "") -> void:
	if not visible:
		return
	if message != "":
		_message.text = message
	_refresh_player()
	_refresh_machine()


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _refresh_player() -> void:
	var p := world.player
	_wallet.text = "cash  $%.2f   (stakes paid you $%.2f)" % [world.ledger.player_cash, world.ledger.stake_income]
	for k in _left_bars:
		_left_bars[k].value = p.bars[k] * 100.0
	_clear(_bag)
	var stacks := Stacks.layout(p.carry)
	for i in Commerce.CARRY_SLOTS:
		if i < stacks.size():
			var item: String = stacks[i].item
			var usable := Catalog.is_consumable(item)
			var slot := SlotView.new().setup(item, stacks[i].count, "", "Right-click to use" if usable else "can't be used", "good" if usable else "")
			slot.right_clicked.connect(func(): consume_requested.emit(item))
			_bag.add_child(slot)
		else:
			_bag.add_child(SlotView.new().setup("", 0))


func _refresh_machine() -> void:
	if machine == null:
		return
	var m := machine
	var owner_d := world.drones[m.owner_id]
	_title.text = m.display_name()
	if m.working:
		var more := "you own the 49%% maximum" if m.investable() <= 0.0 else "up to $%.0f more can be invested" % m.investable()
		_status.text = "Run by %s. $%.2f each. Level %d, worth $%.0f. You own %d%% (%s)." % [owner_d.label, m.price, m.level, m.value(), roundi(m.equity.stake * 100.0), more]
	else:
		_status.text = "Wrecked. %s needs $%d to repair it, and nothing is for sale." % [owner_d.label, int(m.repair_cost + Needs.RESERVE)]
	_clear(_sale)
	var stacks := Stacks.layout(m.output)
	var slots := maxi(Stacks.slots_for(m.capacity()), COLUMNS if stacks.size() > COLUMNS else Stacks.slots_for(m.capacity()))
	for i in slots:
		if i < stacks.size() and m.working:
			var item: String = stacks[i].item
			var affordable := world.ledger.player_cash >= m.price_of(item)
			var slot := SlotView.new().setup(item, stacks[i].count, "$%.2f" % m.price_of(item), "Right-click to buy one for $%.2f" % m.price_of(item), "good" if affordable else "bad")
			slot.right_clicked.connect(func(): buy_requested.emit(m, item))
			_sale.add_child(slot)
		else:
			_sale.add_child(SlotView.new().setup("", 0))
	_clear(_wants)
	for raw in m.recipe:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_wants.add_child(row)
		var have: int = m.input.count(raw)
		var cap: int = m.input.caps[raw]
		var per_craft: int = m.recipe[raw]
		var low: bool = have < per_craft * Needs.RESTOCK_BELOW and raw not in Catalog.free_inputs()
		row.add_child(SlotView.new().setup(raw, have, "%d / %d" % [have, cap], "%s: %d of %d" % [raw.replace("_", " "), have, cap], "warn" if low else ""))
		var note := _label(row, _source_note(raw, cap - have, have), 14)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 250


func _source_note(raw: String, short: int, have: int) -> String:
	var name := raw.replace("_", " ")
	if raw in Catalog.free_inputs():
		return "%s: found lying around, never runs out." % name
	if raw in Catalog.relief_goods():
		return "%s: wants %d more. The Red Cross van brings it, free." % [name, short] if short > 0 else "%s: full." % name
	return "%s: wants %d more. Bought from another stand." % [name, short] if short > 0 else "%s: full." % name
