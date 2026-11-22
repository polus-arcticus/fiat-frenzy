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
const KICK := 2.4           # a push with the foot (left click): this much more speed at once...
const KICK_EVERY := 0.3     # ...at most this often
const PUMP_AFTER := 0.6     # crouched this long past a full charge, the board starts to pump along...
const PUMP_ACCEL := 1.2     # ...this fast...
const PUMP_TOP := 0.6       # ...up to this share of the top speed (a fallback, slower than pushing)
## Into a wall or up a kerb without an ollie, faster than BAIL_SPEED, and you bail: off the board, a roll onto the ground, a
## moment there, then up and on again. Slower, the board just stops.
const BAIL_SPEED := 3.0
const ROUGH := 0.6          # on cobbles, setts or gravel (Kerbs.rough_at), the board goes this share of its top speed...
const ROUGH_DRAG := 6.0     # ...and slows to it this fast
const BAIL_TIME := 1.8
const OLLIE_MIN := 3.6      # launch speed of a tap
const OLLIE_MAX := 6.4      # and of a full charge
## Style is strewn, not pocketed: what a trick prints lands out of the hero's reach (Commerce.PICKUP_REACH), for them to go
## back for, or for whoever gets there first.
const KICKFLIP_CASH := 5.0  # what a kickflip sprays on the ground...
const KICKFLIP_BILLS := 5   # ...in this many bills...
const KICKFLIP_STREW := Vector2(2.0, 4.0)  # ...this many metres round where it landed
const TRAIL_BEHIND := Vector2(1.7, 2.7)    # a grind's bills land this far behind the board...
const TRAIL_ACROSS := Vector2(0.4, 1.4)    # ...and this far across the pavement
## Grinding a kerb (Kerbs.edges): come down from an ollie onto a kerb line, running along it, and the board locks onto its
## edge and slides, a $1 bill dropping onto the pavement every GRIND_EVERY metres. Jump to pop off; it ends by itself where
## the kerb does, or when the board has slowed too much.
const GRIND_REACH := 0.5    # metres from a kerb line the board snaps onto it
const GRIND_ALIGN := 0.82   # how nearly along it you must be going (the cosine: within about 35 degrees)
const GRIND_ABOVE := 0.8    # how far above the kerb's top the board may be, coming down, to catch it
const GRIND_MIN_SPEED := 2.5
const GRIND_DRAG := 2.2     # metres a second, a second: the edge slows you (flat out, about 30 m and $15)
const GRIND_EVERY := 2.0    # metres per $1 dropped
const GRIND_LINK := 0.9     # a kerb line that starts this near where this one ends carries the grind on

var mounted: bool:
	get:
		return _w.hero.mode == Hero.Mode.SKATING
var speed := 0.0
var charge := 0.0           # 0..1: how far the ollie is wound up
var in_air := false
var flipped := false        # a kickflip was done in this jump
var ollies := 0
var kickflips := 0          # (a view watches this count to play the flip)
var last_trick := ""
var kicks := 0               # pushes with the foot (a view plays one each time this counts up)
var rough := false           # rolling on cobbles (ROUGH)
var bailing := false
var bail_left := 0.0         # seconds till you're up again
var bails := 0
var kerbs: Kerbs             # the kerbs to grind (the game sets them; none, no grinding)
var grinding := false
var grinds := 0
var grind_metres := 0.0      # how far the grind under way has gone
var grind_paid := 0.0        # and what it has dropped

var _w: World
var _edge := -1              # the kerb line being ground (an index into kerbs.edges)
var _along := 0.0            # metres from its start
var _dir := 1.0              # +1 toward its end, -1 toward its start
var _since_bill := 0.0
var _since_kick := 1.0
var _crouched := 0.0         # seconds the jump key has been held on the ground


func _init(world: World) -> void:
	_w = world


## Why the hero can't get on a board right now, or "".
func why_not() -> String:
	if _w.player == null or board() == "":
		return "You don't have a skateboard in your loadout."
	return _w.hero.why_not(Hero.Mode.SKATING)


## The best board in the hero's loadout ("skateboard", or a camp's "old_skateboard"), or "".
func board() -> String:
	return _w.loadout.ride("board")


## How fast the board goes flat out: an old one from a homeless camp, slower (ItemDef.speed).
func top_speed() -> float:
	var b := board()
	return TOP_SPEED * (Catalog.item(b).speed if b != "" else 1.0) * (ROUGH if rough else 1.0)


## Returns {ok, text}.
func mount() -> Dictionary:
	var why := why_not()
	if why != "":
		return {"ok": false, "text": why}
	_w.hero.enter(Hero.Mode.SKATING)
	speed = 0.0
	charge = 0.0
	in_air = false
	flipped = false
	return {"ok": true, "text": "You step onto the board. W push, A and D steer, S brake, hold Space and let go to ollie, tap it again in the air to kickflip."}


