## CONTROLLER. The inspector (F3): leave the hero standing where they are, fly a free camera about the live world, click
## anyone, and read what they are doing and why (see Inspector). The sim never stops while you look. Leaving puts the hero's
## camera, controls and gun back as they were.
class_name InspectorController
extends Node

const SPEED := 14.0
const FAST := 4.0
const LOOK := 0.003
const PICK_RADIUS := 0.9   # how near the click's ray must pass to someone (metres), plus a little more with distance

var world: World
var player: PlayerController
var gun: GunController
var screens: ScreenStack
var active := false
var selected: Drone = null

var _view: InspectorView
var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _was_enabled := true
var _gun_was_on := false
var _was_captured := false
var _refresh := 0.0
var _last_pos := Vector2.INF
var _still := 0.0


func setup(w: World, p: PlayerController, g: GunController, s: ScreenStack, root: Node) -> InspectorController:
	world = w
	player = p
	gun = g
	screens = s
	_view = InspectorView.new().setup(root)
	add_child(_view)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.1
	_cam.far = 900.0
	_cam.add_child(Watercolor.make_post_quad())
	add_child(_cam)
	return self


func toggle() -> void:
	if active:
		_leave()
	elif screens.depth() == 0:
		_enter()


func _enter() -> void:
	active = true
	_was_enabled = player.controls_enabled
	_gun_was_on = gun.enabled
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	player.controls_enabled = false
	gun.set_enabled(false)
	var from := player.camera.global_transform
	_cam.global_transform = from
	_cam.global_position += Vector3(0, 3.0, 0) + from.basis.z * 3.0
	_yaw = player.rotation.y
	_pitch = -0.35
	_apply_look()
	_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_view.show_it(true)
	_view.show_text(PackedStringArray())


func _leave() -> void:
	active = false
	player.controls_enabled = _was_enabled and world.player.care == ""
	gun.set_enabled(_gun_was_on)
	player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _was_captured else Input.MOUSE_MODE_VISIBLE
	_view.show_it(false)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if e.pressed else Input.MOUSE_MODE_VISIBLE
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			select(pick(e.position))
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= e.relative.x * LOOK
		_pitch = clampf(_pitch - e.relative.y * LOOK, -1.5, 1.5)
		_apply_look()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_N:
				_cycle(1)
			KEY_P:
				_cycle(-1)
			KEY_G:
				go_to_selected()
			_:
				return
		get_viewport().set_input_as_handled()


func _apply_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if not active:
		return
	player.controls_enabled = false  # (waking up in the tent hands them back; not while we are looking)
	var move := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if move != Vector3.ZERO:
		var speed := SPEED * (FAST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		var flat := Basis(Vector3.UP, _yaw)
		_cam.global_position += (flat * Vector3(move.x, 0, move.z) + Vector3.UP * move.y) * speed * delta
	_watch(delta)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		show_selected()
	_view.draw(selected)


## How long the picked drone has stayed in one place.
func _watch(delta: float) -> void:
	if selected == null:
		_last_pos = Vector2.INF
		_still = 0.0
		return
	if _last_pos.is_finite() and selected.pos.distance_to(_last_pos) < 0.3:
		_still += delta
	else:
		_still = 0.0
		_last_pos = selected.pos


func show_selected() -> void:
	_view.show_text(Inspector.lines(world, selected, _still) if selected != null else PackedStringArray())


func select(d: Drone) -> void:
	selected = d
	_last_pos = Vector2.INF
	_still = 0.0
	show_selected()


## Whoever the click is on: the drone the ray from the camera through `screen_pos` passes closest to (near enough to mean it).
func pick(screen_pos: Vector2) -> Drone:
	var origin := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var best: Drone = null
	var best_t := INF
	for d in world.drones:
		var v := Vector3(d.pos.x, 0.9, d.pos.y) - origin
		var t := v.dot(dir)
		if t <= 0.0 or t > 400.0:
			continue
		if (v - dir * t).length() <= PICK_RADIUS + t * 0.01 and t < best_t:
			best_t = t
			best = d
	return best


func _cycle(step: int) -> void:
	if world.drones.is_empty():
		return
	var i := world.drones.find(selected)
	select(world.drones[posmod(i + step, world.drones.size())])


## The camera goes to a good place to watch the picked drone from.
func go_to_selected() -> void:
	if selected == null:
		return
	_yaw = 0.0
	_pitch = -0.6
	_apply_look()
	_cam.global_position = Vector3(selected.pos.x, 7.0, selected.pos.y + 9.0)
