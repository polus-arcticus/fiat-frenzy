## CONTROLLER. The opening: a helicopter full of bankers falls out of the sky onto the station district.
## A skippable cinematic. The camera follows the fall; the wreck lands with a shake, dust and sparks; three
## dazed bankers and a spray of their cash (real bills, so the NPCs go after them) land around it; then the
## money gun drops at your feet. While it runs the player has no controls and the sim is paused.
##
## This is the only place with story logic. The visuals are the models and effects it asks for; the
## bankers are ordinary drones, and the cash is the ordinary Gun/Bill system.
class_name IntroController
extends Node

signal finished
signal pickup_spawned(pickup: GunPickupView)

const WRECK := preload("res://assets/models/heli_wreck.glb")
const ROTOR := preload("res://assets/models/heli_rotor.glb")
const BRIEFCASE := preload("res://assets/models/briefcase.glb")

const FALL_TIME := 3.2
const SKY_OFFSET := Vector3(-28, 40, -26)
## Where the bankers land, as (along the street, across it) from the wreck.
const BANKER_SPOTS := [Vector2(-2.5, -1.5), Vector2(3.0, 1.2), Vector2(-1.0, 2.2)]
const CASH_BILLS := 10
const CASH_VALUE := 5.0
const BANKER_CASH := 12.0

var running := false
var wreck: Node3D
var pickup: GunPickupView

var _world: World
var _player: PlayerController
var _hud: Hud
var _scenario: Scenario
var _root: Node
var _make_view: Callable
var _rotor: Node3D
var _final := Transform3D.IDENTITY
var _rotor_final := Transform3D.IDENTITY
var _tween: Tween
var _impacted := false
var _gun_dropped := false


func setup(w: World, p: PlayerController, h: Hud, s: Scenario, root_node: Node, make_view: Callable) -> IntroController:
	_world = w
	_player = p
	_hud = h
	_scenario = s
	_root = root_node
	_make_view = make_view
	name = "Intro"
	return self


func _wreck_at() -> Vector3:
	return Vector3(_scenario.wreck_pos.x, 0, _scenario.wreck_pos.y)


