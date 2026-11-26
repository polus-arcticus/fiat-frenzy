## VIEW PART. A runner's pedal bike and the trailer behind it, built from boxes, under and behind whoever rides it (the drone's
## view faces -Z). The trailer's crates show what is in it, as a cart's do (CartView).
class_name BikeTrailerView
extends Node3D

const SADDLE := 0.22        # how far the rider stands up off the ground, over the pedals
const FRAME := Color(0.12, 0.45, 0.55)
const TYRE := Color(0.12, 0.12, 0.14)
const BED := Color(0.55, 0.40, 0.28)
const SPOKE := Color(0.7, 0.72, 0.76)
const RIM := 12             # lengths to a tyre
const LEAN := 0.38          # the rider leans in over the handlebars (radians)
const CRATES := 8

var _cargo: Array[MeshInstance3D] = []


func _init() -> void:
	name = "BikeTrailer"
	for z in [-0.62, 0.55]:  # the wheels: a rim of eight spokes' ends each
		_wheel(Vector3(0, 0.32, z), 0.32)
	Look.box(self, Vector3(0.05, 0.05, 1.0), Vector3(0, 0.42, -0.03), FRAME, Vector3(0.12, 0, 0))   # the bottom tube...
	Look.box(self, Vector3(0.05, 0.05, 0.85), Vector3(0, 0.66, -0.05), FRAME)                         # ...the top tube
	Look.box(self, Vector3(0.05, 0.62, 0.05), Vector3(0, 0.62, 0.25), FRAME, Vector3(0.22, 0, 0))    # the seat post
	Look.box(self, Vector3(0.2, 0.05, 0.28), Vector3(0, 0.94, 0.34), TYRE)                            # the saddle
	Look.box(self, Vector3(0.05, 0.75, 0.05), Vector3(0, 0.67, -0.52), FRAME, Vector3(-0.2, 0, 0))   # the fork
	Look.box(self, Vector3(0.55, 0.04, 0.04), Vector3(0, 1.04, -0.42), TYRE)                          # the handlebars
	Look.box(self, Vector3(0.04, 0.04, 0.55), Vector3(0, 0.34, 0.9), Color(0.6, 0.62, 0.66))         # the tow bar
	Look.box(self, Vector3(0.82, 0.07, 1.1), Vector3(0, 0.4, 1.7), BED)                               # the trailer's bed...
	for side in [-1.0, 1.0]:
		Look.box(self, Vector3(0.05, 0.28, 1.1), Vector3(side * 0.41, 0.57, 1.7), BED.darkened(0.15))
		_wheel(Vector3(side * 0.5, 0.26, 1.8), 0.26)
	for end in [1.16, 2.24]:
		Look.box(self, Vector3(0.82, 0.28, 0.05), Vector3(0, 0.57, end), BED.darkened(0.15))
	for k in CRATES:
		_cargo.append(Look.box(self, Vector3(0.32, 0.26, 0.28), Vector3(-0.18 + (k % 2) * 0.36, 0.58 + (k / 6) * 0.27, 1.38 + ((k / 2) % 3) * 0.32), Color.WHITE))
		_cargo[k].visible = false


## A tyre as a ring of short lengths, with two spokes and a hub.
func _wheel(at: Vector3, radius: float) -> void:
	for k in RIM:
		var turn := TAU * k / RIM
		Look.box(self, Vector3(0.06, 0.07, TAU * radius / RIM * 1.1), at + Vector3(0, cos(turn), sin(turn)) * radius, TYRE, Vector3(turn, 0, 0))
	for turn in [0.4, 0.4 + PI * 0.5]:
		Look.box(self, Vector3(0.02, radius * 1.9, 0.02), at, SPOKE, Vector3(turn, 0, 0))
	Look.box(self, Vector3(0.09, 0.09, 0.09), at, SPOKE)


func slots() -> int:
	return _cargo.size()


## Shows crates for the biggest load in the trailer (a crate to each eighth of what it holds, or part of one).
func refresh(drone: Drone) -> void:
	var item := ""
	var units := 0
	var cart: Inventory = drone.runner.cart if drone.runner != null else Inventory.new()
	for it in cart.counts:
		if cart.count(it) > units:
			item = it
			units = cart.count(it)
	var each: float = float(drone.runner.rig().load) / CRATES if drone.runner != null else 1.0
	for k in _cargo.size():
		_cargo[k].visible = units > 0 and k < ceili(units / each)
		if _cargo[k].visible:
			_cargo[k].material_override = Look.tinted(CartView.CARGO_COLORS.get(item, Color(0.7, 0.6, 0.5)))
