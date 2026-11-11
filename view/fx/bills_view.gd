## VIEW. The loose money lying in the street: a pile of flat bills for each Bill the model says is loose,
## taller for more money, with its total shown when you are near. It creates and removes its piles to
## match the model, and only reads it.
class_name BillsView
extends Node3D

const BILL := preload("res://assets/models/bill.glb")

var world: World
var _piles := {}   # Bill -> Node3D
var _shown := {}   # Bill -> the value the pile was built for


func setup(w: World) -> BillsView:
	world = w
	name = "LooseCash"
	return self


func _process(_delta: float) -> void:
	var live := {}
	for b in world.bills:
		if not b.loose:
			continue
		live[b] = true
		if not _piles.has(b) or not is_equal_approx(_shown[b], b.value):
			if _piles.has(b):
				_piles[b].queue_free()
			_piles[b] = _build(b)
			_shown[b] = b.value
	for b in _piles.keys():
		if not live.has(b):
			_piles[b].queue_free()
			_piles.erase(b)
			_shown.erase(b)


func _build(b: Bill) -> Node3D:
	var pile := Node3D.new()
	pile.position = Vector3(b.pos.x, 0.04, b.pos.y)
	add_child(pile)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(b.pos.x * 10.0), roundi(b.pos.y * 10.0)))
	var count := clampi(ceili(b.value / 2.0), 1, 10)
	for i in count:
		var sheet := Look.model(BILL)
		sheet.scale = Vector3.ONE * 3.0
		sheet.position = Vector3(rng.randf_range(-0.12, 0.12), i * 0.018, rng.randf_range(-0.12, 0.12))
		sheet.rotation.y = rng.randf() * TAU
		pile.add_child(sheet)
	Look.label3d(pile, "$%d" % roundi(b.value), Vector3(0, 0.7, 0), 30, 10.0)
	return pile
