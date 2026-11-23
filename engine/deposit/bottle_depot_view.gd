## VIEW. The bottle depot: a kiosk on the pavement, a counter with stacked crates of empties beside it, under a green "PFAND"
## board, and a line saying what it has paid out. It only reads the model.
class_name BottleDepotView
extends Node3D

const LAYER_MACHINE := 8
const CRATE := Color(0.2, 0.45, 0.3)
const GLASS := Color(0.55, 0.75, 0.6)

var depot: BottleDepot
var _world: World
var _board: Label3D
var _clock := 0.0


func setup(d: BottleDepot, world: World) -> BottleDepotView:
	depot = d
	_world = world
	name = "BottleDepot"
	position = Ground.at(d.pos)
	rotation.y = atan2(-d.front.x, -d.front.y)  # (facing its front, as the stalls do)
	var prop := Node3D.new()
	add_child(prop)
	# the kiosk: open to the street (its front is -z, as a stand's), a back wall and two sides, the roof overhanging the counter;
	# the attendant stands inside, behind the counter (Premises.post)
	var wall := Color(0.86, 0.84, 0.78)
	Look.box(prop, Vector3(2.4, 2.2, 0.1), Vector3(0, 1.1, 2.0), wall)
	for x in [-1.15, 1.15]:
		Look.box(prop, Vector3(0.1, 2.2, 1.8), Vector3(x, 1.1, 1.1), wall)
	Look.box(prop, Vector3(2.8, 0.12, 2.6), Vector3(0, 2.26, 0.9), Color(0.25, 0.5, 0.32))
	Look.box(prop, Vector3(2.3, 0.95, 0.45), Vector3(0, 0.48, 0.3), Color(0.62, 0.5, 0.36))  # the counter
	Look.box(prop, Vector3(0.5, 0.3, 0.35), Vector3(0.7, 1.1, 0.3), Color(0.3, 0.32, 0.36))  # the till
	# crates of empties, stacked by the side, out front
	for k in 5:
		var at := Vector3(-1.75 - (k % 2) * 0.48, 0.16 + (k / 2) * 0.32, 0.2 + (k % 3) * 0.12)
		Look.box(prop, Vector3(0.44, 0.3, 0.32), at, CRATE)
		for b in 3:
			Look.box(prop, Vector3(0.07, 0.12, 0.07), at + Vector3(-0.13 + b * 0.13, 0.2, 0.0), GLASS)
	# the board, on the roof's front edge
	Look.box(prop, Vector3(1.6, 0.5, 0.06), Vector3(0, 2.65, -0.3), Color(0.2, 0.5, 0.3))
	var sign := Look.label3d(prop, "PFAND", Vector3(0, 2.65, -0.34), 64, 0.0)
	sign.modulate = Color(0.97, 0.97, 0.92)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED  # (painted on the board: it turns with the kiosk, and walls hide it)
	sign.fixed_size = false
	sign.no_depth_test = false
	sign.pixel_size = 0.005
	sign.outline_size = 0
	sign.rotation.y = PI  # (a label reads from +z: the street is -z)
	_board = Look.label3d(self, "", Vector3(0, 3.4, 0), 30, 18.0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 2.4, 2.4)
	Look.pick_area(self, box, Vector3(0, 1.2, 0.9), LAYER_MACHINE, "drone_uid", d.owner)  # (aiming at it is aiming at its attendant)
	_refresh()
	return self


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh()


func _refresh() -> void:
	_board.text = "%s · $%.2f a bottle\npaid out $%.0f for %d" % [depot.display_name(), Deposit.DEPOSIT, depot.paid_out, depot.taken_in]
