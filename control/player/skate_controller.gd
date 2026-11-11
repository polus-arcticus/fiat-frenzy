## CONTROLLER. Getting on and off the skateboard (B) and what riding it does to the player. The rules are the model's
## (Skating); this reads the keys for them, shows the board and the crouch and the flip, puts the camera behind the hero in
## third person, puts the gun away, and gets them off if they pass out or sit on the bus.
class_name SkateController
extends Node

const CAMERA_ARM := 4.6   # the camera hangs a little further back while skating

var world: World
var player: PlayerController
var gun: GunController
var hud: Hud

var _board: BoardView
var _was_third_person := false
var _flips_seen := 0
var _squash := 1.0


func setup(w: World, p: PlayerController, g: GunController, h: Hud) -> SkateController:
	world = w
	player = p
	gun = g
	hud = h
	_board = BoardView.new().setup()
	player.add_child(_board)
	player.skate_driver = drive
	player.skate_bumped.connect(world.skating.bump)
	return self


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("board") and player.controls_enabled:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if world.skating.mounted:
		get_off()
		return
	var r := world.skating.mount()
	hud.notify(r.text)
	if r.ok:
		_was_third_person = player.wanted_third_person
		player.skating = true
		player.camera_arm = CAMERA_ARM
		player.set_third_person(true)
		gun.set_suppressed(true)
		_board.visible = true
		_flips_seen = world.skating.kickflips
		player.body.rotation.y = -PI * 0.5  # sideways on the board, the way a skater stands
		player.body.position.y = 0.14


func get_off() -> void:
	world.skating.dismount()
	player.skating = false
	player.camera_arm = PlayerController.ARM_LENGTH
	player.set_third_person(_was_third_person)
	gun.set_suppressed(false)
	_board.visible = false
	player.body.rotation.y = 0.0
	player.body.position.y = 0.0
	player.body.scale = Vector3.ONE


## What the board wants this physics frame, from the keys: called by the player body (see PlayerController.skate_driver).
func drive(delta: float, grounded: bool) -> Dictionary:
	var held := player.controls_enabled
	var input := {
		"push": held and Input.is_action_pressed("move_forward"),
		"brake": held and Input.is_action_pressed("move_back"),
		"steer": Input.get_axis("move_right", "move_left") if held else 0.0,
		"jump_down": held and Input.is_action_pressed("jump"),
		"jump_pressed": held and Input.is_action_just_pressed("jump"),
	}
	var out := world.skating.step(delta, input, grounded, player.ground_pos())
	if out.flip:
		_board.kickflip()
		hud.show_caption(world.skating.last_trick, 1.2)
		hud.notify("Kickflip! $%d on the ground." % int(Skating.KICKFLIP_CASH))
	elif out.jump > 0.0:
		hud.show_caption("Ollie", 0.6)
	return out


func _physics_process(delta: float) -> void:
	if not world.skating.mounted:
		return
	# off the board if they pass out, or sit down on the bus, or are moved by a script
	if world.player.care != "" or player.is_seated() or player.scripted:
		get_off()
		return
	# the crouch of the wind-up, and the nose tipping up in the air
	var squash := 1.0 - 0.22 * world.skating.charge
	_squash = lerpf(_squash, squash, clampf(14.0 * delta, 0.0, 1.0))
	player.body.scale = Vector3(1.0, _squash, 1.0)
	_board.pitch(deg_to_rad(10.0) if world.skating.in_air else 0.0)
