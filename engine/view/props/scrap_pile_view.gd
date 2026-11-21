## VIEW. A pile of scrap in the street: a heap of rusted pieces that grows and shrinks with what lies there (see ScrapPile).
class_name ScrapPileView
extends Node3D

const RUST := [Color(0.45, 0.3, 0.22), Color(0.38, 0.38, 0.4), Color(0.55, 0.42, 0.3), Color(0.3, 0.32, 0.34)]

var pile: ScrapPile
var _pieces: Array[MeshInstance3D] = []
var _label: Label3D


func setup(p: ScrapPile) -> ScrapPileView:
	pile = p
	name = "ScrapPile"
	position = Vector3(p.pos.x, 0, p.pos.y)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(p.uid)  # (its own look, the same every time: not the world's dice)
	for k in 4:  # the old bikes it is heaped round, always there: on their sides, one on another
		var a := dice.randf() * TAU
		var at := Vector3(cos(a), 0.0, sin(a)) * dice.randf_range(0.3, 1.0)
		old_bike(self, at + Vector3(0, 0.06 + k * 0.05, 0), Vector3(0, dice.randf() * TAU, dice.randf_range(-0.2, 0.2)))
	for i in ScrapPile.CAP:
		var a := dice.randf() * TAU
		var r := sqrt(dice.randf()) * 0.9
		var size := Vector3(dice.randf_range(0.2, 0.6), dice.randf_range(0.05, 0.2), dice.randf_range(0.1, 0.4))
		var at := Vector3(cos(a) * r, 0.05 + float(i) / ScrapPile.CAP * 0.5 * (1.0 - r), sin(a) * r)
		_pieces.append(Look.box(self, size, at, RUST[i % RUST.size()], Vector3(0, dice.randf() * TAU, dice.randf_range(-0.4, 0.4))))
	_label = Look.label3d(self, "", Vector3(0, 1.4, 0), 24)
	_process(0.0)
	return self


## An old bike: a rusty frame and two wheels, lying flat in its own plane (turn it up on its wheels with `rot`). Also the bike
## camp's (MachineView).
static func old_bike(parent: Node3D, at: Vector3, rot: Vector3) -> Node3D:
	var frame := Node3D.new()
	frame.position = at
	frame.rotation = rot
	parent.add_child(frame)
	Look.box(frame, Vector3(1.0, 0.05, 0.05), Vector3(0, 0, 0), Color(0.5, 0.18, 0.15))
	Look.box(frame, Vector3(0.05, 0.05, 0.6), Vector3(0.2, 0, 0.1), Color(0.5, 0.18, 0.15), Vector3(0, 0.6, 0))
	for side in [-0.5, 0.5]:
		var wheel := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.27
		ring.outer_radius = 0.33
		wheel.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.12, 0.13)
		wheel.material_override = mat
		wheel.position = Vector3(side, 0.0, 0.0)
		frame.add_child(wheel)
	return frame


func _process(_delta: float) -> void:
	var n := pile.output.count("scrap")
	for i in _pieces.size():
		_pieces[i].visible = i < n
	_label.text = "scrap · %d" % n
