## VIEW PART. A runner's shopping cart: a clean steel cart built from boxes, pushed in front of them, with room
## for four chunky crates of cargo that show what is in the drone's cart. (The cart model from the old game
## has a scavenger's trash bag in its mesh, so this one is built from boxes.)
class_name CartView
extends Node3D

const CARGO_COLORS := {"flour": Color(0.95, 0.93, 0.86), "bottled_water": Color(0.55, 0.78, 0.95), "sugar": Color(0.98, 0.98, 0.96), "protein": Color(0.92, 0.55, 0.55)}

var _cargo: Array[MeshInstance3D] = []


func _init() -> void:
	name = "Cart"
	position = Vector3(0, 0, -0.95)
	var steel := Color(0.66, 0.68, 0.72)
	Look.box(self, Vector3(0.6, 0.05, 0.9), Vector3(0, 0.3, 0), steel)
	for side in [-1.0, 1.0]:
		Look.box(self, Vector3(0.04, 0.38, 0.9), Vector3(side * 0.3, 0.5, 0), steel)
		Look.box(self, Vector3(0.04, 0.55, 0.04), Vector3(side * 0.28, 0.75, 0.46), steel)
		for z in [-0.36, 0.36]:
			Look.box(self, Vector3(0.07, 0.13, 0.13), Vector3(side * 0.25, 0.1, z), Color(0.15, 0.15, 0.17))
	Look.box(self, Vector3(0.6, 0.38, 0.04), Vector3(0, 0.5, -0.45), steel)
	Look.box(self, Vector3(0.62, 0.05, 0.05), Vector3(0, 1.03, 0.46), Color(0.82, 0.2, 0.18))
	for k in 4:
		_cargo.append(Look.box(self, Vector3(0.28, 0.26, 0.28), Vector3(-0.14 + (k % 2) * 0.3, 0.46, -0.2 + (k / 2) * 0.32), Color.WHITE))
		_cargo[k].visible = false


func slots() -> int:
	return _cargo.size()


## Shows crates for the biggest load in the drone's cart (one crate per three units).
func refresh(drone: Drone) -> void:
	var item := ""
	var units := 0
	for it in drone.cart.counts:
		if drone.cart.count(it) > units:
			item = it
			units = drone.cart.count(it)
	for k in _cargo.size():
		_cargo[k].visible = units > 0 and k < ceili(units / 3.0)
		if _cargo[k].visible:
			_cargo[k].material_override = Look.tinted(CARGO_COLORS.get(item, Color(0.7, 0.6, 0.5)))
