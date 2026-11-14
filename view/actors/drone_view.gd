## VIEW. Draws one Drone: a humanoid from the Blender pipeline that follows the model's position and
## plays an animation that fits what the drone is doing. It only reads the model.
class_name DroneView
extends Node3D

const MODELS := {
	"drifter": preload("res://assets/models/zombie.glb"),
	"vendor": preload("res://assets/models/builder.glb"),
	"banker": preload("res://assets/models/banker.glb"),
	"sage": preload("res://assets/models/banker.glb"),
	"clerk": preload("res://assets/models/banker.glb"),
	"runner": preload("res://assets/models/builder.glb"),
	"keeper": preload("res://assets/models/builder.glb"),
}
const LAYER_NPC := 4

var drone: Drone
var world: World
var _model: Node3D
var _pose: Node3D   # lies the whole body down; the model hangs under it, turned round to face -z
var _anim: AnimationPlayer
var _label: Label3D
var _bars: BarsRig
var _cart: CartView = null  # a runner's
var _bubble: Bubble
var _aura: AuraView
var _last_level := 1
var _playing := ""
var _hold_clip := ""
var _hold_until := 0.0
var _last := Vector3.ZERO
var _speed := 0.0
var _label_clock := 0.0
var _tent_shelters: Array = []


func setup(d: Drone, w: World) -> DroneView:
	drone = d
	world = w
	name = "Drone%d" % d.id
	_model = Look.model(MODELS[d.look if MODELS.has(d.look) else d.kind])
	# The models are made facing +z (the glTF way), but this view turns -z toward where the drone is going
	# (and puts a runner's cart at -z), so the model is spun half a turn to face the way it walks.
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	var flip := Node3D.new()
	flip.name = "Facing"
	flip.rotation.y = PI
	_pose.add_child(flip)
	flip.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for clip in ["Idle", "Walk", "Shamble", "Dazed", "Search", "Hammer"]:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anim.seek(randf() * 2.0, true)
	_label = Look.label3d(self, "", Vector3(0, 2.85, 0), 40, 14.0)
	_bars = BarsRig.new()
	add_child(_bars)
	_bubble = Bubble.new()
	add_child(_bubble)
	_aura = AuraView.new()
	add_child(_aura)
	if d.kind == "runner":
		_cart = CartView.new()
		add_child(_cart)
	if d.kind == "sage":
		_bars.visible = false  # he is not a thing with bars
		var emblem := Emblem.new()
		emblem.position = Vector3(-0.02, 1.34, -0.2)  # a pin on his left lapel: you only notice it close up
		_pose.add_child(emblem)
	Look.pick_area(self, _capsule(), Vector3(0, 0.9, 0), LAYER_NPC, "drone", d)
	position = Vector3(d.pos.x, 0, d.pos.y)
	_last = position
	_last_level = d.growth.level
	for m in w.machines:
		if m.shelter != null:
			_tent_shelters.append(m.shelter)
	return self


func _capsule() -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = 0.5
	c.height = 1.9
	return c


func _process(delta: float) -> void:
	var target := Vector3(drone.pos.x, 0, drone.pos.y)
	global_position = global_position.lerp(target, 1.0 - exp(-14.0 * delta))
	var moved := global_position - _last
	_speed = lerpf(_speed, moved.length() / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))
	_last = global_position
	if moved.length() > 0.002:
		rotation.y = lerp_angle(rotation.y, atan2(-moved.x, -moved.z), 1.0 - exp(-10.0 * delta))
	elif drone.face_to.is_finite() and drone.pos.distance_to(drone.face_to) > 0.1:  # standing still, looking at something
		var to := drone.face_to - drone.pos
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.y), 1.0 - exp(-6.0 * delta))
	if drone.growth.level > _last_level:
		_celebrate()
	_model.visible = (drone.sheltered_in == null or not (drone.sheltered_in in _tent_shelters)) and drone.care != "carried"
	_bars.refresh(drone, _model.visible and drone.kind != "sage", get_viewport().get_camera_3d())
	_aura.visible = drone.aura and _model.visible and drone.care == ""
	_lie_down(delta)
	_play(_pick_animation())
	_label_clock -= delta
	if _label_clock <= 0.0:
		_label_clock = 0.5
		_label.text = _caption()
		_label.visible = _model.visible
		if _cart != null:
			_cart.refresh(drone)


