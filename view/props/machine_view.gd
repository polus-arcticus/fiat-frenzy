## VIEW. Draws one Machine as a street stand (or a tent) with a price board. A machine that is not
## working is shown wrecked: tipped over or collapsed. It only reads the model.
class_name MachineView
extends Node3D

const HOT_DOG := preload("res://assets/models/hotdog_cart.glb")
const TENT := preload("res://assets/models/tent.glb")
const BARREL := preload("res://assets/models/fire_barrel.glb")
const LAYER_MACHINE := 8

var machine: Machine
var world: World
var _prop: Node3D
var _board: Label3D
var _light: OmniLight3D
var _clock := 0.0
var _up := 0.0  # 0 wrecked .. 1 standing
var _grown := 1.0  # how much bigger it has got, with its level
var _loaves: Array[MeshInstance3D] = []  # bakery: the bread on the counter
var _sacks: Array[MeshInstance3D] = []   # bakery: the flour in the back


func setup(m: Machine, w: World, facing: float) -> MachineView:
	machine = m
	world = w
	name = "Machine_%s" % m.kind
	position = Vector3(m.pos.x, 0, m.pos.y)
	rotation.y = facing
	_prop = Node3D.new()
	add_child(_prop)
	match m.kind:
		"hot_dog_stand":
			_prop.add_child(Look.model(HOT_DOG))
		"tent":
			_prop.add_child(Look.model(TENT))
			var barrel := Look.model(BARREL)
			barrel.position = Vector3(1.6, 0, 0.6)
			add_child(barrel)
			_light = OmniLight3D.new()
			_light.position = Vector3(1.6, 1.2, 0.6)
			_light.omni_range = 9.0
			_light.light_color = Color(1.0, 0.6, 0.3)
			_light.light_energy = 0.0
			add_child(_light)
		"lemonade_stand":
			_stall(Color(0.98, 0.86, 0.3), Color(1.0, 0.98, 0.9), Color(0.95, 0.9, 0.35))
		"bike_shop", "skate_shop":
			_shop_counter()
		"bakery":
			_stall(Color(0.72, 0.38, 0.28), Color(0.96, 0.9, 0.78), Color(0.85, 0.65, 0.35), false)
			_bakery_goods()
	_board = Look.label3d(self, "", Vector3(0, 3.2, 0), 30, 15.0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, 2.4)
	var pick := Look.pick_area(self, box, Vector3(0, 1.2, 0), LAYER_MACHINE, "drone_id", m.owner_id)
	pick.set_meta("machine", m)
	Look.solid_body(self, m.solid())
	_up = 1.0 if m.working else 0.0
	_grown = _size_for(m.level)
	_apply_pose()
	_refresh_board()
	return self


## A market stall from boxes: counter, posts, striped awning, a crate of goods.
func _stall(awning_a: Color, awning_b: Color, goods: Color, crates := true) -> void:
	Look.box(_prop, Vector3(2.2, 0.95, 0.9), Vector3(0, 0.48, 0), Color(0.55, 0.4, 0.28))
	Look.box(_prop, Vector3(0.12, 2.2, 0.12), Vector3(-1.05, 1.1, -0.5), Color(0.45, 0.33, 0.24))
	Look.box(_prop, Vector3(0.12, 2.2, 0.12), Vector3(1.05, 1.1, -0.5), Color(0.45, 0.33, 0.24))
	for k in 6:
		Look.box(_prop, Vector3(0.38, 0.06, 1.5), Vector3(-0.95 + k * 0.38, 2.28, -0.1), awning_a if k % 2 == 0 else awning_b, Vector3(0.18, 0, 0))
	if crates:
		Look.box(_prop, Vector3(0.7, 0.35, 0.5), Vector3(-0.5, 1.12, 0), goods)
		Look.box(_prop, Vector3(0.5, 0.25, 0.4), Vector3(0.55, 1.07, 0.05), goods.darkened(0.2))


