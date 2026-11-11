## CONTROLLER. Getting on and off the bicycle with F. The rules are the model's (Riding); this changes how the
## player moves and what they see while riding: faster, no jumping, lower to the ground, handlebars in view
## and the gun put away. It also keeps the model's bike with the player, and gets them off if they pass out.
class_name BikeController
extends Node

var world: World
var player: PlayerController
var gun: GunController
var hud: Hud

var _rig: BikeRig
var _view: BikeView = null


func setup(w: World, p: PlayerController, g: GunController, h: Hud) -> BikeController:
	world = w
	player = p
	gun = g
	hud = h
	_rig = BikeRig.new().setup()
	player.camera.add_child(_rig)
	_rig.position = Vector3(0, -0.42, -0.75)
	return self


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("mount") and player.controls_enabled:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if world.riding.riding():
		var r := world.riding.dismount(player.rotation.y)
		hud.notify(r.text)
		if r.ok:
			_apply(false)
	else:
		var r := world.riding.mount()
		hud.notify(r.text)
		if r.ok:
			_apply(true)


## Called every frame (by GameController), after the player's body has been copied into the model.
func sync() -> void:
	if world.bike == null:
		return
	if _view == null:
		_view = BikeView.new().setup(world)
		get_parent().add_child(_view)
	if world.riding.riding() and world.player.unconscious():
		world.riding.dismount(player.rotation.y)
		_apply(false)
	world.riding.follow_player()


func _apply(on: bool) -> void:
	player.speed_scale = world.riding.speed_factor()
	player.set_riding(on)
	gun.set_suppressed(on)
	_rig.visible = on


func _process(delta: float) -> void:
	if _rig.visible:
		_rig.update(Vector2(player.velocity.x, player.velocity.z).length(), delta)
