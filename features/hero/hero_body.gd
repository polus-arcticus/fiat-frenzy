## VIEW. The hero's body, drawn when the camera is behind them (third person): a character model that stands and walks.
## In first person it is hidden. It reads nothing from the model: the player controller tells it how fast the body is
## going, and it plays the idle or the walk to match. The model faces -Z, as the player body does.
class_name HeroBody
extends Node3D

## The hero is the one character nobody else shares: a black tee and grey trousers, not hi-vis or a suit.
const MODEL := preload("res://assets/models/dealer.glb")

var _model: Node3D
var _anim: AnimationPlayer
var _playing := ""


func setup() -> HeroBody:
	name = "HeroBody"
	_model = Look.model(MODEL)
	# The models are made facing +z (the glTF way), but the player body faces -z, so the model is spun half a turn.
	var flip := Node3D.new()
	flip.name = "Facing"
	flip.rotation.y = PI
	add_child(flip)
	flip.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for clip in ["Idle", "Walk"]:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return self


## `speed` is how fast the body is moving along the ground, in metres a second.
func refresh(speed: float) -> void:
	if _anim == null:
		return
	var clip := "Walk" if speed > 0.3 else "Idle"
	if clip != _playing and _anim.has_animation(clip):
		_playing = clip
		_anim.play(clip, 0.2)
	_anim.speed_scale = clampf(speed / 1.6, 0.8, 3.0) if clip == "Walk" else 1.0