## The board hit something solid (a wall, a kerb it didn't ollie) going `at_speed`: it stops dead, and if that was faster
## than BAIL_SPEED, you bail. Returns whether you did.
func bump(at_speed := 0.0) -> bool:
	speed = 0.0
	charge = 0.0
	if at_speed < BAIL_SPEED or bailing:
		return false
	bailing = true
	bail_left = BAIL_TIME
	bails += 1
	last_trick = "Bail"
	return true


func dismount() -> void:
	if mounted:
		_w.hero.stand()
	speed = 0.0
	charge = 0.0
	in_air = false
	flipped = false
	grinding = false
	bailing = false


## One physics step of the board. `input` says what the player is doing: push (bool), brake (bool), steer (-1..1, left is
## positive), jump_down (the jump key is held) and jump_pressed (it was pressed this frame); and, for grinding, where the
## board is: height (above the street), heading (the way it faces, a unit Vector2) and falling (coming down). `grounded` is
## whether the body is on the floor, and `at` where it is on the ground. Returns {speed, turn, jump, flip, grind}: how fast to
## roll, how many radians a second to turn, the upward speed to launch with (0 for none), whether a kickflip was done this
## frame, and whether it is grinding; while it is, also grind_at (where the board is on the kerb) and grind_heading.
func step(dt: float, input: Dictionary, grounded: bool, at: Vector2) -> Dictionary:
	if bailing:  # on the ground: no board, no keys, till you're up
		bail_left -= dt
		speed = 0.0
		if bail_left <= 0.0:
			bailing = false
		return {"speed": 0.0, "turn": 0.0, "jump": 0.0, "flip": false, "grind": false, "bail": bailing}
	if grinding:
		return _grind(dt, input)
	if in_air and not grounded and input.get("falling", false) and _catch(at, float(input.get("height", 0.0)), input.get("heading", Vector2.ZERO)):
		return _grind(0.0, {})
	_since_kick += dt
	var rolling := grounded and not in_air
	rough = rolling and input.get("rough", false)
	if speed > top_speed():  # onto cobbles going fast: they shake it out of you
		speed = maxf(top_speed(), speed - ROUGH_DRAG * dt)
	if input.get("kick", false) and rolling and _since_kick >= KICK_EVERY:  # a push with the foot
		speed = minf(top_speed(), speed + KICK)
		_since_kick = 0.0
		kicks += 1
	elif input.get("push", false):
		speed = minf(top_speed(), speed + ACCEL * dt)
		if rolling and _since_kick >= KICK_EVERY * 2.0:  # (holding W pushes too: the foot goes down now and then)
			_since_kick = 0.0
			kicks += 1
	elif rolling and _crouched > CHARGE_TIME + PUMP_AFTER and speed < top_speed() * PUMP_TOP:  # crouched long: pumping
		speed = minf(top_speed() * PUMP_TOP, speed + PUMP_ACCEL * dt)
	elif input.get("brake", false):
		speed = maxf(0.0, speed - BRAKE * dt)
	else:
		speed = maxf(0.0, speed - COAST * dt)
	var out := {"speed": speed, "turn": float(input.get("steer", 0.0)) * TURN_RATE * clampf(speed / 4.0, 0.4, 1.0), "jump": 0.0, "flip": false, "grind": false}
	if not grounded:
		in_air = true
	elif in_air:
		in_air = false  # landed
		flipped = false
	if in_air:
		charge = 0.0
		_crouched = 0.0
		if input.get("jump_pressed", false) and not flipped:
			flipped = true
			kickflips += 1
			last_trick = "Kickflip  +$%d" % int(KICKFLIP_CASH)
			spray(at)
			out.flip = true
	else:
		if input.get("jump_down", false):
			charge = minf(1.0, charge + dt / CHARGE_TIME)
			_crouched += dt
		elif charge > 0.0:  # let go: ollie
			_crouched = 0.0
			out.jump = lerpf(OLLIE_MIN, OLLIE_MAX, charge)
			charge = 0.0
			in_air = true
			ollies += 1
			last_trick = "Ollie"
	return out


## Coming down at `at`, `height` above the street, facing `heading`: is there a kerb line to catch? If so, the grind begins.
func _catch(at: Vector2, height: float, heading: Vector2) -> bool:
	if kerbs == null or speed < GRIND_MIN_SPEED or heading == Vector2.ZERO:
		return false
	var above := height - Kerbs.HEIGHT
	if above < -0.05 or above > GRIND_ABOVE:
		return false
	var best := -1
	var best_d := INF
	for i in kerbs.edges_near(at, GRIND_REACH):
		var e: Dictionary = kerbs.edges[i]
		var along: Vector2 = (e.b - e.a).normalized()
		if absf(along.dot(heading)) < GRIND_ALIGN:
			continue
		var d := Geometry2D.get_closest_point_to_segment(at, e.a, e.b).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	var e: Dictionary = kerbs.edges[best]
	_edge = best
	_dir = 1.0 if (e.b - e.a).dot(heading) >= 0.0 else -1.0
	_along = (Geometry2D.get_closest_point_to_segment(at, e.a, e.b) - e.a).length()
	grinding = true
	in_air = false
	flipped = false
	grinds += 1
	grind_metres = 0.0
	grind_paid = 0.0
	_since_bill = 0.0
	last_trick = "Grind"
	return true


