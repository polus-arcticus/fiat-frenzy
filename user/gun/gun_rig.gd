## VIEW. The money gun in the player's hands. The model is a skinned mesh with five bones (gun, trigger,
## drum, bill, panel) and three clips (Idle, Fire, Jam). Here the bones are also driven from code, after the
## clips have played, for the things the clips don't have:
##   charging  the drum spins up faster and faster, the trigger is held back, the whole gun starts to shake
##   switching the gun rolls over once, the panel tilts to show the mode, and the drum clicks round
## While a Fire or Jam clip is playing it is left alone. It only reads what the controller tells it.
class_name GunRig
extends Node3D

const GUN := preload("res://assets/models/money_gun.glb")
const PANEL_ANGLE := {"gift": 90.0, "invest": 48.0}  # degrees: the panel's flat (gift) or tipped up (invest)
const ROLL_TIME := 0.34

var model: Node3D
var muzzle: Marker3D
## 0..1, set by the controller while it charges a contract.
var charge := 0.0
var mode := "gift"

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _bones := {}
var _rest := {}     # bone -> its rest transform
var _roll := -1.0   # seconds into a roll, or -1
var _drum := 0.0    # the drum's extra spin, radians
var _panel := 90.0  # degrees now


func setup() -> GunRig:
	name = "GunRig"
	process_priority = 10  # after the animation player, so the code wins where it means to
	model = Look.model(GUN)
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim:
		_anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")
		_anim.animation_finished.connect(func(_n): _anim.play("Idle", 0.15))
	_skeleton = model.find_child("Skeleton3D", true, false)
	if _skeleton:
		for i in _skeleton.get_bone_count():
			_bones[_skeleton.get_bone_name(i)] = i
			_rest[_skeleton.get_bone_name(i)] = _skeleton.get_bone_rest(i)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.02, -0.3)
	model.add_child(muzzle)
	return self


func play_fire() -> void:
	if _anim:
		_anim.play("Fire")


## The gun jams: a trigger pulled with too little charge.
func play_jam() -> void:
	if _anim:
		_anim.play("Jam")


## Switches to `new_mode`. `animate` rolls the gun over; without it the panel just snaps.
func set_mode(new_mode: String, animate := true) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	if animate:
		_roll = 0.0
	else:
		_panel = PANEL_ANGLE[mode]


## Is it in the middle of switching?
func rolling() -> bool:
	return _roll >= 0.0


## The clips that are in charge of the bones while they play.
func _clip_playing() -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation in ["Fire", "Jam"]


func _process(delta: float) -> void:
	if _roll >= 0.0:
		_roll += delta
		var t := clampf(_roll / ROLL_TIME, 0.0, 1.0)
		model.rotation.z = TAU * (t * t * (3.0 - 2.0 * t))  # one full turn about the barrel, eased
		if t >= 1.0:
			_roll = -1.0
			model.rotation.z = 0.0
			_drum += PI * 0.5  # the drum clicks a quarter round as it lands
	_panel = move_toward(_panel, PANEL_ANGLE[mode], 420.0 * delta)
	if _skeleton == null or _clip_playing():
		return
	_pose("panel", Basis.from_euler(Vector3(deg_to_rad(_panel), 0, 0)))
	if charge > 0.0:
		_drum += (3.0 + 42.0 * charge) * delta
		_pose("drum", Basis.from_euler(Vector3(_drum, 0, -PI / 2.0)))
		_pose("trigger", Basis.from_euler(Vector3(-PI / 2.0 - 0.45 * minf(1.0, charge * 4.0), 0, 0)))
		var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.006 * charge * charge
		_skeleton.set_bone_pose_position(_bones.gun, (_rest.gun as Transform3D).origin + shake)
	else:
		_drum = lerp_angle(_drum, roundf(_drum / TAU) * TAU, 1.0 - exp(-7.0 * delta))  # settles to rest
		_pose("drum", Basis.from_euler(Vector3(_drum, 0, -PI / 2.0)))
		_pose("trigger", Basis.from_euler(Vector3(-PI / 2.0, 0, 0)))
		_skeleton.set_bone_pose_position(_bones.gun, (_rest.gun as Transform3D).origin)


func _pose(bone: String, basis: Basis) -> void:
	if _bones.has(bone):
		_skeleton.set_bone_pose_rotation(_bones[bone], basis.get_rotation_quaternion())
