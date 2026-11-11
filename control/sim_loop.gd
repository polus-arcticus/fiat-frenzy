## Drives the model from the game's clock: turns frame time into fixed sim steps, at a chosen speed, and can be
## held still by anything that needs the world to wait (the intro, a conversation, the bus ride).
##
## Holds are named, not a single on/off flag, so two things that pause at once cannot un-pause each other: the
## sim runs only when nothing is holding it. Each holder releases its own hold, and nobody has to remember what
## the state was before.
class_name SimLoop
extends RefCounted

const STEP := 0.1
const SPEEDS := [1.0, 2.0, 4.0, 8.0, 20.0]
const MAX_STEPS_PER_FRAME := 40  # past this the sim drops the backlog rather than spiral

var speed := 2.0
var _speed_index := 1
var _holds := {}
var _acc := 0.0
var _world: World


func _init(world: World) -> void:
	_world = world


func paused() -> bool:
	return not _holds.is_empty()


## `reason` holds the sim still, or lets it go again.
func hold(reason: String, on := true) -> void:
	if on:
		_holds[reason] = true
	else:
		_holds.erase(reason)


## The next speed in SPEEDS, wrapping round.
func cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	speed = SPEEDS[_speed_index]


## Called every physics frame with its delta.
func update(delta: float) -> void:
	if paused():
		return
	_acc += delta * speed
	var steps := 0
	while _acc >= STEP and steps < MAX_STEPS_PER_FRAME:
		_world.tick(STEP)
		_acc -= STEP
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_acc = 0.0
