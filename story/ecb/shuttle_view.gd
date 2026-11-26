## VIEW. The European Central Bank's visitor shuttle: a little golf cart, white with an EU-blue stripe, two benches under a
## canopy roof, a steering wheel with nobody at it (it drives itself). Long along its local Z (the front is +Z). The hero gets
## on from the right-hand side, into the front seat. Built from boxes; its body is solid so nobody walks through it.
class_name ShuttleView
extends VehicleView

const LENGTH := 2.9
const WIDTH := 1.25
const FLOOR := 0.3
const WHITE := Color(0.93, 0.93, 0.89)
const BLUE := Color(0.13, 0.28, 0.62)
const SEAT := Color(0.2, 0.24, 0.34)
const DARK := Color(0.12, 0.12, 0.14)
const SIDE := -1.0   # the side (local x) you get on from: the right, facing the front

## The hero's feet when they sit: the front seat, on the right, on the floor in front of the bench.
const SEAT_LOCAL := Vector3(SIDE * 0.28, FLOOR, 0.3)


func floor_height() -> float:
	return FLOOR


func setup(at: Vector2, yaw: float) -> ShuttleView:
	name = "Shuttle"
	place(at, yaw)
	_body()
	_seats()
	_roof()
	_wheels()
	var solid := StaticBody3D.new()  # you cannot walk through it, and a bill fired at it stops
	solid.collision_layer = 1
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 0.7, LENGTH)
	shape.shape = box
	shape.position = Vector3(0, 0.45, 0)
	solid.add_child(shape)
	add_child(solid)
	return self


func _body() -> void:
	Look.box(self, Vector3(WIDTH, 0.12, LENGTH - 0.1), Vector3(0, FLOOR - 0.06, 0), WHITE)                  # the floor
	Look.box(self, Vector3(WIDTH, 0.38, 0.75), Vector3(0, FLOOR + 0.19, LENGTH * 0.5 - 0.4), WHITE)         # the bonnet
	Look.box(self, Vector3(WIDTH - 0.1, 0.06, 0.5), Vector3(0, FLOOR + 0.41, LENGTH * 0.5 - 0.45), BLUE)    # (with a blue top)
	Look.box(self, Vector3(WIDTH, 0.36, 0.5), Vector3(0, FLOOR + 0.18, -LENGTH * 0.5 + 0.3), WHITE)         # the back
	for s in [-1.0, 1.0]:  # side panels, with the blue stripe
		Look.box(self, Vector3(0.05, 0.28, 1.9), Vector3(s * (WIDTH * 0.5 - 0.02), FLOOR + 0.14, -0.05), WHITE)
		Look.box(self, Vector3(0.055, 0.07, 1.9), Vector3(s * (WIDTH * 0.5 - 0.02), FLOOR + 0.2, -0.05), BLUE)
	for s in [-0.4, 0.4]:  # headlights
		Look.box(self, Vector3(0.18, 0.1, 0.05), Vector3(s, FLOOR + 0.3, LENGTH * 0.5 - 0.02), Color(1.0, 0.95, 0.7))
	Look.box(self, Vector3(0.04, 0.5, 0.04), Vector3(-SIDE * 0.28, FLOOR + 0.5, 0.78), DARK, Vector3(0.9, 0, 0))   # the steering column...
	Look.box(self, Vector3(0.32, 0.03, 0.32), Vector3(-SIDE * 0.28, FLOOR + 0.72, 0.66), DARK, Vector3(0.5, 0, 0)) # ...and the wheel


func _seats() -> void:
	Look.box(self, Vector3(WIDTH - 0.1, 0.12, 0.45), Vector3(0, FLOOR + 0.3, 0.3), SEAT)           # the front bench
	Look.box(self, Vector3(WIDTH - 0.1, 0.42, 0.1), Vector3(0, FLOOR + 0.62, 0.02), SEAT)
	Look.box(self, Vector3(WIDTH - 0.1, 0.12, 0.45), Vector3(0, FLOOR + 0.3, -0.7), SEAT)          # the back bench, facing backwards
	Look.box(self, Vector3(WIDTH - 0.1, 0.42, 0.1), Vector3(0, FLOOR + 0.62, -0.95), SEAT)


func _roof() -> void:
	for x in [-0.58, 0.58]:
		for z in [-1.0, 0.95]:
			Look.box(self, Vector3(0.05, 1.45, 0.05), Vector3(x, FLOOR + 0.72, z), DARK)
	Look.box(self, Vector3(WIDTH + 0.25, 0.07, LENGTH - 0.2), Vector3(0, FLOOR + 1.47, -0.05), WHITE)
	Look.box(self, Vector3(WIDTH + 0.27, 0.075, 0.35), Vector3(0, FLOOR + 1.47, -0.05 + (LENGTH - 0.2) * 0.5 - 0.17), BLUE)  # a blue band at the front


func _wheels() -> void:
	for x in [-0.6, 0.6]:
		for z in [0.9, -0.9]:
			Look.box(self, Vector3(0.14, 0.44, 0.44), Vector3(x, 0.22, z), DARK)


func seat_local() -> Vector3:
	return SEAT_LOCAL


## Where to stand, outside, to get on: out from the right-hand side, level with the front seat.
func kerb_point() -> Vector3:
	return to_global(Vector3(SIDE * 1.7, 0.0, 0.3))


## The way in: at the side of the front seat.
func doorway_point() -> Vector3:
	return to_global(Vector3(SIDE * 0.75, FLOOR, 0.3))
