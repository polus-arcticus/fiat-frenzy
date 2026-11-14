## VIEW. The food bank: a charity stall with a green-and-white awning and shelves of base goods, a pile of
## flour sacks, bottled water, sugar and protein that shrinks and grows with its stock. It only reads the model.
class_name FoodBankView
extends Node3D

const LAYER_MACHINE := 8
const GOODS := ["flour", "bottled_water", "sugar", "protein"]
const COLORS := {"flour": Color(0.95, 0.93, 0.86), "bottled_water": Color(0.55, 0.78, 0.95), "sugar": Color(0.98, 0.98, 0.96), "protein": Color(0.92, 0.55, 0.55)}
const PILE := 5  # most pieces shown per good

var bank: FoodBank
var _piles := {}   # good -> its pieces
var _board: Label3D
var _clock := 0.0


func setup(fb: FoodBank, facing: float) -> FoodBankView:
	bank = fb
	name = "FoodBank"
	position = Vector3(fb.pos.x, 0, fb.pos.y)
	rotation.y = facing
	var prop := Node3D.new()
	add_child(prop)
	Look.box(prop, Vector3(3.4, 0.95, 0.9), Vector3(0, 0.48, 0), Color(0.55, 0.4, 0.28))
	Look.box(prop, Vector3(0.12, 2.3, 0.12), Vector3(-1.6, 1.15, -0.5), Color(0.45, 0.33, 0.24))
	Look.box(prop, Vector3(0.12, 2.3, 0.12), Vector3(1.6, 1.15, -0.5), Color(0.45, 0.33, 0.24))
	for k in 8:
		Look.box(prop, Vector3(0.42, 0.06, 1.6), Vector3(-1.5 + k * 0.43, 2.38, -0.1), Color(0.3, 0.62, 0.38) if k % 2 == 0 else Color(0.97, 0.97, 0.94), Vector3(0.18, 0, 0))
	for i in GOODS.size():
		var x := -1.2 + i * 0.8
		var pieces: Array[MeshInstance3D] = []
		for k in PILE:
			var at := Vector3(x + (k % 2) * 0.22 - 0.1, 1.06 + (k / 2) * 0.2, -0.05 + (k % 3) * 0.1)
			if GOODS[i] == "flour":
				pieces.append(Look.blob(prop, Vector3(0.34, 0.3, 0.26), at, COLORS[GOODS[i]]))
			else:
				pieces.append(Look.box(prop, Vector3(0.26, 0.24, 0.22), at, COLORS[GOODS[i]]))
		_piles[GOODS[i]] = pieces
	Look.solid_body(self, fb.solid())
	_board = Look.label3d(self, "", Vector3(0, 3.3, 0), 30, 18.0)
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 2.4, 2.4)
	Look.pick_area(self, box, Vector3(0, 1.2, 0), LAYER_MACHINE, "drone_id", fb.owner_id)
	_refresh()
	return self


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh()


func _refresh() -> void:
	var lines: Array[String] = []
	for good in GOODS:
		var n: int = bank.output.count(good)
		var cap: int = bank.output.caps[good]
		var shown := ceili(float(n) / cap * PILE)
		for k in _piles[good].size():
			_piles[good][k].visible = k < shown
		lines.append("%s %d" % [good.replace("bottled_", "").replace("_", " "), n])
	_board.text = "%s\n%s\n%s" % [bank.display_name(), "  ·  ".join(lines.slice(0, 2)), "  ·  ".join(lines.slice(2, 4))]
