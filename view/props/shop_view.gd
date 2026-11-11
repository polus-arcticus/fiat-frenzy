## VIEW. The bike shop's room: a sign over the door, bikes on display along the walls, a rug, and warm lights, so
## the inside reads in daylight and at night. The building, door and floor come from CityBuilder, and the
## counter from MachineView; this is only the dressing. The bike that is for sale stands by the counter
## with its price, until it is bought.
class_name ShopView
extends Node3D

var shop: Machine
var _door := Vector2.ZERO
var _along := Vector2.RIGHT
var _inward := Vector2.DOWN
var _for_sale: Node3D
var _tag: Label3D


func setup(layout: Dictionary, m: Machine) -> ShopView:
	shop = m
	name = "BikeShop"
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
	Look.box(board, Vector3(3.6, 0.6, 0.12), Vector3.ZERO, Color(0.16, 0.34, 0.5))
	Look.box(board, Vector3(3.7, 0.05, 0.14), Vector3(0, 0.32, 0), Color(0.95, 0.85, 0.5))
	Look.label3d(board, "BIKE SHOP", Vector3(0, 0, 0.1), 46, 70.0)
	# a doormat and a rug
	_box(Vector3(2.6, 0.03, 1.2), 0.0, 0.7, Color(0.3, 0.28, 0.3))
	_box(Vector3(5.0, 0.02, 4.0), 0.0, 6.0, Color(0.62, 0.3, 0.28))
	# bikes on display along the side walls
	var i := 0
	for lx in [-5.5, 5.5]:
		for lz in [3.0, 6.0, 9.0]:
			if lx > 0.0 and lz > 6.5:
				continue
			_display(lx, lz, BikeModel.FRAMES[i % BikeModel.FRAMES.size()], PI / 2.0 if lx < 0.0 else -PI / 2.0)
			i += 1
	# the one for sale, by the counter
	var for_sale_at := _at(2.8, _counter_depth())
	_for_sale = BikeModel.build(BikeModel.FRAMES[0])
	_for_sale.position = for_sale_at
	_for_sale.rotation.y = atan2(_along.x, _along.y) + PI
	add_child(_for_sale)
	var tag_at := _at(2.8, _counter_depth() - 0.1)
	_tag = Look.label3d(self, "FOR SALE  $%d" % int(Catalog.bike_price()), Vector3(tag_at.x, 1.8, tag_at.z), 30, 25.0)
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


func _process(_delta: float) -> void:
	var on := shop.stock() >= 1
	_for_sale.visible = on
	_tag.visible = on


## Where the counter is, how far in from the door.
func _counter_depth() -> float:
	return (shop.pos - _door).dot(_inward)


## A point in the shop's own frame: `lx` along the door wall, `lz` in from the door (metres).
func _at(lx: float, lz: float) -> Vector3:
	var p := _door + _along * lx + _inward * lz
	return Vector3(p.x, 0.0, p.y)


func _box(size: Vector3, lx: float, lz: float, color: Color) -> void:
	var p := _at(lx, lz)
	var m := Look.box(self, size, Vector3(p.x, size.y * 0.5 + 0.04, p.z), color)
	m.rotation.y = atan2(_along.x, _along.y) + PI / 2.0 * 0.0


func _display(lx: float, lz: float, paint: Color, yaw_offset: float) -> void:
	var b := BikeModel.build(paint)
	var p := _at(lx, lz)
	b.position = Vector3(p.x, 0.04, p.z)
	b.rotation.y = atan2(_along.x, _along.y) + yaw_offset
	add_child(b)
