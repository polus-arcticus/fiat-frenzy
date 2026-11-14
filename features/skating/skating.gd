## Skateboarding, arcade style: the rules, not the movement. You get on a board you own, roll along at a speed you build up
## (hold forward) and lose (coast, brake), and steer. Hold the jump key to crouch and let go to ollie: the longer you held,
## the higher. Press jump again in the air for a kickflip, once a jump, which sprays $25 on the ground (printed, like
## everything the gun makes, and lying there to be picked up).
##
## The player controller moves the body; each physics frame it asks `step` what the board wants to do (how fast, how much to
## turn, whether to jump or flip) and does it. Nothing here knows about nodes, so it is tested headless.
class_name Skating
extends RefCounted

const TOP_SPEED := 12.0     # metres a second at full push
const ACCEL := 7.0          # pushing
const COAST := 1.5          # slowing down by itself
const BRAKE := 13.0         # slowing down on purpose
const TURN_RATE := 2.6      # radians a second at speed: steering. (Slower going slowly, but you can always turn a little.)
const CHARGE_TIME := 0.45   # seconds of holding jump for the highest ollie
const OLLIE_MIN := 3.6      # launch speed of a tap
const OLLIE_MAX := 6.4      # and of a full charge
const KICKFLIP_CASH := 25.0 # what a kickflip sprays on the ground...
const KICKFLIP_BILLS := 5   # ...in this many bills

var mounted := false
var speed := 0.0
var charge := 0.0           # 0..1: how far the ollie is wound up
var in_air := false
var flipped := false        # a kickflip was done in this jump
var ollies := 0
var kickflips := 0          # (a view watches this count to play the flip)
var last_trick := ""

var _w: World


func _init(world: World) -> void:
	_w = world


## Why the hero can't get on a board right now, or "".
func why_not() -> String:
	if mounted:
		return "You're already on it."
	if _w.player == null or _w.player.carry.count("skateboard") < 1:
		return "You don't have a skateboard."
	if _w.player.unconscious():
		return "You're out cold."
	if _w.riding.riding():
		return "Get off the bike first."
	return ""


## Returns {ok, text}.
func mount() -> Dictionary:
	var why := why_not()
	if why != "":
		return {"ok": false, "text": why}
	mounted = true
	speed = 0.0
	charge = 0.0
	in_air = false
	flipped = false
	return {"ok": true, "text": "You step onto the board. W push, A and D steer, S brake, hold Space and let go to ollie, tap it again in the air to kickflip."}


## The board hit something solid: it stops dead.
func bump() -> void:
	speed = 0.0


func dismount() -> void:
	mounted = false
	speed = 0.0
	charge = 0.0
	in_air = false
	flipped = false


## One physics step of the board. `input` says what the player is doing: push (bool), brake (bool), steer (-1..1, left is
## positive), jump_down (the jump key is held) and jump_pressed (it was pressed this frame). `grounded` is whether the body
## is on the floor, and `at` where it is on the ground. Returns {speed, turn, jump, flip}: how fast to roll, how many
## radians a second to turn, the upward speed to launch with (0 for none), and whether a kickflip was done this frame.
func step(dt: float, input: Dictionary, grounded: bool, at: Vector2) -> Dictionary:
	if input.get("push", false):
		speed = minf(TOP_SPEED, speed + ACCEL * dt)
	elif input.get("brake", false):
		speed = maxf(0.0, speed - BRAKE * dt)
	else:
		speed = maxf(0.0, speed - COAST * dt)
	var out := {"speed": speed, "turn": float(input.get("steer", 0.0)) * TURN_RATE * clampf(speed / 4.0, 0.4, 1.0), "jump": 0.0, "flip": false}
	if not grounded:
		in_air = true
	elif in_air:
		in_air = false  # landed
		flipped = false
	if in_air:
		charge = 0.0
		if input.get("jump_pressed", false) and not flipped:
			flipped = true
			kickflips += 1
			last_trick = "Kickflip  +$%d" % int(KICKFLIP_CASH)
			spray(at)
			out.flip = true
	else:
		if input.get("jump_down", false):
			charge = minf(1.0, charge + dt / CHARGE_TIME)
		elif charge > 0.0:  # let go: ollie
			out.jump = lerpf(OLLIE_MIN, OLLIE_MAX, charge)
			charge = 0.0
			in_air = true
			ollies += 1
			last_trick = "Ollie"
	return out


## Sprays the kickflip's cash on the ground round `at`: printed now, lying there as loose bills. Returns the bills.
func spray(at: Vector2) -> Array[Bill]:
	var laid: Array[Bill] = []
	for k in KICKFLIP_BILLS:
		var angle := TAU * (float(k) + 0.5) / KICKFLIP_BILLS
		var b := _w.gun.fire(KICKFLIP_CASH / KICKFLIP_BILLS, "cash")
		laid.append(_w.gun.land(b, at + Vector2.from_angle(angle) * (1.4 + 0.35 * (k % 2))))
	return laid
