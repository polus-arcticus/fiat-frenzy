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
var _skeleton: Skeleton3D
var _held := false  # the clips are paused: a pose is set bone by bone (cross_legs)
const CROSS := -0.8  # radians the top (right) thigh turns across the other: its knee in front of the other leg


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
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] if not skeletons.is_empty() else null
	if _anim:
		for clip in ["Idle", "Walk"]:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return self


## The recovery position, `w` of the way into it (0..1): lying on the left side, the top (right) leg bent at hip and knee and
## brought over the other, the knee on the ground in front. The clips are paused while it's held; 0 lets them play again.
func cross_legs(w: float) -> void:
	if _skeleton == null or _anim == null:
		return
	if w <= 0.0:
		if _held:
			_held = false
			_skeleton.reset_bone_poses()
			_anim.play(_playing if _playing != "" else "Idle")
		return
	if not _held:
		_held = true
		_anim.pause()
	_bend("thigh.R", Vector3(-1.4 * w, 0.0, CROSS * w))  # the top leg: up at the hip, and across
	_bend("shin.R", Vector3(1.6 * w, 0.0, 0.0))          # bent at the knee
	_bend("thigh.L", Vector3(-0.35 * w, 0.0, 0.0))       # the one underneath, a little bent
	_bend("shin.L", Vector3(0.5 * w, 0.0, 0.0))
	_bend("upper_arm.R", Vector3(-0.9 * w, 0.0, 0.0))    # the top arm forward, to prop the head


func _bend(bone: String, euler: Vector3) -> void:
	var i := _skeleton.find_bone(bone)
	if i < 0:
		return
	var rest := _skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(i, rest * Quaternion.from_euler(euler))


## `speed` is how fast the body is moving along the ground, in metres a second.
func refresh(speed: float) -> void:
	if _anim == null or _held:
		return
	var clip := "Walk" if speed > 0.3 else "Idle"
	if clip != _playing and _anim.has_animation(clip):
		_playing = clip
		_anim.play(clip, 0.2)
	_anim.speed_scale = clampf(speed / 1.6, 0.8, 3.0) if clip == "Walk" else 1.0
