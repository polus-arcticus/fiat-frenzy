## CONTROLLER. Everything about full-screen screens that take the player's attention (the bag, the map, a
## conversation). Screens register here. While any is open the player's controls are off and the mouse is free; when
## the last closes they come back, so no screen or controller has to do that itself. It is also the one place Esc is
## handled: Esc closes the one on top, and only when none is open does it free the mouse. So Esc never does both,
## and it never depends on which node happens to see the key first.
class_name ScreenStack
extends Node

signal mouse_freed

var _open: Array = []
## Whose controls to take while a screen is open (set by whoever builds the game).
var player: PlayerController = null


## A screen needs `opened` and `closed` signals and a `close()` method.
func register(screen) -> void:
	screen.opened.connect(func():
		_open.append(screen)
		_lock(true))
	screen.closed.connect(func():
		_open.erase(screen)
		if _open.is_empty():
			_lock(false))


func _lock(on: bool) -> void:
	if player != null:
		player.controls_enabled = not on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func depth() -> int:
	return _open.size()


## Closes every open screen (the player has passed out).
func close_all() -> void:
	for screen in _open.duplicate():
		screen.close()


func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed("release"):
		return
	if not _open.is_empty():
		_open.back().close()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_freed.emit()
	get_viewport().set_input_as_handled()