# A step along the kerb line: slower for the edge's drag, a bill every GRIND_EVERY metres, onto the next line where this one
# ends, and off with a jump or when it has run out (of kerb or speed).
func _grind(dt: float, input: Dictionary) -> Dictionary:
	var e: Dictionary = kerbs.edges[_edge]
	var out := {"speed": speed, "turn": 0.0, "jump": 0.0, "flip": false, "grind": true}
	if input.get("jump_pressed", false):
		return _off(out, OLLIE_MIN)
	speed = maxf(0.0, speed - GRIND_DRAG * dt)
	var step := speed * dt
	_along += _dir * step
	grind_metres += step
	_since_bill += step
	var length: float = (e.b - e.a).length()
	if _since_bill >= GRIND_EVERY:  # (paid for the distance covered, the kerb's end included)
		_since_bill -= GRIND_EVERY
		_strew_behind(e, length)
		grind_paid += 1.0
	if _along < 0.0 or _along > length:
		var end: Vector2 = e.b if _along > length else e.a
		var next := _linked(end, (e.b - e.a).normalized() * _dir)
		if next < 0:
			return _off(out, 0.0)
		var n: Dictionary = kerbs.edges[next]
		_edge = next
		_dir = 1.0 if n.a.distance_to(end) <= n.b.distance_to(end) else -1.0
		_along = 0.0 if _dir > 0.0 else (n.b - n.a).length()
		e = n
	if speed < GRIND_MIN_SPEED:
		return _off(out, 0.0)
	var dir: Vector2 = (e.b - e.a).normalized()
	var at: Vector2 = e.a + dir * _along
	out.grind_at = at
	out.grind_heading = dir * _dir
	return out


# A grind's $1, strewn on the pavement behind the board: a trail to come back for (out of reach as it lands).
func _strew_behind(e: Dictionary, length: float) -> void:
	var dice := _w.random()
	var dir: Vector2 = (e.b - e.a).normalized()
	var board: Vector2 = e.a + dir * clampf(_along, 0.0, length)
	var back := clampf(_along - _dir * dice.randf_range(TRAIL_BEHIND.x, TRAIL_BEHIND.y), minf(0.5, length * 0.5), maxf(length - 0.5, length * 0.5))
	var across := dice.randf_range(TRAIL_ACROSS.x, TRAIL_ACROSS.y)
	var at: Vector2 = e.a + dir * back + (e.side as Vector2) * across
	if at.distance_to(board) <= Commerce.PICKUP_REACH + 0.2:  # (just onto a new kerb line: nothing behind on it yet)
		at = e.a + dir * back + (e.side as Vector2) * (Commerce.PICKUP_REACH + 0.3)
	_w.gun.land(_w.gun.fire(1.0, "cash"), at)


# The kerb line that carries on from `end`, going `heading` (-1 if none).
func _linked(end: Vector2, heading: Vector2) -> int:
	for i in kerbs.edges_near(end, GRIND_LINK):
		if i == _edge:
			continue
		var n: Dictionary = kerbs.edges[i]
		var near_a: bool = n.a.distance_to(end) <= n.b.distance_to(end)
		if minf(n.a.distance_to(end), n.b.distance_to(end)) > GRIND_LINK:
			continue
		var going: Vector2 = (n.b - n.a).normalized() * (1.0 if near_a else -1.0)
		if going.dot(heading) >= GRIND_ALIGN:
			return i
	return -1


# Off the kerb: into the air, popping up `jump` (0: rolling off the end).
func _off(out: Dictionary, jump: float) -> Dictionary:
	grinding = false
	in_air = true
	last_trick = "Grind  %d m  +$%d" % [roundi(grind_metres), int(grind_paid)]
	out.grind = false
	out.jump = jump
	out.ended = true
	return out


## Sprays the kickflip's cash on the ground round `at`: printed now, lying there as loose bills. Returns the bills.
func spray(at: Vector2) -> Array[Bill]:
	var laid: Array[Bill] = []
	var dice := _w.random()
	for k in KICKFLIP_BILLS:
		var angle := TAU * (float(k) + dice.randf_range(0.1, 0.9)) / KICKFLIP_BILLS
		var b := _w.gun.fire(KICKFLIP_CASH / KICKFLIP_BILLS, "cash")
		laid.append(_w.gun.land(b, at + Vector2.from_angle(angle) * dice.randf_range(KICKFLIP_STREW.x, KICKFLIP_STREW.y)))
	return laid
