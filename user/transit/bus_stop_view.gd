## VIEW. The bus stop: a shelter on the pavement by the door (a roof on two posts, a glass back, a bench), a sign on a pole,
## and the bay painted on the road where the bus pulls up. It stands in the bus's own frame at the stop: the bus's front
## is +Z and its door is on its right, the pavement side, so everything is built to that side. It only decorates.
class_name BusStopView
extends Node3D

const POST := Color(0.2, 0.22, 0.26)
const GLASS := Color(0.62, 0.76, 0.84, 0.3)
const PAINT := Color(0.94, 0.94, 0.9)
const SIGN := Color(0.96, 0.86, 0.28)


## `at` is where the bus waits (the middle of its lane), `yaw` as BusView turns, `lane_to_kerb` how far the lane's middle is
## from the kerb.
func setup(at: Vector2, yaw: float, lane_to_kerb: float) -> BusStopView:
	name = "BusStop"
	position = Vector3(at.x, 0.0, at.y)
	rotation.y = yaw
	var door_x := BusView.DOOR_SIDE  # which way the pavement is, in the bus's frame (-1: its right)
	var kerb := door_x * lane_to_kerb
	var z := BusView.DOOR_Z
	# the shelter, back from the kerb by a metre and a half
	var back := kerb + door_x * 2.7
	for dz in [-1.5, 1.5]:
		Look.box(self, Vector3(0.1, 2.5, 0.1), Vector3(kerb + door_x * 1.1, 1.25, z + dz), POST)
	Look.box(self, Vector3(1.9, 0.1, 3.5), Vector3(kerb + door_x * 1.9, 2.55, z), Color(0.3, 0.55, 0.42))  # the roof
	for dz in [-1.55, 1.55]:  # the back: two posts and a rail round the glass, so you can see through
		Look.box(self, Vector3(0.07, 2.1, 0.07), Vector3(back, 1.1, z + dz), POST)
	Look.box(self, Vector3(0.07, 0.07, 3.2), Vector3(back, 2.1, z), POST)
	var pane := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 1.8, 3.1)
	pane.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = GLASS
	pane.material_override = mat
	pane.position = Vector3(back, 1.15, z)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pane)
	Look.box(self, Vector3(0.45, 0.07, 2.2), Vector3(back - door_x * 0.45, 0.5, z), Color(0.5, 0.36, 0.24))  # a bench
	Look.box(self, Vector3(0.45, 0.45, 0.07), Vector3(back - door_x * 0.45, 0.25, z - 0.9), POST)
	Look.box(self, Vector3(0.45, 0.45, 0.07), Vector3(back - door_x * 0.45, 0.25, z + 0.9), POST)
	# the sign: a pole at the front end of the bay with a round yellow board
	var pole := kerb + door_x * 0.7
	var pz := z + 2.9
	Look.box(self, Vector3(0.08, 3.0, 0.08), Vector3(pole, 1.5, pz), POST)
	var board := Look.box(self, Vector3(0.1, 0.9, 0.9), Vector3(pole, 3.05, pz), SIGN)
	board.rotation.z = 0.0
	var label := Look.label3d(self, "BUS", Vector3(pole + door_x * -0.1, 3.05, pz), 36, 60.0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.fixed_size = false
	label.pixel_size = 0.004
	label.no_depth_test = false
	label.rotation.y = -door_x * PI * 0.5
	Look.label3d(self, "EZB  Ostend", Vector3(pole, 3.9, pz), 24, 30.0)
	# the bay painted on the road: a line along the kerb side of the lane and a line across each end, and BUS on the tarmac
	var near := door_x * (lane_to_kerb - 0.12)
	Look.box(self, Vector3(0.12, 0.012, 13.0), Vector3(near, 0.035, 0.0), PAINT)
	for end in [-6.5, 6.5]:
		Look.box(self, Vector3(1.0, 0.012, 0.12), Vector3(near - door_x * 0.5, 0.035, end), PAINT)
	var paint := Label3D.new()
	paint.text = "BUS"
	paint.font_size = 90
	paint.pixel_size = 0.012
	paint.modulate = PAINT
	paint.double_sided = true
	paint.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	paint.rotation = Vector3(-PI * 0.5, 0.0, PI * 0.5 * -door_x)
	paint.position = Vector3(near * 0.4, 0.04, -4.4)
	add_child(paint)
	return self
