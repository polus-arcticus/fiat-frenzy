## CONTROLLER. First-person movement and look. Click to capture the mouse (Esc to let go is the
## ScreenStack's job).
class_name PlayerController
extends CharacterBody3D

@export var walk_speed := 4.5
@export var sprint_speed := 8.0
@export var jump_velocity := 4.6
@export var mouse_sensitivity := 0.0025
@export var accel := 12.0

var controls_enabled := true
## How many times faster than walking the player goes (the bicycle). While it is above 1 there is no sprint and no jump.
var speed_scale := 1.0
var head: Node3D
var camera: Camera3D
var _pitch := 0.0
var _bob_t := 0.0
var _shake := 0.0
var _riding := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 700.0
	camera.current = true
	head.add_child(camera)
	camera.add_child(Watercolor.make_post_quad())


func ground_pos() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled:
		look(-e.relative.x * mouse_sensitivity, -e.relative.y * mouse_sensitivity)


func look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	_pitch = clampf(_pitch + pitch, deg_to_rad(-85), deg_to_rad(85))
	head.rotation.x = _pitch


## Turn to face a world point. `weight` 1 snaps; less eases toward it each call (the intro's camera follow).
func look_toward(point: Vector3, weight := 1.0) -> void:
	var to := point - head.global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), weight)
	var target_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	_pitch = clampf(lerp_angle(_pitch, target_pitch, weight), deg_to_rad(-85), deg_to_rad(85))
	head.rotation.x = _pitch


## Getting on or off a bike: the head sits lower and there is no sprint or jump while riding.
func set_riding(on: bool) -> void:
	_riding = on
	if not on:
		speed_scale = 1.0


## Look straight ahead again (after being teleported somewhere new).
func level_gaze() -> void:
	_pitch = 0.0
	head.rotation.x = 0.0


## Rattles the camera (0..1); it dies away on its own.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func teleport(pos: Vector3, yaw := 0.0) -> void:
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Vector2.ZERO
	var sprinting := false
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor() and not _riding:
			velocity.y = jump_velocity
		sprinting = Input.is_action_pressed("sprint") and not _riding
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := (sprint_speed if sprinting else walk_speed) * speed_scale
	var flat := Vector3(velocity.x, 0, velocity.z).lerp(dir * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	move_and_slide()
	head.position.y = lerpf(head.position.y, 1.45 if _riding else 1.6, clampf(8.0 * delta, 0.0, 1.0))  # lower on a bike
	var ratio := minf(flat.length() / sprint_speed, 1.2)
	if is_on_floor() and ratio > 0.05:
		_bob_t += delta * (6.0 + ratio * 6.0)
	_shake = maxf(0.0, _shake - delta * 1.5)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake * 0.25
	camera.position = Vector3(cos(_bob_t * 0.5) * 0.03, absf(sin(_bob_t)) * 0.045, 0.0) * minf(ratio * 1.6, 1.0) + jitter
