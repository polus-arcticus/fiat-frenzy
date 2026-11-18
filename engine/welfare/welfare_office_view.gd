## VIEW. The welfare office: a trestle desk under a blue-and-white awning, a cash box on it and a board that says what the
## purse holds, what came in and what went out. It only reads the model.
class_name WelfareOfficeView
extends Node3D

const LAYER_MACHINE := 8

var office: WelfareOffice
var _world: World
var _board: Label3D
var _clock := 0.0


func setup(o: WelfareOffice, world: World) -> WelfareOfficeView:
	office = o
	_world = world
	name = "WelfareOffice"
	position = Vector3(o.pos.x, 0, o.pos.y)
	rotation.y = atan2(-o.front.x, -o.front.y)  # (facing its front, as the stalls do)
	var prop := Node3D.new()
	add_child(prop)
	Look.box(prop, Vector3(2.4, 0.08, 0.9), Vector3(0, 0.82, 0), Color(0.6, 0.45, 0.3))  # the desk top
	for x in [-1.05, 1.05]:
		Look.box(prop, Vector3(0.08, 0.8, 0.8), Vector3(x, 0.4, 0), Color(0.45, 0.33, 0.24))
	Look.box(prop, Vector3(0.45, 0.25, 0.3), Vector3(0.6, 0.98, 0.05), Color(0.25, 0.3, 0.45))  # the cash box
	Look.box(prop, Vector3(0.6, 0.02, 0.4), Vector3(-0.5, 0.87, 0.05), Color(0.95, 0.94, 0.9))  # forms
	for x in [-1.2, 1.2]:
		Look.box(prop, Vector3(0.1, 2.3, 0.1), Vector3(x, 1.15, -0.45), Color(0.45, 0.33, 0.24))
	for k in 6:
		Look.box(prop, Vector3(0.42, 0.06, 1.3), Vector3(-1.05 + k * 0.42, 2.38, -0.05), Color(0.3, 0.45, 0.75) if k % 2 == 0 else Color(0.97, 0.97, 0.94), Vector3(0.18, 0, 0))
	_board = Look.label3d(self, "", Vector3(0, 3.2, 0), 30, 18.0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.4, 2.0)
	Look.pick_area(self, box, Vector3(0, 1.2, 0), LAYER_MACHINE, "drone_uid", o.owner)  # (aiming at it is aiming at its clerk)
	_refresh()
	return self


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh()


func _refresh() -> void:
	_board.text = "%s\ngiven out $%.0f" % [office.display_name(), office.given_out]
