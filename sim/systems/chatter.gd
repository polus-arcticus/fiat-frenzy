## People talking. Anyone who is awake says one of three things when the player comes close (not often, and
## not twice in a row), and one thing each when they pick up loose money, are given money, or are invested
## in. Money lines are throttled so a burst of bills makes one line, and they cut in on a "close" line. The
## line sits on the drone (`speech`) for the view to show; nothing here knows how.
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


func _init(world: World) -> void:
	_w = world
	_rng.seed = 4242


func step(dt: float) -> void:
	for z in _w.zones.running():
		for d in _w.zones.drones_in(z):
			d.speech_ttl = maxf(0.0, d.speech_ttl - dt)
			d.chat_cooldown = maxf(0.0, d.chat_cooldown - dt)
			d.event_cooldown = maxf(0.0, d.event_cooldown - dt)
	_since_check += dt
	if _since_check < 1.0:
		return
	_since_check = 0.0
	if _w.player == null:
		return
	for d in _w.zones.drones_in(_w.player.zone):  # people only talk up to the hero, so only in the hero's zone
		if d.unconscious() or d.chat_cooldown > 0.0 or d.speech_ttl > 0.0:
			continue
		if d.pos.distance_to(_w.player.pos) <= NEAR_RANGE and _rng.randf() < NEAR_CHANCE:
			say(d, Lines.NEAR)


## `d` says something for `event` (near, cash, gift or invest). Returns whether they did.
func say(d: Drone, event: String) -> bool:
	if d.unconscious():
		return false
	if event != Lines.NEAR and d.event_cooldown > 0.0:
		return false
	var options := Lines.for_event(d, event)
	var line: String = options[_rng.randi() % options.size()]
	if event == Lines.NEAR and line == d.speech:
		line = options[(options.find(line) + 1) % options.size()]  # never the same line twice running
	d.speech = line
	d.speech_ttl = LINE_TIME
	d.speech_seq += 1
	if event == Lines.NEAR:
		d.chat_cooldown = NEAR_COOLDOWN
	else:
		d.event_cooldown = EVENT_THROTTLE
	return true


## `d` says exactly `line` (for a character who has something particular to say). Returns whether they did.
func say_line(d: Drone, line: String) -> bool:
	if d.unconscious():
		return false
	d.speech = line
	d.speech_ttl = LINE_TIME + 1.0
	d.speech_seq += 1
	return true
