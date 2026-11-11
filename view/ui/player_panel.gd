## VIEW (HUD part). The top-left panel: the clock and money, the gun's mode, and the hero's own bars.
class_name PlayerPanel
extends RefCounted

var bars := {}  # "level", "cash", "hunger", "thirst", "warmth" -> bar

var _status: Label
var _mode: Label
var _title: Label


func build(root: Control) -> void:
	var panel := Ui.panel(root, Control.PRESET_TOP_LEFT, Vector2(16, 16))
	_status = Ui.label(panel, "", 18)
	_mode = Ui.label(panel, "", 20)
	var box: VBoxContainer = panel.get_child(0)
	_title = Ui.label(box, "You", 15)
	bars = Ui.bars(box, ["level", "cash", "hunger", "thirst", "warmth"])


func show_world(w: World, time_scale: float) -> void:
	var moon := "  (night)" if w.clock.is_night() else ""
	_status.text = "Day %d  %s%s   ×%d\nyour cash  $%.2f\nfrom your stakes  $%.2f\nmoney printed  $%.0f" % [w.clock.day() + 1, w.clock.text(), moon, int(time_scale), w.ledger.player_cash, w.ledger.stake_income, w.ledger.printed]


func show_player(p: Drone, cash: float) -> void:
	_title.text = "You  ·  Level %d" % p.growth.level
	(bars["level"] as LevelBar).level = p.growth.level
	for k in bars:
		var v: float = p.growth.progress() if k == "level" else (clampf(cash / Look.CASH_FULL, 0.0, 1.0) if k == "cash" else p.bars[k])
		bars[k].value = v * 100.0


func show_mode(mode: String) -> void:
	_mode.text = "GUN: %s" % mode.to_upper()
	_mode.add_theme_color_override("font_color", Color(0.2, 0.5, 0.25) if mode == "gift" else Color(0.55, 0.35, 0.1))
