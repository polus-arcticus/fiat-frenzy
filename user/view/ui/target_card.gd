## VIEW (HUD part). The card for whoever the crosshair is on: their money and survival bars, their reputation (with you) in points, and what they run
## (a stand's price, stock, worth and your stake; a runner's cart; the food bank's shelves).
class_name TargetCard
extends RefCounted

var title: Label
var info: Label
var bars := {}

var _panel: PanelContainer


func build(root: Control) -> void:
	_panel = Ui.panel(root, Control.PRESET_CENTER_BOTTOM, Vector2(0, -120))
	title = Ui.label(_panel, "", 20)
	bars = Ui.bars(_panel.get_child(0), ["money"] + Drone.NEEDS)
	info = Ui.label(_panel, "", 15)
	_panel.visible = false


func show_target(d: Drone, w: World) -> void:
	if d == null:
		_panel.visible = false
		return
	_panel.visible = true
	title.text = "%s  ·  level %d" % [d.label if d.label != "" else d.kind, d.growth.level]
	for k in Drone.NEEDS:
		bars[k].value = d.bars[k] * 100.0
	(bars["money"] as LevelBar).level = Wealth.tiers(d.wallet) + 1  # a notch for every order of magnitude: $10, $100, $1,000...
	bars["money"].value = Wealth.progress(d.wallet) * 100.0
	info.text = _describe(d, w)


## The lines under the bars.
func _describe(d: Drone, w: World) -> String:
	var job := w.profession_of(d)
	var text := ("%s  ·  " % job if job != "" else "") + "reputation %d points" % roundi(d.rep * 100.0)
	var r := d.runner
	if r != null:
		var load_text := ", ".join(r.cart.counts.keys().filter(func(k): return r.cart.count(k) > 0).map(func(k): return "%d %s" % [r.cart.count(k), k.replace("_", " ")]))
		text += "\n%s (holds %d): %s" % [r.rig().name, r.rig().load, load_text if load_text != "" else "empty"]
		text += "\n%d trips, %d units, $%.2f in fees" % [r.deliveries, r.delivered_total, r.fees_earned]
		var worth := r.equity.value(r.book_value(), d.growth.xp)
		text += "\nbusiness worth $%.0f  ·  you own %d%% of its fees" % [worth, roundi(r.equity.share(w.ledger.local) * 100.0)]
		var next := r.next_rig()
		if not next.is_empty():
			text += "\nsaving for a %s: $%.0f of $%.0f (buys it at dawn)" % [next.name, minf(d.wallet, float(next.cost) + Drone.RESERVE), float(next.cost) + Drone.RESERVE]
	var m := w.machine_of(d)
	if m != null:
		if m.working and m.residence != null:
			text += "\n%s: %d tents, %d lived in" % [m.display_name(), m.residence.tents, w.lodging.housed(m).size()]
			text += "\nworth $%.0f  ·  you own %d%%" % [m.value(), roundi(m.equity.share(w.ledger.local) * 100.0)]
		elif m.working:
			text += "\n%s: $%.2f, %d in stock" % [m.display_name(), m.price, m.stock()]
			text += "\nworth $%.0f  ·  you own %d%%" % [m.value(), roundi(m.equity.share(w.ledger.local) * 100.0)]
			if m.investable() > 0.0:
				text += "\n$%.0f more can be invested (the most you can own is 49%%)" % m.investable()
			else:
				text += "\nyou own the 49% maximum"
		else:
			text += "\n%s is wrecked: needs $%d" % [m.display_name(), int(m.repair_cost + Needs.RESERVE)]
	return text