## The bike shop's counter: a long wooden counter with a till on it.
func _shop_counter() -> void:
	var wood := Color(0.55, 0.4, 0.28)
	Look.box(_prop, Vector3(3.2, 0.95, 0.9), Vector3(0, 0.48, 0), wood)
	Look.box(_prop, Vector3(3.3, 0.06, 1.0), Vector3(0, 0.98, 0), wood.lightened(0.2))
	Look.box(_prop, Vector3(0.42, 0.22, 0.32), Vector3(-1.1, 1.14, 0.1), Color(0.25, 0.27, 0.3))
	Look.box(_prop, Vector3(0.3, 0.2, 0.04), Vector3(-1.1, 1.38, 0.2), Color(0.3, 0.5, 0.45), Vector3(-0.5, 0, 0))
	Look.box(_prop, Vector3(0.5, 0.04, 0.3), Vector3(0.9, 1.03, 0.0), Color(0.9, 0.86, 0.7))  # a leaflet or two


## The bakery shows its two inventories: loaves on the counter (its output) and flour sacks stacked
## behind it (its input), so you can see at a glance what it has and what it's short of.
func _bakery_goods() -> void:
	for k in 10:
		var x := -0.9 + (k % 5) * 0.45
		var z := -0.15 if k < 5 else 0.2
		_loaves.append(Look.blob(_prop, Vector3(0.42, 0.22, 0.28), Vector3(x, 1.08, z), Color(0.84, 0.6, 0.3)))
	for k in 4:
		var sack := Look.blob(_prop, Vector3(0.52, 0.66, 0.42), Vector3(-1.55 + (k % 2) * 0.6, 0.34 + (k / 2) * 0.62, -0.2), Color(0.95, 0.93, 0.86))
		_sacks.append(sack)


func _update_goods() -> void:
	if _loaves.is_empty():
		return
	for k in _loaves.size():
		_loaves[k].visible = k < ceili(machine.stock() / 5.0)  # a full 50-loaf shelf fills the counter
	var flour: int = machine.input.count("flour")
	for k in _sacks.size():
		_sacks[k].visible = k < ceili(flour / 2.0)


## A stall gets 8% bigger for every level above the first, up to 60% bigger.
func _size_for(level: int) -> float:
	return 1.0 + minf(0.08 * (level - 1), 0.6)


func _process(delta: float) -> void:
	_grown = move_toward(_grown, _size_for(machine.level), delta * 0.4)
	var goal := 1.0 if machine.working else 0.0
	_up = move_toward(_up, goal, delta * 0.8)
	_apply_pose()
	if _light:
		_light.light_energy = (1.8 + sin(Time.get_ticks_msec() * 0.011) * 0.4) * _up
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh_board()
		_update_goods()


func _apply_pose() -> void:
	var tip := 1.0 - smoothstep(0.0, 1.0, _up)
	if machine.kind == "tent":
		_prop.scale = Vector3(_grown, _grown * lerpf(1.0, 0.22, tip), _grown)
	else:
		_prop.scale = Vector3.ONE * _grown
		_prop.rotation = Vector3(0, 0, 1.35 * tip)
		_prop.position.y = 0.45 * tip


func _refresh_board() -> void:
	var title := machine.display_name()
	if not machine.working:
		var owner_d := world.drones[machine.owner_id]
		_board.text = "%s\n(wrecked) needs $%d to repair" % [title, int(machine.repair_cost + Needs.RESERVE)]
		_board.modulate = Color(1.0, 0.8, 0.7)
		return
	_board.modulate = Color(1, 0.98, 0.92)
	var line := "%s  ·  Lv %d\n$%.2f  ·  %d left" % [title, machine.level, machine.price, machine.stock()]
	if machine.equity.stake > 0.0:
		line += "\nyou own %d%%" % roundi(machine.equity.stake * 100.0)
	_board.text = line
