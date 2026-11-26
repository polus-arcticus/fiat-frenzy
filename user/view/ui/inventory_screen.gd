## VIEW. The Planet Crafter-style inventory screen. Your inventory on the left, the stand's on the right
## (or just yours, when opened with no stand).
## Right-click an item in the stand's stock to buy one; right-click an item in your own to use it. The
## stand's *input* inventory is shown too: what it is waiting for, and how short it is. This view only
## displays and asks (it emits `buy_requested`, `use_requested` and `unequip_requested`); the rules live in Commerce, Loadout
## and Placing, and what using an item means is the item's own (ItemDef.use). Above the bag is the loadout: what the hero rides and wears.
##
## A tent city opens here too, like any stand (its keeper's tents and barrel fires for sale, the scrap it wants), with a third
## panel: who lives there, an ID card each (click one for their story), and the tent city's own two things to do, put up a tent
## (`add_tent_requested`) and sit by the barrels (`warm_requested`). The rules for those live in Lodging and Commerce.
class_name InventoryScreen
extends CanvasLayer

signal buy_requested(machine: Machine, item: String)
signal use_requested(item: String)      # right-click in the bag: what that does is the item's to say (ItemDef.use)
signal unequip_requested(item: String)  # right-click in the loadout: back into the bag
signal add_tent_requested(city: Machine)
signal warm_requested(city: Machine)
signal opened
signal closed

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.97, 0.94, 0.86, 0.97)
const COLUMNS := 5      # slots across in a stand's stock
const BAG_COLUMNS := 4  # and in your bag

var world: World
var machine: Machine

var _root: Control
var _right: PanelContainer
var _left_bars := {}
var _wallet: Label
var _bag: GridContainer
var _loadout: GridContainer
var _title: Label
var _status: Label
var _sale: GridContainer
var _wants: VBoxContainer
var _message: Label
var _residents: PanelContainer
var _residents_count: Label
var _residents_news: Label
var _cards: VBoxContainer
var _add: Button
var _warm: Button
var _open_cards := {}    # uid -> true: the ID cards opened out to their story
var _cards_shown := ""   # what the cards were last drawn from (they are redrawn only when it changes, so the list keeps its scroll)


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
	_residents = _build_residents()
	row.add_child(_residents)
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
	for k in Drone.NEEDS:
		_left_bars[k] = _bar(v, k)
	_label(v, "Loadout", 18)
	_loadout = _grid(v, Loadout.SLOTS)
	_label(v, "Bag", 18)
	_bag = _grid(v, BAG_COLUMNS)
	var hint := _label(v, "Right-click to eat, drink, equip or put down; right-click the loadout to take off.", 14)
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


## A tent city's third panel: who lives there, and the two things to do there.
func _build_residents() -> PanelContainer:
	var panel := _panel()
	var v: VBoxContainer = panel.get_child(0)
	_label(v, "Who lives here", 24)
	_residents_count = _label(v, "", 15)
	_residents_news = _label(v, "", 14)
	_residents_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_residents_news.custom_minimum_size.x = 340
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 5)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	_add = _button(buttons, func(): add_tent_requested.emit(machine))
	_warm = _button(buttons, func(): warm_requested.emit(machine))
	var hint := _label(v, "Click a card for their story.", 14)
	hint.modulate.a = 0.7
	return panel


func _button(parent: Node, pressed: Callable) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


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
	fill.bg_color = Ui.bar_color(key)
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
	_residents.visible = m != null and m.shelter != null
	_cards_shown = ""
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
	_refresh_residents()


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _refresh_player() -> void:
	var p := world.player
	_wallet.text = "cash  $%.2f   (stakes paid you $%.2f)" % [world.ledger.player_cash, world.ledger.stake_income]
	for k in _left_bars:
		_left_bars[k].value = p.bars[k] * 100.0
	_clear(_loadout)
	var worn := world.loadout.items()
	for i in Loadout.SLOTS:
		if i < worn.size():
			var item: String = worn[i]
			var slot := SlotView.new().setup(item, 0, "", "%s: right-click to put it in your bag" % item.replace("_", " "), "good")
			slot.right_clicked.connect(func(): unequip_requested.emit(item))
			_loadout.add_child(slot)
		else:
			_loadout.add_child(SlotView.new().setup("", 0, "", "an empty slot: a bike, a board or clothes go here"))
	_clear(_bag)
	var stacks := Stacks.layout(p.carry)
	for i in Commerce.CARRY_SLOTS:
		if i < stacks.size():
			var item: String = stacks[i].item
			var use: String = Catalog.item(item).use()
			var hint: String = {"equip": "Right-click to equip", "consume": "Right-click to eat or drink", "place": "Right-click to put it down in the street"}.get(use, "can't be used")
			var slot := SlotView.new().setup(item, stacks[i].count, "", hint, "good" if use != "" else "")
			slot.right_clicked.connect(func(): use_requested.emit(item))
			_bag.add_child(slot)
		else:
			_bag.add_child(SlotView.new().setup("", 0))


