## VIEW. The medical tent: a white open-fronted tent with a red cross, and a cot for each bed. It only
## reads the model (the sign says how many beds are free).
class_name HospitalView
extends Node3D

var hospital: Hospital
var _board: Label3D
var _clock := 0.0


func setup(h: Hospital, facing: float) -> HospitalView:
	hospital = h
	name = "MedicalTent"
	position = Vector3(h.pos.x, 0, h.pos.y)
	rotation.y = facing
	var white := Color(0.95, 0.95, 0.92)
	var red := Color(0.82, 0.12, 0.14)
	var prop := Node3D.new()
	add_child(prop)
	Look.box(prop, Vector3(4.8, 0.08, 3.8), Vector3(0, 0.04, 0.1), Color(0.78, 0.78, 0.74))  # groundsheet
	Look.box(prop, Vector3(4.8, 2.3, 0.08), Vector3(0, 1.2, 1.95), white)                     # back wall
	for side in [-1.0, 1.0]:
		Look.box(prop, Vector3(0.08, 2.0, 3.8), Vector3(side * 2.4, 1.05, 0.1), white)       # side walls
		Look.box(prop, Vector3(2.9, 0.07, 4.2), Vector3(side * 1.15, 2.55, 0.1), white if side < 0 else Color(0.9, 0.9, 0.87), Vector3(0, 0, -side * 0.42))
	Look.box(prop, Vector3(1.2, 0.5, 0.06), Vector3(0, 2.15, -1.8), white)                     # lintel over the open front
	Look.box(prop, Vector3(0.22, 0.8, 0.05), Vector3(0, 2.15, -1.84), red)
	Look.box(prop, Vector3(0.8, 0.22, 0.05), Vector3(0, 2.15, -1.84), red)
	# the ambulance's bay, painted on the road in front: in the tent's own frame the bay is a few metres out and along
	var bay := hospital.bay() - hospital.pos
	var local := Vector2(bay.dot(Vector2(-hospital.front.y, hospital.front.x)), -bay.dot(hospital.front))  # (x across, z back)
	var paint := Color(0.94, 0.94, 0.9)
	for e in [-1.4, 1.4]:  # (the bay is long along the street, which is the tent's x axis)
		Look.box(prop, Vector3(6.4, 0.012, 0.12), Vector3(local.x, 0.035, local.y + e), paint)
	for e in [-3.2, 3.2]:
		Look.box(prop, Vector3(0.12, 0.012, 2.9), Vector3(local.x + e, 0.035, local.y), paint)
	var ground := Label3D.new()
	ground.text = "AMBULANCE"
	ground.font_size = 80
	ground.pixel_size = 0.012
	ground.modulate = paint
	ground.double_sided = true
	ground.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ground.rotation = Vector3(-PI * 0.5, PI, 0.0)  # lying flat, reading along the bay from the road
	ground.position = Vector3(local.x, 0.04, local.y - 0.2)
	prop.add_child(ground)
	for i in Hospital.BEDS:
		var x := -1.35 + 0.9 * float(i)
		Look.box(prop, Vector3(0.7, 0.12, 1.9), Vector3(x, 0.38, 0.2), Color(0.55, 0.6, 0.66))
		Look.box(prop, Vector3(0.62, 0.05, 1.7), Vector3(x, 0.47, 0.2), Color(0.88, 0.9, 0.92))
		for lx in [-0.3, 0.3]:
			for lz in [-0.7, 1.1]:
				Look.box(prop, Vector3(0.05, 0.34, 0.05), Vector3(x + lx, 0.17, lz), Color(0.4, 0.42, 0.46))
	Look.solid_body(self, h.solid(), 2.0)
	_board = Look.label3d(self, "", Vector3(0, 3.5, 0), 34, 24.0)
	_refresh()
	return self


func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh()


func _refresh() -> void:
	_board.text = "MEDICAL TENT\n%d of %d beds free" % [hospital.free_beds(), Hospital.BEDS]
