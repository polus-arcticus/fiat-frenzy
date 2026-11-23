## VIEW. Draws one Machine as a street stand (or a tent) with a price board. A machine that is not
## working is shown wrecked: tipped over or collapsed. It only reads the model.
class_name MachineView
extends Node3D

const HOT_DOG := preload("res://assets/models/hotdog_cart.glb")
const TENT := preload("res://assets/models/tent.glb")
const LAYER_MACHINE := 8

var machine: Machine
var world: World
var _prop: Node3D
var _extras: Node3D  # what stands beside the prop: the hostel's board
var _body: StaticBody3D  # what the hero bumps into (the machine's footprint)
var _kind := ""      # the kind the prop was built for
var _tents_drawn := 0  # a tent city: how many tents it was drawn with
var _board: Label3D
var _clock := 0.0
var _up := 0.0  # 0 wrecked .. 1 standing
var _grown := 1.0  # how much bigger it has got, with its level
var _loaves: Array[MeshInstance3D] = []  # bakery: the bread on the counter
var _sacks: Array[MeshInstance3D] = []   # bakery: the flour in the back


func setup(m: Machine, w: World, facing: float) -> MachineView:
	machine = m
	world = w
	position = Ground.at(m.pos)
	rotation.y = facing
	_board = Look.label3d(self, "", Vector3(0, 3.2, 0), 30, 15.0)
	_build_prop()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, 2.4)
	var pick := Look.pick_area(self, box, Vector3(0, 1.2, 0), LAYER_MACHINE, "drone_uid", m.owner)
	pick.set_meta("machine", m)
	_up = 1.0 if m.working else 0.0
	_grown = _size_for(m.level)
	_apply_pose()
	_refresh_board()
	return self


## Builds the look of the machine's kind; again when it changes (its owner built it up a tier: see Trades).
func _build_prop() -> void:
	for n in [_prop, _extras, _body]:
		if n != null:
			remove_child(n)
			n.queue_free()
	_body = Look.solid_body(self, machine.solid())  # (a tent's ground grows with its modules)
	var home := machine.residence
	if home != null:
		_board.position = Vector3((maxi(1, home.tents) - 1) * Residence.TENT_WIDTH * home.wing * 0.5, 3.2, 0)
	_loaves.clear()
	_sacks.clear()
	_kind = machine.kind
	name = "Machine_%s" % _kind
	_prop = Node3D.new()
	add_child(_prop)
	_extras = Node3D.new()  # (beside the prop, so they do not tip or sag with it)
	add_child(_extras)
	match _kind:
		"hot_dog_stand":
			_prop.add_child(Look.model(HOT_DOG))
		"tent", "hostel":
			_tent_modules()
			if _kind == "hostel":
				_hostel_sign()
		"lemonade_stand":
			_stall(Color(0.98, 0.86, 0.3), Color(1.0, 0.98, 0.9), Color(0.95, 0.9, 0.35))
		"bike_shop", "skate_shop":
			_shop_counter()
		"thrift_stall", "clothing_shop":  # a stall, and beside it a rail of coats
			if _kind == "thrift_stall":
				_stall(Color(0.55, 0.45, 0.6), Color(0.85, 0.8, 0.7), Color(0.55, 0.5, 0.38))
			else:
				_kiosk(Color(0.25, 0.38, 0.6))
			for x in [1.5, 2.9]:  # the rail's legs, beside the stall, the coats facing the street
				Look.box(_prop, Vector3(0.05, 1.6, 0.05), Vector3(x, 0.8, 0), Color(0.3, 0.3, 0.32))
			Look.box(_prop, Vector3(1.45, 0.05, 0.05), Vector3(2.2, 1.6, 0), Color(0.3, 0.3, 0.32))
			for k in 4:
				var cloth := Color(0.55, 0.5, 0.38).lerp(Color(0.25, 0.38, 0.6), float(k) / 3.0 if _kind == "clothing_shop" else 0.0)
				Look.box(_prop, Vector3(0.3, 0.8, 0.1), Vector3(1.68 + k * 0.34, 1.15, 0.0), cloth.darkened(0.1 * (k % 2)))
		"scrap_camp", "bike_camp":  # a tarp over a trestle, among the scrap
			_stall(Color(0.3, 0.4, 0.5), Color(0.5, 0.55, 0.58), Color(0.42, 0.36, 0.3))
			if _kind == "bike_camp":
				for side in [-1.0, 1.0]:  # an old bike stood up at either end of the trestle, ready to go
					WasteBinView.old_bike(_prop, Vector3(side * 1.7, 0.33, 0.2), Vector3(PI / 2.0, PI / 2.0, 0.1 * side))
		"bakery":
			_stall(Color(0.72, 0.38, 0.28), Color(0.96, 0.9, 0.78), Color(0.85, 0.65, 0.35), false)
			_bakery_goods()
		"bake_shop":
			_kiosk(Color(0.72, 0.38, 0.28))
			_bakery_goods()
		"burger_bar":
			_kiosk(Color(0.78, 0.18, 0.12))
		"coffee_stop":
			_kiosk(Color(0.36, 0.22, 0.14))


