## VIEW PART. A speech bubble: dark ink on a thick paper-coloured outline, floating over a drone's head, which
## wraps long lines and fades in and out as the drone's `speech` changes. Reads a Drone; owns nothing.
class_name Bubble
extends Label3D

const INK := Color(0.16, 0.14, 0.2)
const PAPER := Color(0.99, 0.96, 0.86)
const STANDING_Y := 3.35
const LYING_Y := 1.9
const FADE_IN := 0.15
const FADE_OUT := 0.5

var _seen := 0
var _left := 0.0   # real seconds it has left on screen (the game may be running fast, or paused)
var _age := 0.0


func _init() -> void:
	name = "Bubble"
	font_size = 52
	outline_size = 36
	pixel_size = 0.00062
	width = 600.0
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	render_priority = 5
	outline_render_priority = 4
	visibility_range_end = 16.0
	modulate = INK
	outline_modulate = PAPER
	position = Vector3(0, STANDING_Y, 0)
	visible = false


## Shows the drone's current line, if it has one. `lying`: they are on the ground, so the bubble sits lower.
## `k` eases the position this frame; `delta` is real time, so a line is readable at any game speed.
func refresh(drone: Drone, lying: bool, k: float, delta: float) -> void:
	position.y = lerpf(position.y, LYING_Y if lying else STANDING_Y, k)
	if drone.speech_seq != _seen:
		_seen = drone.speech_seq
		text = drone.speech
		_left = Chatter.LINE_TIME
		_age = 0.0
	_left = maxf(0.0, _left - delta)
	_age += delta
	visible = _left > 0.0 and text != "" and not drone.unconscious()
	if visible:
		var a := minf(clampf(_age / FADE_IN, 0.0, 1.0), clampf(_left / FADE_OUT, 0.0, 1.0))
		modulate.a = a
		outline_modulate.a = a