func start() -> void:
	running = true
	_player.controls_enabled = false
	wreck = Look.model(WRECK)
	_rotor = Look.model(ROTOR)
	_root.add_child(wreck)
	_root.add_child(_rotor)
	var at := _wreck_at()
	_final = Transform3D(Basis(Vector3.UP, _scenario.wreck_yaw) * Basis(Vector3.BACK, deg_to_rad(-5.0)), at)
	var rotor_pos := _scenario.offset_on_street(_scenario.wreck_pos, -8.0, 3.0)
	_rotor_final = Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)) * Basis(Vector3.RIGHT, deg_to_rad(4.0)), Vector3(rotor_pos.x, 0.06, rotor_pos.y))
	var first := _final
	first.origin += SKY_OFFSET
	wreck.global_transform = first
	Effects.smoke(wreck, Vector3(0, 2.0, 0.6))
	_hud.show_caption("Bahnhofsviertel. 6:47 AM.", 2.4)
	_tween = create_tween()
	_tween.tween_method(_fall_step, 0.0, 1.0, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_play()


## The beats after the fall begins, on timers so a skip can simply stop them.
func _play() -> void:
	await get_tree().create_timer(FALL_TIME).timeout
	if not running:
		return
	_impact()
	await get_tree().create_timer(0.5).timeout
	if not running:
		return
	_drop_gun(0.9)
	await get_tree().create_timer(1.3).timeout
	if not running:
		return
	_hud.show_caption("...and something landed at your feet.", 2.5)
	await get_tree().create_timer(1.0).timeout
	if running:
		finish()


func _fall_step(t: float) -> void:
	var xf := _final
	xf.origin = _final.origin + SKY_OFFSET * (1.0 - t) + Vector3(0, sin(t * PI) * 4.0, 0)
	xf.basis = _final.basis.rotated(Vector3.UP, (1.0 - t) * TAU * 2.5).rotated(Vector3.FORWARD, (1.0 - t) * 0.4)
	wreck.global_transform = xf
	_rotor.global_position = wreck.global_transform * Vector3(0, 2.5, -0.1)
	var e := xf.basis.get_euler()
	_rotor.global_rotation = Vector3(e.x, t * 90.0, e.z)


func _process(delta: float) -> void:
	if running and wreck != null:
		_player.look_toward(wreck.global_position + Vector3(0, 1.0, 0), clampf(delta * 5.0, 0.0, 1.0))


func _unhandled_input(e: InputEvent) -> void:
	if running and e.is_action_pressed("skip"):
		finish()
		get_viewport().set_input_as_handled()


func _impact() -> void:
	if _impacted:
		return
	_impacted = true
	wreck.global_transform = _final
	var at := _final.origin
	_player.shake(1.0)
	Effects.burst(_root, at + Vector3.UP * 0.5, [Color(0.55, 0.5, 0.45, 0.9), Color(0.7, 0.68, 0.65, 0.0)], 70, 7.0, 0.35, 1.6)
	Effects.burst(_root, at + Vector3.UP * 1.0, [Color(1, 0.8, 0.3), Color(1, 0.4, 0.1, 0.0)], 40, 9.0, 0.06, 0.8)
	var from := _rotor.global_transform
	create_tween().tween_method(_fling_rotor.bind(from), 0.0, 1.0, 0.9)
	for spot in BANKER_SPOTS:
		_spawn_banker(_scenario.offset_on_street(_scenario.wreck_pos, spot.x, spot.y))
	for i in CASH_BILLS:
		var bill := _world.gun.fire(CASH_VALUE, "gift")
		var dir := Vector3(randf_range(-1, 1), randf_range(0.8, 1.6), randf_range(-1, 1)).normalized()
		var p := BillProjectile.new().launch(bill, _world, at + Vector3(randf_range(-0.8, 0.8), 2.0, randf_range(-0.8, 0.8)), dir * randf_range(5.0, 9.0), Callable())
		_root.add_child(p)
	var case := Look.model(BRIEFCASE)
	case.scale = Vector3.ONE * 1.6
	var case_at := _scenario.offset_on_street(_scenario.wreck_pos, 1.5, 2.0)
	_root.add_child(case)
	case.global_position = Vector3(case_at.x, 0.0, case_at.y)
	case.rotation.y = 0.7
	_hud.show_caption("A helicopter full of bankers just fell on the station district.", 2.6)
	_hud.notify("Bankers are scattered across the street. So is their cash.")


func _spawn_banker(at: Vector2) -> void:
	var d := _world.add_drifter(at, BANKER_CASH)
	d.label = "Banker"
	d.look = "banker"
	var view: DroneView = _make_view.call(d)
	view.hold_animation("Dazed", 5.0)


func _fling_rotor(t: float, from: Transform3D) -> void:
	var xf := from.interpolate_with(_rotor_final, t)
	xf.origin += Vector3.UP * sin(t * PI) * 3.0
	_rotor.global_transform = xf.rotated_local(Vector3.UP, (1.0 - t) * 9.0)


## The gun falls out of the sky and lands just ahead of the player.
func _drop_gun(duration: float) -> void:
	if _gun_dropped:
		return
	_gun_dropped = true
	pickup = GunPickupView.new()
	_root.add_child(pickup)
	var rest := Vector3(_scenario.gun_rest.x, 0.1, _scenario.gun_rest.y)
	pickup.global_position = rest + Vector3(0, 18.0, 0)
	pickup_spawned.emit(pickup)
	var tw := create_tween()
	tw.tween_method(_gun_fall.bind(rest), 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_gun_landed.bind(rest))


func _gun_fall(t: float, rest: Vector3) -> void:
	if is_instance_valid(pickup):
		pickup.global_position = rest + Vector3(0, 18.0 * (1.0 - t), 0)
		pickup.rotation = Vector3(t * 14.0, t * 6.0, 0.0) * (1.0 - t)


func _gun_landed(rest: Vector3) -> void:
	if is_instance_valid(pickup):
		pickup.global_position = rest
		pickup.rotation = Vector3.ZERO
		pickup.rest()
		Effects.burst(_root, rest + Vector3.UP * 0.1, [Color(0.6, 0.55, 0.5, 0.8), Color(0.6, 0.55, 0.5, 0)], 14, 2.0, 0.08, 0.6)
		_player.shake(0.25)


## Ends the cinematic (it also ends itself): everything snaps to where it was heading, and control returns.
func finish() -> void:
	if not running:
		return
	running = false
	if _tween:
		_tween.kill()
	if wreck != null:
		_impact()
		_drop_gun(0.01)
		wreck.global_transform = _final
		_rotor.global_transform = _rotor_final
		_gun_landed(Vector3(_scenario.gun_rest.x, 0.1, _scenario.gun_rest.y))
	_player.controls_enabled = true
	_player.look_toward(Vector3(_scenario.gun_rest.x, 0.0, _scenario.gun_rest.y))
	finished.emit()
