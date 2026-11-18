## VIEW. The skateboard under the hero's feet: a deck with a kicked-up nose and tail, grip tape, trucks and four wheels. It
## lies along the way the hero is heading. It can crouch with the ollie's wind-up, tip its nose up in a jump and spin
## through a kickflip. Reads nothing from the model: the skate controller tells it what to do.
class_name BoardView
extends Node3D

const DECK := Color(0.9, 0.52, 0.2)
const GRIP := Color(0.12, 0.12, 0.14)
const WHEEL := Color(0.95, 0.93, 0.85)
const TRUCK := Color(0.62, 0.62, 0.66)

var _spin: Node3D   # the part that rolls over in a kickflip
var _tween: Tween


func setup() -> BoardView:
	name = "Board"
	_spin = Node3D.new()
	_spin.position.y = 0.11
	add_child(_spin)
	# the deck lies along -Z, the way the hero faces; its ends kick up
	Look.box(_spin, Vector3(0.24, 0.035, 0.5), Vector3(0, 0, 0), DECK)
	Look.box(_spin, Vector3(0.22, 0.036, 0.46), Vector3(0, 0.003, 0), GRIP)
	for end in [-1.0, 1.0]:
		var kick := Look.box(_spin, Vector3(0.24, 0.035, 0.16), Vector3(0, 0.035, end * 0.31), DECK)
		kick.rotation.x = end * deg_to_rad(-24.0)
	for z in [-0.26, 0.26]:
		Look.box(_spin, Vector3(0.2, 0.03, 0.06), Vector3(0, -0.04, z), TRUCK)
		for x in [-0.1, 0.1]:
			Look.box(_spin, Vector3(0.04, 0.07, 0.07), Vector3(x * 1.15, -0.065, z), WHEEL)
	visible = false
	return self


## Rolls the board over once, along its length, in `seconds`.
func kickflip(seconds := 0.45) -> void:
	if _tween != null:
		_tween.kill()
	_spin.rotation.z = 0.0
	_tween = create_tween()
	_tween.tween_property(_spin, "rotation:z", TAU, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _spin.rotation.z = 0.0)


## Tips the nose up (positive) or down, in radians: leaving the ground and landing.
func pitch(radians: float) -> void:
	_spin.rotation.x = lerp_angle(_spin.rotation.x, radians, 0.25)
