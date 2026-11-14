## VIEW. What you see of the bike while riding: the handlebars with your hands on the grips, a bit of frame
## and the front wheel, down at the bottom of the screen. It hangs on the camera and sways a little with speed.
class_name BikeRig
extends Node3D

const SKIN := Color(0.85, 0.66, 0.52)

var _t := 0.0


func setup() -> BikeRig:
	name = "BikeRig"
	visible = false
	var frame := BikeModel.FRAMES[0]
	Look.box(self, Vector3(0.62, 0.035, 0.035), Vector3(0, 0, 0), BikeModel.TYRE)       # handlebars
	Look.box(self, Vector3(0.05, 0.05, 0.12), Vector3(-0.3, 0, 0.04), BikeModel.TYRE)  # grips
	Look.box(self, Vector3(0.05, 0.05, 0.12), Vector3(0.3, 0, 0.04), BikeModel.TYRE)
	Look.box(self, Vector3(0.07, 0.05, 0.08), Vector3(-0.3, 0.01, 0.06), SKIN)           # hands
	Look.box(self, Vector3(0.07, 0.05, 0.08), Vector3(0.3, 0.01, 0.06), SKIN)
	Look.box(self, Vector3(0.05, 0.3, 0.05), Vector3(0, -0.15, -0.02), BikeModel.RIM, Vector3(0.2, 0, 0))  # stem and fork going down
	Look.box(self, Vector3(0.05, 0.05, 0.55), Vector3(0, -0.28, -0.3), frame, Vector3(0.28, 0, 0))        # top of the frame ahead
	var tyre := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.36
	tyre.mesh = torus
	tyre.material_override = Look.tinted(BikeModel.TYRE)
	tyre.position = Vector3(0, -0.5, -0.6)
	tyre.rotation = Vector3(0, 0, PI / 2.0)
	add_child(tyre)
	return self


## `speed` is how fast the player is going (m/s); it sways more the faster they go.
func update(speed: float, delta: float) -> void:
	_t += delta * (2.0 + speed * 0.6)
	var amount := clampf(speed / 10.0, 0.0, 1.0)
	rotation.z = sin(_t) * 0.035 * amount
	rotation.x = -0.12 + sin(_t * 2.0) * 0.012 * amount
