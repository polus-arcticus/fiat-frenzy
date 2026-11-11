## VIEW. A bicycle built from primitives in the paper-and-ink style: two tyres (tori), a frame of boxes,
## a fork, handlebars and a saddle. It faces -z (forward), standing on the ground at the origin, about
## 1.7 m long. Used for the bike in the shop, the one parked in the street and (the front end) in your hands.
class_name BikeModel
extends RefCounted

const TYRE := Color(0.14, 0.14, 0.16)
const RIM := Color(0.75, 0.77, 0.8)
const WHEEL_Y := 0.34
const FRAMES: Array[Color] = [Color(0.86, 0.24, 0.2), Color(0.2, 0.5, 0.78), Color(0.95, 0.7, 0.2), Color(0.3, 0.65, 0.4)]


## A whole bike. `frame` is the paint.
static func build(frame: Color) -> Node3D:
	var b := Node3D.new()
	b.name = "Bike"
	wheel(b, Vector3(0, WHEEL_Y, 0.6))
	wheel(b, Vector3(0, WHEEL_Y, -0.6))
	Look.box(b, Vector3(0.04, 0.04, 0.72), Vector3(0, 0.89, -0.07), frame)                       # top tube
	Look.box(b, Vector3(0.045, 0.045, 0.76), Vector3(0, 0.575, -0.16), frame, Vector3(0.81, 0, 0))  # down tube
	Look.box(b, Vector3(0.04, 0.62, 0.04), Vector3(0, 0.6, 0.19), frame, Vector3(0.29, 0, 0))      # seat tube
	Look.box(b, Vector3(0.03, 0.04, 0.5), Vector3(-0.05, 0.32, 0.35), frame)                    # chain stays
	Look.box(b, Vector3(0.03, 0.04, 0.5), Vector3(0.05, 0.32, 0.35), frame)
	Look.box(b, Vector3(0.04, 0.66, 0.04), Vector3(0, 0.65, -0.525), RIM, Vector3(0.24, 0, 0))   # fork
	Look.box(b, Vector3(0.52, 0.03, 0.03), Vector3(0, 1.0, -0.45), TYRE)                         # handlebars
	Look.box(b, Vector3(0.12, 0.05, 0.26), Vector3(0, 0.96, 0.3), TYRE)                          # saddle
	Look.box(b, Vector3(0.16, 0.03, 0.03), Vector3(0, 0.3, 0.1), RIM)                            # cranks
	return b


## One tyre standing in the y-z plane, with a rim and a pair of spokes.
static func wheel(parent: Node3D, at: Vector3) -> void:
	var tyre := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.36
	torus.rings = 16
	torus.ring_segments = 8
	tyre.mesh = torus
	tyre.material_override = Look.tinted(TYRE)
	tyre.position = at
	tyre.rotation = Vector3(0, 0, PI / 2.0)
	parent.add_child(tyre)
	Look.box(parent, Vector3(0.02, 0.6, 0.02), at, RIM)
	Look.box(parent, Vector3(0.02, 0.02, 0.6), at, RIM)
	Look.box(parent, Vector3(0.05, 0.05, 0.05), at, RIM)
