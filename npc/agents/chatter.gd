## People talking. Anyone who is awake says one of three things when the player comes close (not often, and
## not twice in a row), and one thing each when they pick up loose money, are given money, or are invested
## in. Money lines are throttled so a burst of bills makes one line, and they cut in on a "close" line. What each person last
## said is kept here (`of`: a Speech), for the view to show; nothing here knows how, and nothing of it is saved.
## It uses its own random numbers, so talk never changes what the rest of the simulation does.
class_name Chatter
extends RefCounted

const NEAR_RANGE := 6.0      # how close the player must be to be spoken to
const NEAR_CHANCE := 0.35    # each second someone is in range and free to talk
const NEAR_COOLDOWN := 25.0  # seconds before the same person says another "close" line
const EVENT_THROTTLE := 2.5  # seconds before the same person says another money line
const LINE_TIME := 3.2       # how long a line stays up

var _w: World
var _rng := RandomNumberGenerator.new()
var _since_check := 0.0
var _said := {}  # uid -> Speech (Snapshot.DERIVED: not saved)


func _init(world: World) -> void:
	_w = world
	_rng.seed = 4242


## What `d` last said, and their cooldowns.
func of(d: Drone) -> Speech:
	var s: Speech = _said.get(d.uid)
	if s == null:
		s = Speech.new()
		_said[d.uid] = s
	return s


func step(dt: float) -> void:
	for z in _w.zones.running():
		for d in _w.zones.drones_in(z):
			var s: Speech = _said.get(d.uid)
			if s == null:
				continue
			s.ttl = maxf(0.0, s.ttl - dt)
			s.near_cooldown = maxf(0.0, s.near_cooldown - dt)
			s.event_cooldown = maxf(0.0, s.event_cooldown - dt)
	_since_check += dt
	if _since_check < 1.0:
		return
	_since_check = 0.0
	if _w.player == null:
		return
	for d in _w.zones.drones_in(_w.player.zone):  # people only talk up to the hero, so only in the hero's zone
		var s := of(d)
		if d.unconscious() or s.near_cooldown > 0.0 or s.ttl > 0.0:
			continue
		if d.pos.distance_to(_w.player.pos) <= NEAR_RANGE and _rng.randf() < NEAR_CHANCE:
			say(d, Lines.NEAR)


## `d` says something for `event` (near, cash, gift or invest). Returns whether they did.
func say(d: Drone, event: String) -> bool:
	if d.unconscious():
		return false
	var s := of(d)
	if event != Lines.NEAR and s.event_cooldown > 0.0:
		return false
	var options := Lines.for_event(d, event)
	var line: String = options[_rng.randi() % options.size()]
	if event == Lines.NEAR and line == s.line:
		line = options[(options.find(line) + 1) % options.size()]  # never the same line twice running
	s.line = line
	s.ttl = LINE_TIME
	s.seq += 1
	if event == Lines.NEAR:
		s.near_cooldown = NEAR_COOLDOWN
	else:
		s.event_cooldown = EVENT_THROTTLE
	return true


## `d` says exactly `line` (for a character who has something particular to say). Returns whether they did.
func say_line(d: Drone, line: String) -> bool:
	if d.unconscious():
		return false
	var s := of(d)
	s.line = line
	s.ttl = LINE_TIME + 1.0
	s.seq += 1
	return true
