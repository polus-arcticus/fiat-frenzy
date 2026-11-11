## VIEW. Mr. Nobody's house, furnished like anyone's: a rug, a table with two chairs, an armchair, a standing lamp,
## a shelf of ordinary books and a coat stand by the door. Nothing here gives him away (his plans and his
## insects are somewhere else, and he only talks about them). The building, door, floor and walls come from
## CityBuilder. Built in the room's own frame: x along the door wall, y up, z in from the door.
class_name SageHouseView
extends Node3D

const WOOD := Color(0.52, 0.4, 0.3)
const CLOTH := Color(0.55, 0.5, 0.45)

var _room: Node3D


func setup(layout: Dictionary) -> SageHouseView:
	name = "SageHouse"
	var door: Vector2 = layout.door
	var along: Vector2 = layout.along
	_room = Node3D.new()
	_room.position = Vector3(door.x, 0.0, door.y)
	_room.rotation.y = atan2(-along.y, along.x)  # local x runs along the wall, local z goes in from the door
	add_child(_room)
	Look.box(_room, Vector3(5.0, 0.03, 4.0), Vector3(0, 0.06, 6.0), Color(0.5, 0.42, 0.38))   # a rug
	Look.box(_room, Vector3(1.6, 0.03, 0.8), Vector3(0, 0.06, 0.8), Color(0.38, 0.36, 0.36))  # a mat
	_table(Vector3(-2.6, 0, 6.5))
	_armchair(Vector3(3.2, 0, 7.2))
	_shelf(Vector3(0, 0, 10.5))
	_lamp(Vector3(4.6, 0, 8.6))
	_coat_stand(Vector3(-5.6, 0, 1.2))
	for spot in [Vector2(0, 2.4), Vector2(-3, 7), Vector2(3, 7)]:
		var l := OmniLight3D.new()
		l.position = Vector3(spot.x, 3.2, spot.y)
		l.omni_range = 9.0
		l.light_energy = 0.9
		l.light_color = Color(1.0, 0.9, 0.72)
		_room.add_child(l)
	return self


func _table(at: Vector3) -> void:
	var t := Node3D.new()
	t.position = at
	_room.add_child(t)
	Look.box(t, Vector3(1.4, 0.06, 0.9), Vector3(0, 0.75, 0), WOOD)
	for sx in [-0.62, 0.62]:
		for sz in [-0.38, 0.38]:
			Look.box(t, Vector3(0.06, 0.75, 0.06), Vector3(sx, 0.375, sz), WOOD.darkened(0.2))
	for side in [-1.0, 1.0]:  # two chairs
		Look.box(t, Vector3(0.42, 0.05, 0.42), Vector3(0, 0.45, side * 0.85), WOOD)
		Look.box(t, Vector3(0.42, 0.5, 0.05), Vector3(0, 0.72, side * 1.05), WOOD)
		for sx in [-0.17, 0.17]:
			for sz in [-0.17, 0.17]:
				Look.box(t, Vector3(0.04, 0.45, 0.04), Vector3(sx, 0.22, side * 0.85 + sz), WOOD.darkened(0.2))
	Look.box(t, Vector3(0.3, 0.1, 0.3), Vector3(0.2, 0.83, 0.0), Color(0.85, 0.82, 0.75))        # a bowl on the table


func _armchair(at: Vector3) -> void:
	var a := Node3D.new()
	a.position = at
	a.rotation.y = PI * 0.8
	_room.add_child(a)
	Look.box(a, Vector3(0.9, 0.4, 0.8), Vector3(0, 0.3, 0), CLOTH)
	Look.box(a, Vector3(0.9, 0.55, 0.18), Vector3(0, 0.7, 0.32), CLOTH.darkened(0.1))
	for sx in [-1.0, 1.0]:
		Look.box(a, Vector3(0.14, 0.3, 0.8), Vector3(sx * 0.5, 0.5, 0), CLOTH.darkened(0.1))


func _shelf(at: Vector3) -> void:
	var s := Node3D.new()
	s.position = at
	_room.add_child(s)
	Look.box(s, Vector3(2.2, 1.9, 0.35), Vector3(0, 0.95, -0.2), WOOD.darkened(0.1))
	for row in 3:
		var y := 0.35 + row * 0.55
		Look.box(s, Vector3(2.0, 0.03, 0.34), Vector3(0, y - 0.18, -0.2), WOOD)
		var x := -0.9
		for i in 9:
			var w := 0.12 + 0.03 * float((i + row) % 3)
			Look.box(s, Vector3(w, 0.34, 0.24), Vector3(x + w * 0.5, y, -0.2), [Color(0.45, 0.3, 0.28), Color(0.3, 0.38, 0.45), Color(0.55, 0.5, 0.35), Color(0.35, 0.4, 0.33)][(i * 3 + row) % 4])
			x += w + 0.04


func _lamp(at: Vector3) -> void:
	var l := Node3D.new()
	l.position = at
	_room.add_child(l)
	Look.box(l, Vector3(0.3, 0.04, 0.3), Vector3(0, 0.02, 0), WOOD.darkened(0.3))
	Look.box(l, Vector3(0.04, 1.4, 0.04), Vector3(0, 0.72, 0), WOOD.darkened(0.3))
	Look.box(l, Vector3(0.36, 0.26, 0.36), Vector3(0, 1.5, 0), Color(0.95, 0.88, 0.7))


func _coat_stand(at: Vector3) -> void:
	var c := Node3D.new()
	c.position = at
	_room.add_child(c)
	Look.box(c, Vector3(0.05, 1.7, 0.05), Vector3(0, 0.85, 0), WOOD.darkened(0.3))
	Look.box(c, Vector3(0.4, 0.04, 0.04), Vector3(0, 1.6, 0), WOOD.darkened(0.3))
	Look.box(c, Vector3(0.34, 0.8, 0.14), Vector3(0.0, 1.1, 0.1), Color(0.3, 0.3, 0.34))          # a grey coat
