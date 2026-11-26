## VIEW. A bin in the street (WasteBin), and what has gathered in it: a heap that grows and shrinks with its count.
##   garbage    a dark wheelie bin, old bikes and rusted pieces heaped beside it (scrap)
##   recycling  a blue and a green container, bottles lying in front
##   organics   a brown bin, scraps of food heaped beside it
##   fountain   a stone basin with a spout, the water in it rising with what is there
##   any other  a grey crate, its heap in front (a source with no look of its own yet still shows, and says what it is)
class_name WasteBinView
extends Node3D

const RUST := [Color(0.45, 0.3, 0.22), Color(0.38, 0.38, 0.4), Color(0.55, 0.42, 0.3), Color(0.3, 0.32, 0.34)]
const GLASS := [Color(0.24, 0.5, 0.3), Color(0.45, 0.3, 0.16), Color(0.82, 0.86, 0.84)]
const FOOD := [Color(0.42, 0.62, 0.28), Color(0.85, 0.55, 0.2), Color(0.62, 0.42, 0.26), Color(0.88, 0.8, 0.5)]
const STONE := Color(0.66, 0.64, 0.6)
const WATER := Color(0.42, 0.62, 0.78)
const SHOWN := 24  # pieces of a heap drawn, at the most (more just makes it full)
const PLAIN := [Color(0.5, 0.48, 0.44), Color(0.6, 0.56, 0.5), Color(0.42, 0.42, 0.42)]

var bin: WasteBin
var _pieces: Array[MeshInstance3D] = []
var _water: MeshInstance3D
var _label: Label3D


func setup(b: WasteBin) -> WasteBinView:
	bin = b
	name = "WasteBin"
	position = Ground.at(b.pos)
	rotation.y = atan2(-b.front.x, -b.front.y)  # (its front to the street)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(b.uid)  # (its own look, the same every time: not the world's dice)
	var own := b.source != "map"  # (a real one on the map: the city draws the container itself, StreetThings; this draws its heap)
	match b.kind:
		"garbage":
			if own:
				Look.box(self, Vector3(0.7, 1.05, 0.75), Vector3(0, 0.52, 0.45), Color(0.2, 0.24, 0.24))
				Look.box(self, Vector3(0.74, 0.06, 0.8), Vector3(0, 1.08, 0.45), Color(0.15, 0.18, 0.18))
			for k in 2:  # an old bike or two, always there, on their sides
				old_bike(self, Vector3(dice.randf_range(-0.6, 0.6), 0.06 + k * 0.05, -0.4), Vector3(0, dice.randf() * TAU, 0.1))
			_heap(dice, RUST, Vector3(0, 0, -0.5), 0.8, Vector2(0.2, 0.55))
		"recycling":
			if own:
				Look.box(self, Vector3(1.1, 1.4, 0.9), Vector3(-0.65, 0.7, 0.4), Color(0.22, 0.36, 0.62))
				Look.box(self, Vector3(1.1, 1.4, 0.9), Vector3(0.65, 0.7, 0.4), Color(0.24, 0.5, 0.3))
			_heap(dice, GLASS, Vector3(0, 0, -0.45), 0.7, Vector2(0.08, 0.1), true)
		"organics":
			if own:
				Look.box(self, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0.45), Color(0.4, 0.28, 0.18))
				Look.box(self, Vector3(0.74, 0.06, 0.74), Vector3(0, 1.03, 0.45), Color(0.3, 0.2, 0.12))
			_heap(dice, FOOD, Vector3(0, 0, -0.45), 0.65, Vector2(0.12, 0.25))
		"fountain":
			if own:
				for side in 4:  # a square stone basin
					var r := side * PI * 0.5
					Look.box(self, Vector3(1.2, 0.5, 0.15), Vector3(sin(r) * 0.55, 0.25, cos(r) * 0.55), STONE, Vector3(0, r, 0))
				Look.box(self, Vector3(0.2, 1.1, 0.2), Vector3(0, 0.55, 0.45), STONE.darkened(0.1))   # the column
				Look.box(self, Vector3(0.08, 0.08, 0.3), Vector3(0, 1.0, 0.3), Color(0.5, 0.48, 0.44))  # the spout
				_water = Look.box(self, Vector3(1.0, 0.04, 1.0), Vector3(0, 0.1, 0), WATER)
		_:
			if own:
				Look.box(self, Vector3(0.8, 0.8, 0.7), Vector3(0, 0.4, 0.45), Color(0.4, 0.4, 0.38))
			_heap(dice, PLAIN, Vector3(0, 0, -0.45), 0.65, Vector2(0.12, 0.25))
	_label = Look.label3d(self, "", Vector3(0, 1.7, 0), 24)
	_process(0.0)
	return self


# The heap that gathers by the bin: SHOWN pieces, as many showing as there are things in it.
func _heap(dice: RandomNumberGenerator, colours: Array, at: Vector3, radius: float, size: Vector2, upright := false) -> void:
	for i in SHOWN:
		var a := dice.randf() * TAU
		var r := sqrt(dice.randf()) * radius
		var s := dice.randf_range(size.x, size.y)
		var dims := Vector3(s * 0.5, s * 2.5, s * 0.5) if upright else Vector3(s, s * 0.4, s * 0.7)
		var p := at + Vector3(cos(a) * r, 0.05 + float(i) / SHOWN * 0.35 * (1.0 - r / radius), sin(a) * r)
		var tilt := Vector3(PI * 0.5 if upright and dice.randf() < 0.6 else 0.0, dice.randf() * TAU, dice.randf_range(-0.4, 0.4))
		_pieces.append(Look.box(self, dims, p, colours[i % colours.size()], tilt))


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
	var n := bin.output.count(bin.item)
	var cap: int = bin.output.caps.get(bin.item, 1)
	var shown := int(ceil(float(n) / float(maxi(cap, 1)) * SHOWN))
	for i in _pieces.size():
		_pieces[i].visible = i < shown
	if _water != null:
		_water.position.y = 0.1 + 0.32 * float(n) / float(maxi(cap, 1))
	_label.text = "%s · %d" % [WasteBin.label_of(bin.kind), n]
