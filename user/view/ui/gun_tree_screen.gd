## VIEW. The money gun's upgrade tree (U): its four branches side by side, each a ladder of nodes from the bottom up. What the
## hero owns is lit; the rest is greyed, to be unlocked through the story. It only displays (the rules are GunTree's).
class_name GunTreeScreen
extends CanvasLayer

signal opened
signal closed

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.97, 0.94, 0.86, 0.97)
const LIT := Color(0.35, 0.65, 0.35)

var world: World
var _columns: HBoxContainer


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
	panel.add_theme_stylebox_override("panel", _box(PAPER, INK, 10, 18))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_label(v, "The money gun", 26)
	var sub := _label(v, "What it can do. The story unlocks the rest, one step at a time up each branch.", 15)
	sub.modulate.a = 0.75
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 14)
	v.add_child(_columns)
	var hint := _label(v, "U or Esc to close.", 13)
	hint.modulate.a = 0.6


func open(w: World) -> void:
	world = w
	visible = true
	refresh()
	opened.emit()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	for c in _columns.get_children():
		_columns.remove_child(c)
		c.queue_free()
	var tree := world.gun_tree
	for branch in GunTree.BRANCHES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.custom_minimum_size.x = 200
		_columns.add_child(col)
		_label(col, GunTree.BRANCH_NAMES[branch], 19)
		var ladder := GunTree.in_branch(branch)
		ladder.reverse()  # (the top of the ladder at the top)
		for n in ladder:
			col.add_child(_card(n, tree.owns(n.id)))


func _card(n: Dictionary, owned: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(1, 0.99, 0.94) if owned else Color(INK, 0.06), LIT if owned else Color(INK, 0.25), 6, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	_label(v, n.name, 16)
	var effect := _label(v, n.effect, 13)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var status := "Yours" if owned and n.live else ("Yours (does nothing yet)" if owned else "Locked: unlocked through the story (to come)")
	var s := _label(v, status, 12)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_color_override("font_color", LIT.darkened(0.2) if owned else Color(INK, 0.7))
	if not owned:
		card.modulate.a = 0.5  # greyed
	return card


func _box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_color = border
	sb.set_border_width_all(2)
	return sb


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l
