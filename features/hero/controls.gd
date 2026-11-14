## CONTROLLER. Registers the input actions in code, so the project file stays small.
class_name Controls
extends RefCounted


static func register() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("inventory", KEY_TAB)
	_key("chat", KEY_Q)
	_key("interact", KEY_E)
	_key("mount", KEY_F)
	_key("map", KEY_M)
	_key("view", KEY_V)
	_key("board", KEY_B)
	_keys("skip", [KEY_ENTER, KEY_SPACE])
	_key("speed", KEY_T)
	_key("help", KEY_F1)
	_key("release", KEY_ESCAPE)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", e)


static func _key(action: String, keycode: Key) -> void:
	_keys(action, [keycode])


static func _keys(action: String, keycodes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keycodes:
		var e := InputEventKey.new()
		e.physical_keycode = keycode
		InputMap.action_add_event(action, e)