## The tent city: a tent for each person, side by side down its wing, with a cot in each. (No barrel: barrel fires are what the
## keeper sells, for the hero to place, and a tent city's warmth is its own: see Lodging.)
func _tent_modules() -> void:
	var home := machine.residence
	var n := maxi(1, home.tents)
	var step := Residence.TENT_WIDTH * home.wing
	for k in n:
		var section := Look.model(TENT)
		section.position = Vector3(k * step, 0, 0)
		_prop.add_child(section)
		Look.box(_prop, Vector3(0.42, 0.14, 0.7), Vector3(k * step, 0.12, 0.3), Color(0.42, 0.36, 0.3))  # a cot
	_tents_drawn = home.tents


## A tier 1 shop, for now on the stand's own ground: a kiosk, walled on three sides and roofed, its counter open to the street
## and a coloured sign band over it. (A shopfront in the block's wall, with rooms above, is to come.)
func _kiosk(sign_color: Color) -> void:
	var wall := Color(0.86, 0.84, 0.78)
	Look.box(_prop, Vector3(2.2, 0.95, 0.6), Vector3(0, 0.48, 0), sign_color.darkened(0.25))
	Look.box(_prop, Vector3(2.3, 0.06, 0.7), Vector3(0, 0.98, 0), Color(0.55, 0.4, 0.28))
	Look.box(_prop, Vector3(2.4, 2.5, 0.1), Vector3(0, 1.25, 0.45), wall)
	for side in [-1.0, 1.0]:
		Look.box(_prop, Vector3(0.1, 2.5, 0.9), Vector3(side * 1.15, 1.25, 0.0), wall)
	Look.box(_prop, Vector3(2.7, 0.12, 1.3), Vector3(0, 2.56, -0.05), Color(0.3, 0.3, 0.32))
	Look.box(_prop, Vector3(2.4, 0.42, 0.06), Vector3(0, 2.28, -0.47), sign_color)


## The hostel: the tent, with a painted board on two posts beside its door.
func _hostel_sign() -> void:
	var wood := Color(0.45, 0.33, 0.24)
	for x in [-1.55, -0.95]:
		Look.box(_extras, Vector3(0.08, 1.7, 0.08), Vector3(x, 0.85, -0.9), wood)
	Look.box(_extras, Vector3(0.8, 0.45, 0.05), Vector3(-1.25, 1.5, -0.92), Color(0.2, 0.42, 0.55))


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
	var leftovers: int = machine.input.count("leftovers")  # (the sacks by the counter: what the bread is made of)
	for k in _sacks.size():
		_sacks[k].visible = k < ceili(leftovers / 2.0)


## A stall gets 8% bigger for every level above the first, up to 60% bigger.
func _size_for(level: int) -> float:
	return 1.0 + minf(0.08 * (level - 1), 0.6)


func _process(delta: float) -> void:
	if machine.kind != _kind or (machine.residence != null and machine.residence.tents != _tents_drawn):
		_build_prop()
	_grown = move_toward(_grown, _size_for(machine.level), delta * 0.4)
	var goal := 1.0 if machine.working else 0.0
	_up = move_toward(_up, goal, delta * 0.8)
	_apply_pose()
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.5
		_refresh_board()
		_update_goods()


func _apply_pose() -> void:
	var tip := 1.0 - smoothstep(0.0, 1.0, _up)
	if machine.shelter != null:  # (a tent, a hostel: it sags rather than tips)
		_prop.scale = Vector3(_grown, _grown * lerpf(1.0, 0.22, tip), _grown)
	else:
		_prop.scale = Vector3.ONE * _grown
		_prop.rotation = Vector3(0, 0, 1.35 * tip)
		_prop.position.y = 0.45 * tip


func _refresh_board() -> void:
	var title := machine.display_name()
	if not machine.working:
		var owner_d := world.drone(machine.owner)
		_board.text = "%s\n(wrecked) needs $%d to repair" % [title, int(machine.repair_cost + Drone.RESERVE)]
		_board.modulate = Color(1.0, 0.8, 0.7)
		return
	_board.modulate = Color(1, 0.98, 0.92)
	var line := "%s  ·  Lv %d\n$%.2f  ·  %d left" % [title, machine.level, machine.price, machine.stock()]
	if machine.residence != null:  # (a home: what it holds, not what it sells)
		var free := world.lodging.free_tents(machine)
		line = "%s\n%d tents  ·  %s" % [title, machine.residence.tents, "%d empty: someone's coming" % free if free > 0 else "all lived in"]
	var mine := machine.equity.share(world.ledger.local)
	if mine > 0.0:
		line += "\nyou own %d%%" % roundi(mine * 100.0)
	_board.text = line
