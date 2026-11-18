## CONTROLLER. Movement and look, in first person or (V) third person, where the camera hangs on an arm behind and a little
## to the right of the hero, who is drawn (HeroBody). Click to capture the mouse (Esc to let go is the ScreenStack's job).
class_name PlayerController
extends CharacterBody3D

@export var walk_speed := 4.5
@export var sprint_speed := 8.0
@export var jump_velocity := 4.6
@export var mouse_sensitivity := 0.0025
@export var accel := 12.0

## The view changed: true for third person. (The gun and the bicycle's handlebars move to suit.)
signal view_changed(third_person: bool)
## The board ran into something solid while skating.
signal skate_bumped

const ARM_LENGTH := 3.4   # how far behind the hero's head the camera hangs in third person
const SHOULDER := 0.55    # and how far to the right: over the shoulder

var controls_enabled := true
## The view in use now, and the one the player has asked for (it is first person whatever they ask while sitting on the
## bus or being moved by a script).
var third_person := false
var wanted_third_person := false
var body: HeroBody
## Skating: while true, the skate driver (a callable: delta, on the floor -> {speed, turn, jump, flip}) moves the body: it rolls
## the way it faces at the board's speed, steers, and jumps when told. The camera arm is longer while skating.
var skating := false
var skate_driver: Callable
var camera_arm := ARM_LENGTH
## How many times faster than walking the player goes (the bicycle). While it is above 1 there is no sprint and no jump.
var speed_scale := 1.0
var head: Node3D
var camera: Camera3D
var _arm: SpringArm3D
var _pitch := 0.0
var _bob_t := 0.0
var _shake := 0.0
var _riding := false
## Moved by a script (getting on the bus), not by the keys: no walking, no gravity, no collisions.
var scripted := false
var _seat: Node3D = null   # sitting in something that moves (the bus): where, in its own frame
var _seat_local := Vector3.ZERO
var _seat_yaw := 0.0
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
	_arm = SpringArm3D.new()  # holds the camera clear of walls: it pulls in when something is in the way
	_arm.spring_length = 0.0
	_arm.collision_mask = 1
	_arm.margin = 0.3
	head.add_child(_arm)
	_arm.add_excluded_object(get_rid())
	_arm.add_child(camera)
	camera.add_child(Watercolor.make_post_quad())
	body = HeroBody.new().setup()
	body.visible = false
	add_child(body)


func ground_pos() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("view") and controls_enabled:
		set_third_person(not wanted_third_person)
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (controls_enabled or _seat != null):
		look(-e.relative.x * mouse_sensitivity, -e.relative.y * mouse_sensitivity)  # (you can look round a moving bus)


## Choose first or third person. (Takes effect at once, unless the hero is on the bus or moved by a script.)
func set_third_person(on: bool) -> void:
	wanted_third_person = on
	_apply_view(0.0)


## How far the camera is behind the hero's head: the aiming ray starts there, so reach is measured from the hero.
func view_back() -> float:
	return camera.global_position.distance_to(head.global_position)


func _apply_view(delta: float) -> void:
	var want := wanted_third_person and _seat == null and not scripted
	if want != third_person:
		third_person = want
		body.visible = want
		view_changed.emit(want)
	var k := 1.0 if delta <= 0.0 else 1.0 - exp(-9.0 * delta)
	_arm.spring_length = lerpf(_arm.spring_length, camera_arm if third_person else 0.0, k)
	_arm.position.x = lerpf(_arm.position.x, SHOULDER if third_person else 0.0, k)


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


## Sit in something that moves: from now on the body is carried at `local` in its frame, and turns with it, so the
## view stays put relative to it. You can still look about. `stand` gets up.
func sit(on: Node3D, local: Vector3) -> void:
	_seat = on
	_seat_local = local
	_seat_yaw = on.rotation.y
	velocity = Vector3.ZERO
	update_seat()


func stand() -> void:
	_seat = null


func is_seated() -> bool:
	return _seat != null


## Put the body where its seat is now. (Every physics frame while seated; tests and tools that step the world without
## frames call it themselves.)
func update_seat() -> void:
	if _seat == null:
		return
	global_position = _seat.to_global(_seat_local)
	rotation.y += angle_difference(_seat_yaw, _seat.rotation.y)
	_seat_yaw = _seat.rotation.y


func _physics_process(delta: float) -> void:
	_apply_view(delta)
	if _seat != null:
		update_seat()
		head.position.y = lerpf(head.position.y, 1.0, clampf(6.0 * delta, 0.0, 1.0))  # sitting: the eyes are low
		_shake = maxf(0.0, _shake - delta * 1.5)
		camera.position = Vector3(0, sin(Time.get_ticks_msec() * 0.011) * 0.012, 0)  # a faint rumble from the road
		return
	if scripted:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if skating and skate_driver.is_valid():
		var out: Dictionary = skate_driver.call(delta, is_on_floor())
		rotate_y(out.turn * delta)
		var heading := -transform.basis.z
		velocity.x = heading.x * out.speed
		velocity.z = heading.z * out.speed
		if out.jump > 0.0:
			velocity.y = out.jump
		move_and_slide()
		var moving := Vector2(get_real_velocity().x, get_real_velocity().z).length()
		if moving < out.speed * 0.5:  # ran into something: the board stops dead, as in the games
			skate_bumped.emit()
		if third_person:
			body.refresh(0.0)  # (standing on the board)
		_shake = maxf(0.0, _shake - delta * 1.5)
		camera.position = Vector3.ZERO
		return
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
	camera.position = Vector3(cos(_bob_t * 0.5) * 0.03, absf(sin(_bob_t)) * 0.045, 0.0) * minf(ratio * 1.6, 1.0) * (0.0 if third_person else 1.0) + jitter
	if third_person:
		body.refresh(flat.length())
