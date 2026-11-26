## CONTROLLER. Getting on and off the skateboard (B) and what riding it does to the player. The rules are the model's
## (Skating); this reads the keys for them, shows the board and the crouch and the flip, puts the camera behind the hero in
## third person, puts the gun away, and gets them off if they pass out or sit on the bus.
class_name SkateController
extends Node

const CAMERA_ARM := 4.6   # the camera hangs a little further back while skating
const KICK_TIME := 0.38   # the push: a lean out of the crouch and back, this long
const KICK_LEAN := 0.32   # radians, at its deepest
const ROLL_TIME := 0.55   # the bail: a barrel roll down onto the side...
const UP_TIME := 0.5      # ...and, at the end of it (Skating.BAIL_TIME), getting up
const HIPS := 0.9         # the body turns about its hips (metres up)
const LYING := 0.22       # and they're this high lying down
const STANDING := 0.14    # the body's height standing on the board

var world: World
var player: PlayerController
var gun: GunController
var hud: Hud

var _board: BoardView
var _was_third_person := false
var _flips_seen := 0
var _squash := 1.0
var _kicks_seen := 0
var _kick_t := -1.0       # time into the push being shown, or -1
var _was_bailing := false


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
		player.body.position.y = STANDING
		_kicks_seen = world.skating.kicks


func get_off() -> void:
	world.skating.dismount()
	player.skating = false
	player.camera_arm = PlayerController.ARM_LENGTH
	player.set_third_person(_was_third_person)
	gun.set_suppressed(false)
	_board.visible = false
	player.body.rotation = Vector3.ZERO
	player.body.position = Vector3.ZERO
	player.body.scale = Vector3.ONE
	player.body.cross_legs(0.0)
	_kick_t = -1.0
	_was_bailing = false


## The bail, posed by the time into it: thrown forward the way you were going, the body falls over head first and log-rolls
## along the ground, a whole turn about its own length, coming to rest on its left side in the recovery position (the top leg
## over: HeroBody.cross_legs); then up again, back onto the board. (The skater stands side-on, so "forward" is a fall over
## the facing axis, and the roll is about the body's length, which then lies along the way of travel.)
func _bail_pose(s: Skating) -> void:
	var body := player.body
	if not s.bailing:  # up again: back to standing on the board
		_was_bailing = false
		body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		body.position = Vector3(0.0, STANDING, 0.0)
		body.cross_legs(0.0)
		_squash = 1.0
		return
	_was_bailing = true
	body.scale = Vector3.ONE
	var t := Skating.BAIL_TIME - s.bail_left
	var fall := 0.0      # over, head first the way of travel (about the body's facing axis)
	var spin := 0.0      # the log roll, about the body's length
	var hips := HIPS
	var legs := 0.0
	if t < ROLL_TIME:
		var f := t / ROLL_TIME
		var eased := 1.0 - pow(1.0 - f, 3.0)  # (fast off the board, settling onto the side)
		fall = PI * 0.5 * clampf(eased * 1.6, 0.0, 1.0)
		spin = -TAU * eased
		hips = lerpf(HIPS, LYING, eased)
		legs = clampf((f - 0.6) / 0.4, 0.0, 1.0)
	elif s.bail_left > UP_TIME:
		fall = PI * 0.5
		hips = LYING
		legs = 1.0
	else:
		var f := 1.0 - s.bail_left / UP_TIME
		fall = lerpf(PI * 0.5, 0.0, f)
		hips = lerpf(LYING, HIPS, f)
		legs = 1.0 - f
	body.basis = Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.BACK, fall) * Basis(Vector3.UP, spin)
	body.position = Vector3(0.0, hips, 0.0) - body.basis * Vector3(0.0, HIPS, 0.0)
	body.cross_legs(legs)
	_board.pitch(0.0)


