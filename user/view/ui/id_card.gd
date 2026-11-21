## VIEW. One resident's ID card, on the tent city's trading screen: a strip in the colour of what they do, their name, their ID
## number, which tent is theirs, their level, where they are from and since when, and whether they are home. Clicked, it opens
## out to their story (Biography). It only displays; `toggled` asks the screen to open or close it.
class_name IdCard
extends PanelContainer

signal toggled(uid: String)

## The strip's colour, by what they do (a vendor by their stand's trade).
const ROLE_COLORS := {"drifter": Color(0.55, 0.6, 0.5), "runner": Color(0.95, 0.75, 0.2), "keeper": Color(0.25, 0.6, 0.6),
	"clerk": Color(0.25, 0.3, 0.55), "medic": Color(0.85, 0.3, 0.3), "vendor": Color(0.95, 0.55, 0.2), "lodging": Color(0.45, 0.35, 0.6)}
const STATUS := {"home": ["at home", Color(0.35, 0.45, 0.75)], "out": ["out", Color(0.4, 0.65, 0.35)],
	"care": ["in care", Color(0.85, 0.3, 0.3)]}

var drone: Drone


## `number`: their tent, counting from 1. `status`: "home", "out" or "care".
func setup(d: Drone, w: World, number: int, status: String, open: bool) -> IdCard:
	drone = d
	var bio := Biography.of(d, w)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.99, 0.95)
	sb.border_color = Color(Ui.INK, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click for their story" if not open else "Click to close"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var strip := ColorRect.new()
	strip.color = _role_color(d, w)
	strip.custom_minimum_size = Vector2(8, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_l := Ui.label(top, d.label if d.label != "" else d.kind, 16)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s: Array = STATUS.get(status, STATUS.out)
	var dot := Ui.label(top, "● " + s[0], 12)
	dot.add_theme_color_override("font_color", s[1])
	var id_l := Ui.label(v, "ID %s   ·   tent no. %d   ·   level %d" % [bio.id, number, d.growth.level], 12)
	id_l.modulate.a = 0.7
	var since := "here from the start" if d.arrived_at < 0.0 else "here since " + _when(d.arrived_at)
	Ui.label(v, "%s  ·  from %s  ·  %s" % [_role_name(d, w), bio.hometown, since], 12)
	if open:
		var story := Ui.label(v, "Was %s. %s %s %s" % [bio.was, bio.fell, bio.here, bio.hope], 13)
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.custom_minimum_size.x = 300
	return self


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(drone.uid)
		accept_event()


static func _role_color(d: Drone, w: World) -> Color:
	var m := w.machine_of(d)
	if m != null and m.shelter != null:
		return ROLE_COLORS.lodging
	return ROLE_COLORS.get(d.kind, ROLE_COLORS.drifter)


static func _role_name(d: Drone, w: World) -> String:
	var m := w.machine_of(d)
	if m != null:
		return "keeper of the " + m.display_name().to_lower() if m.shelter != null else m.display_name().to_lower()
	return {"drifter": "drifter", "runner": "cart runner", "keeper": "food bank keeper", "clerk": "welfare clerk",
		"medic": "medic"}.get(d.kind, d.kind)


## "day 3, 14:20" for a time on the world clock.
static func _when(t: float) -> String:
	var frac := fmod(t, Clock.DAY_SECONDS) / Clock.DAY_SECONDS
	var h := fmod(6.0 + frac * 24.0, 24.0)
	return "day %d, %02d:%02d" % [int(t / Clock.DAY_SECONDS) + 1, int(h), int((h - floorf(h)) * 60.0)]
