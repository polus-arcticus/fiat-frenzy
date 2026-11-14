## VIEW. The skate shop's room, next to the bike shop: a sign over the door, decks hung along the walls, a rug, a stack
## of boards by the counter with the price, and warm lights, so the inside reads in daylight and at night. The building,
## door and floor come from CityBuilder, and the counter from MachineView; this is only the dressing.
class_name SkateShopView
extends Node3D

const DECKS: Array[Color] = [
	Color(0.9, 0.45, 0.2), Color(0.25, 0.55, 0.75), Color(0.85, 0.25, 0.35), Color(0.3, 0.7, 0.45),
	Color(0.95, 0.8, 0.25), Color(0.55, 0.35, 0.7), Color(0.2, 0.2, 0.25),
]

var shop: Machine
var _door := Vector2.ZERO
var _along := Vector2.RIGHT
var _inward := Vector2.DOWN


func setup(layout: Dictionary, m: Machine) -> SkateShopView:
	shop = m
	name = "SkateShop"
	_door = layout.door
	_along = layout.along
	_inward = layout.inward
	var out: Vector2 = layout.out
	# the sign, on the wall over the door, facing the street
	var sign_pos := _at(0.0, -0.12)
	var board := Node3D.new()
	board.position = Vector3(sign_pos.x, 3.5, sign_pos.z)
	board.rotation.y = atan2(out.x, out.y)
	add_child(board)
	Look.box(board, Vector3(3.6, 0.6, 0.12), Vector3.ZERO, Color(0.12, 0.12, 0.14))
	Look.box(board, Vector3(3.7, 0.05, 0.14), Vector3(0, 0.32, 0), Color(0.9, 0.55, 0.2))
	Look.label3d(board, "SKATE SHOP", Vector3(0, 0, 0.1), 46, 70.0)
	# a doormat and a rug
	_box(Vector3(2.6, 0.03, 1.2), 0.0, 0.7, Color(0.2, 0.2, 0.24))
	_box(Vector3(5.0, 0.02, 4.0), 0.0, 6.0, Color(0.3, 0.42, 0.55))
	# decks hung on the side walls, standing on their ends, in rows
	var i := 0
	for lx in [-5.6, 5.6]:
		for lz in [2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5]:
			var at := _at(lx, lz)
			var deck := Node3D.new()
			deck.position = Vector3(at.x, 1.6, at.z)
			deck.rotation.y = atan2(_along.x, _along.y) + (PI / 2.0 if lx < 0.0 else -PI / 2.0)
			add_child(deck)
			Look.box(deck, Vector3(0.22, 0.8, 0.03), Vector3.ZERO, DECKS[i % DECKS.size()])
			Look.box(deck, Vector3(0.12, 0.28, 0.035), Vector3(0, 0.1, 0), DECKS[(i + 3) % DECKS.size()])
			i += 1
	# a low box and a short rail in the middle of the floor, to try the boards on
	_box(Vector3(2.4, 0.4, 1.0), -2.0, 10.5, Color(0.55, 0.52, 0.5))
	_box(Vector3(2.4, 0.06, 0.06), 2.0, 10.5, Color(0.8, 0.8, 0.82), 0.5)
	# the boards for sale, in a stack on the counter side, with their price
	var stand := _at(2.8, _counter_depth())
	for k in 3:
		var deck := Node3D.new()
		deck.position = Vector3(stand.x, 0.15 + k * 0.1, stand.z)
		deck.rotation.y = atan2(_along.x, _along.y) + 0.4 * k
		add_child(deck)
		Look.box(deck, Vector3(0.8, 0.05, 0.22), Vector3.ZERO, DECKS[(k * 2) % DECKS.size()])
	var tag_at := _at(2.8, _counter_depth() - 0.1)
	Look.label3d(self, "SKATEBOARD  $%d" % int(Catalog.base_price("skateboard")), Vector3(tag_at.x, 1.8, tag_at.z), 30, 25.0)
	# warm lights
	for spot in [Vector2(0, 3.5), Vector2(-5, 8), Vector2(5, 8), Vector2(0, 12)]:
		var l := OmniLight3D.new()
		var p := _at(spot.x, spot.y)
		l.position = Vector3(p.x, 3.4, p.z)
		l.omni_range = 11.0
		l.light_energy = 1.1
		l.light_color = Color(1.0, 0.86, 0.62)
		add_child(l)
	return self


## How far in from the door the counter stands (as Scenario puts it).
func _counter_depth() -> float:
	return (shop.pos - _door).dot(_inward)


## The world position `across` along the door's wall and `deep` metres in from it.
func _at(across: float, deep: float) -> Vector3:
	var p := _door + _along * across + _inward * deep
	return Vector3(p.x, 0.0, p.y)


func _box(size: Vector3, across: float, deep: float, color: Color, lift := 0.0) -> void:
	var at := _at(across, deep)
	var mi := Look.box(self, size, Vector3(at.x, size.y * 0.5 + lift, at.z), color)
	mi.rotation.y = atan2(_along.x, _along.y)