## What the board wants this physics frame, from the keys: called by the player body (see PlayerController.skate_driver).
func drive(delta: float, grounded: bool) -> Dictionary:
	var held := player.controls_enabled
	var input := {
		"push": held and Input.is_action_pressed("move_forward"),
		"kick": held and Input.is_action_just_pressed("fire"),  # (left click: a push with the foot; the gun is put away)
		"brake": held and Input.is_action_pressed("move_back"),
		"steer": Input.get_axis("move_right", "move_left") if held else 0.0,
		"jump_down": held and Input.is_action_pressed("jump"),
		"jump_pressed": held and Input.is_action_just_pressed("jump"),
		"height": player.global_position.y - Ground.land(player.ground_pos()),  # (above the land under the board: on a hill, not above the sea)
		"heading": Vector2(-player.transform.basis.z.x, -player.transform.basis.z.z).normalized(),
		"falling": player.velocity.y < 0.0,
		"rough": world.skating.kerbs != null and world.skating.kerbs.rough_at(player.ground_pos()),  # (cobbles: slower)
		"grade": _grade(),
	}
	var grinds := world.skating.grinds
	var bails := world.skating.bails
	var out := world.skating.step(delta, input, grounded, player.ground_pos())
	if world.skating.bails > bails:
		hud.show_caption("Bail", 1.0)
	if world.skating.grinds > grinds:
		hud.show_caption(world.skating.last_trick, 0.8)  # ("Grind" on a kerb, "Rail grind" on a rail)
		_board.pitch(0.0)
	elif out.get("ended", false):
		hud.show_caption(world.skating.last_trick, 1.4)
		if world.skating.grind_paid > 0.0:
			var rail := world.skating.grind_kind == "rail"
			hud.notify("Grind! %d m along the %s, $%d on the %s." % [roundi(world.skating.grind_metres), "rail" if rail else "kerb", int(world.skating.grind_paid), "ballast" if rail else "pavement"])
	if out.flip:
		_board.kickflip()
		hud.show_caption(world.skating.last_trick, 1.2)
		hud.notify("Kickflip! $%d on the ground." % int(Skating.KICKFLIP_CASH))
	elif out.jump > 0.0:
		hud.show_caption("Ollie", 0.6)
	return out


## Rise over run of the land along the way the board faces (positive: uphill), over a metre and a half about the hero.
func _grade() -> float:
	var h := Vector2(-player.transform.basis.z.x, -player.transform.basis.z.z).normalized()
	var here := player.ground_pos()
	return (Ground.land(here + h * 0.75) - Ground.land(here - h * 0.75)) / 1.5


func _physics_process(delta: float) -> void:
	if not world.skating.mounted:
		return
	# off the board if they pass out, or sit down on the bus, or are moved by a script
	if world.player.care != "" or player.is_seated() or player.scripted:
		get_off()
		return
	var s := world.skating
	if s.bailing or _was_bailing:
		_bail_pose(s)
		return
	# the crouch of the wind-up, and the nose tipping up in the air
	var squash := 1.0 - 0.22 * s.charge
	# a push: from the crouch, a lean over the pushing foot and back up (a dip as it goes down)
	if s.kicks > _kicks_seen:
		_kicks_seen = s.kicks
		_kick_t = 0.0
	var lean := 0.0
	if _kick_t >= 0.0:
		_kick_t += delta
		var f := _kick_t / KICK_TIME
		lean = sin(clampf(f, 0.0, 1.0) * PI) * KICK_LEAN
		squash = minf(squash, 1.0 - 0.12 * sin(clampf(f, 0.0, 1.0) * PI))
		if f >= 1.0:
			_kick_t = -1.0
	player.body.rotation.z = lean
	_squash = lerpf(_squash, squash, clampf(14.0 * delta, 0.0, 1.0))
	player.body.scale = Vector3(1.0, _squash, 1.0)
	# the nose tips up in the air, and the board lies along the hill it is on
	var nose := deg_to_rad(10.0) if s.in_air and not s.grinding else atan(_grade()) * 0.9
	_board.pitch(nose)