## Someone who has collapsed lies on the ground, or in their cot, with the bars and name lowered to match.
func _lie_down(delta: float) -> void:
	var lying := drone.care == "down" or drone.care == "patient"
	var k := 1.0 - exp(-6.0 * delta)
	# Lying on their back, head toward +z (the body faces -z, so tipping it back puts the face up).
	_pose.rotation.x = lerp_angle(_pose.rotation.x, PI / 2.0 if lying else 0.0, k)
	_pose.position.y = lerpf(_pose.position.y, (0.6 if drone.care == "patient" else 0.12) if lying else 0.0, k)
	_pose.position.z = lerpf(_pose.position.z, -0.85 if lying else 0.0, k)
	_bars.lower(lying, k)
	_bubble.refresh(drone, lying, k, delta)
	_label.position.y = lerpf(_label.position.y, 1.5 if lying else 2.78, k)
	if drone.care == "patient" and not world.hospitals.is_empty():
		var front := world.hospitals[0].front
		rotation.y = lerp_angle(rotation.y, atan2(-front.x, -front.y) + PI, k)  # head toward the street end


## The bar filled: a burst of gold and "LEVEL UP!" floating up over their head.
func _celebrate() -> void:
	_last_level = drone.growth.level
	var root_node := get_parent()
	var l := Look.label3d(root_node, "LEVEL UP!  Lv %d" % drone.growth.level, global_position + Vector3(0, 3.2, 0), 44, 80.0)
	l.modulate = Color(1.0, 0.9, 0.4)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.4, 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.6)
	tw.chain().tween_callback(l.queue_free)
	Effects.burst(root_node, global_position + Vector3(0, 1.5, 0), [Color(1.0, 0.9, 0.4), Color(1.0, 0.7, 0.2, 0.0)], 36, 5.0, 0.07, 1.0)


## Plays `clip` for a while whatever the drone is doing (the bankers sitting dazed after the crash).
func hold_animation(clip: String, seconds: float) -> void:
	_hold_clip = clip
	_hold_until = Time.get_ticks_msec() / 1000.0 + seconds


func _pick_animation() -> String:
	if Time.get_ticks_msec() / 1000.0 < _hold_until:
		return _hold_clip
	if drone.unconscious():
		return "Idle"
	var walking := _speed > 0.3
	if drone.kind == "runner" or drone.kind == "keeper":
		return "Walk" if _speed > 0.3 else "Idle"
	if drone.kind == "vendor":
		var m := world.machine_of(drone)
		if walking:
			return "Walk"
		return "Hammer" if m != null and m.working and m.stock() < m.capacity() / 2 else ("Search" if m != null and not m.working else "Idle")
	if walking:
		return "Shamble"
	return "Dazed" if drone.neediest() < 0.3 else "Idle"


func _play(clip: String) -> void:
	if _anim and clip != _playing and _anim.has_animation(clip):
		_playing = clip
		_anim.play(clip, 0.2)


func _caption() -> String:
	var wants: Array = world.needs.demands(drone)
	var line := ""
	if drone.care != "":
		line = {"down": "collapsed, waiting for the ambulance", "patient": "resting in the medical tent"}.get(drone.care, "")
	elif drone.sheltered_in != null:
		line = "warming up"
	elif not wants.is_empty():
		line = {"food": "hungry", "drink": "thirsty", "warmth": "cold", "repair": "wants to fix the stand", "restock": "needs stock", "haul": "making deliveries"}.get(wants[0], "")
	var head := drone.label if drone.label != "" else drone.kind
	if drone.kind != "sage" and (drone.kind != "drifter" or drone.growth.level > 1):
		head += "  ·  Lv %d" % drone.growth.level
	return head if line == "" else "%s\n%s" % [head, line]