func _refresh_machine() -> void:
	if machine == null:
		return
	var m := machine
	var owner_d := world.drone(m.owner)
	_title.text = m.display_name()
	var more := "you own the 49%% maximum" if m.investable() <= 0.0 else "up to $%.0f more can be invested" % m.investable()
	var stake := "Level %d, worth $%.0f. You own %d%% (%s)." % [m.level, m.value(), roundi(m.equity.share(world.ledger.local) * 100.0), more]
	if not m.working:
		_status.text = "Wrecked. %s needs $%d to repair it, and nothing is for sale." % [owner_d.label, int(m.repair_cost + Needs.RESERVE)]
	elif m.shelter != null:
		_status.text = "Kept by %s, who makes tents and barrel fires from scrap. %s" % [owner_d.label, stake]
	else:
		_status.text = "Run by %s. $%.2f each. %s" % [owner_d.label, m.price, stake]
	_clear(_sale)
	var stacks := Stacks.layout(m.output).filter(func(s): return m.wares.has(s.item) or (s.item == m.item and m.shelter == null))
	var shelf := m.wares.size() * Catalog.machine(m.kind).ware_cap if m.shelter != null else m.capacity()  # (a tent city: its wares only)
	var slots := maxi(maxi(Stacks.slots_for(shelf), m.wares.size()), COLUMNS if stacks.size() > COLUMNS else stacks.size())  # (a slot a ware, even sold out)
	var sold_out := m.wares.keys().filter(func(w): return m.output.count(w) <= 0)  # (a ware is shown even when there are none)
	for i in slots:
		var k := i - stacks.size()
		if m.working and i >= stacks.size() and k < sold_out.size():
			var ware: String = sold_out[k]
			var price := "$%.2f" % m.price_of(ware)
			_sale.add_child(SlotView.new().setup(ware, 0, price, "Sold out: %ss are made from scrap the runners bring" % ware.replace("_", " "), "bad"))
		elif i < stacks.size() and m.working:
			var item: String = stacks[i].item
			var affordable := world.ledger.player_cash >= m.price_of(item)
			var slot := SlotView.new().setup(item, stacks[i].count, "$%.2f" % m.price_of(item), "Right-click to buy one for $%.2f" % m.price_of(item), "good" if affordable else "bad")
			slot.right_clicked.connect(func(): buy_requested.emit(m, item))
			_sale.add_child(slot)
		else:
			_sale.add_child(SlotView.new().setup("", 0))
	_clear(_wants)
	for raw in m.input.caps:  # (its recipe's inputs, and the scrap its next tier is built of)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_wants.add_child(row)
		var have: int = m.input.count(raw)
		var cap: int = m.input.caps[raw]
		var per_craft: int = m.recipe.get(raw, 0)
		var low: bool = have < per_craft * Needs.RESTOCK_BELOW
		row.add_child(SlotView.new().setup(raw, have, "%d / %d" % [have, cap], "%s: %d of %d" % [raw.replace("_", " "), have, cap], "warn" if low else ""))
		var text := _source_note(raw, cap - have, have, Catalog.machine(m.kind).fetched_by(raw))
		var up := Catalog.next_tier(m.kind)
		if up != "" and Catalog.machine(up).build_goods.has(raw):
			text += " %d of it builds it up into a %s." % [int(Catalog.machine(up).build_goods[raw]), Catalog.machine(up).name]
		var note := _label(row, text, 14)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 250


## A tent city's people: how many tents and who is in them, an ID card each, and its two buttons.
func _refresh_residents() -> void:
	if machine == null or machine.shelter == null:
		return
	var city := machine
	var lodging := world.lodging
	var people := lodging.housed(city)
	var free := lodging.free_tents(city)
	var room := lodging.room_for(city)
	_residents_count.text = "Tents %d  ·  lived in %d  ·  empty %d  ·  %s" % [city.residence.tents, people.size(), free, ("room for %d more" % room) if room > 0 else "full for its tier"]
	if not city.working:
		_residents_news.text = "Wrecked: nobody is kept warm and nobody new will come."
	elif free > 0:
		var left := Lodging.ARRIVE_EVERY - float(lodging.waiting.get(city.uid, 0.0))
		_residents_news.text = "An empty tent: someone will come to live in it in about %d s." % ceili(left)
	else:
		_residents_news.text = "Every tent is lived in. Put up another and someone new will come and join the town."
	var statuses := people.map(func(d): return "care" if d.care != "" else ("home" if d.sheltered_in == city.shelter else "out"))
	var shown := "%s|%s|%s|%d" % [people.map(func(d): return d.uid), statuses, _open_cards.keys(), free]
	if shown != _cards_shown:
		_cards_shown = shown
		_clear(_cards)
		for i in people.size():
			var d: Drone = people[i]
			var card := IdCard.new().setup(d, world, i + 1, statuses[i], _open_cards.has(d.uid))
			card.toggled.connect(_toggle_card)
			_cards.add_child(card)
		for i in free:
			var empty := _label(_cards, "tent no. %d: empty" % (people.size() + i + 1), 13)
			empty.modulate.a = 0.5
	var price := lodging.next_tent_cost(city)
	var short := world.ledger.player_cash < price
	_add.text = "Put up a tent  $%.0f" % price
	_add.disabled = room <= 0 or short
	_add.tooltip_text = "No room at this tier." if room <= 0 else ("You have $%.2f: not enough." % world.ledger.player_cash if short else "Paid from your cash, to the tent keeper.")
	_warm.text = "Sit by the barrels"
	_warm.disabled = not city.working


func _toggle_card(uid: String) -> void:
	if _open_cards.has(uid):
		_open_cards.erase(uid)
	else:
		_open_cards[uid] = true
	refresh()


func _source_note(raw: String, short: int, have: int, by := "owner") -> String:
	var name := raw.replace("_", " ")
	if raw in Catalog.scavenged_goods():
		return "%s: wants %d more. Runners salvage it from the bins." % [name, short] if short > 0 else "%s: full." % name
	if by == "runner":
		return "%s: wants %d more. Runners bring it from another stand." % [name, short] if short > 0 else "%s: full." % name
	return "%s: wants %d more. Bought from another stand." % [name, short] if short > 0 else "%s: full." % name
