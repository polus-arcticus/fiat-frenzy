## The hero: how they are moving about right now. One mode at a time (on foot, on the bike, on the board, in a seat), so
## "can I get on this?" is answered in one place and nothing can be riding and skating at once. The rules of each mode
## (the bike's reach, the board's tricks) stay with that mode's own feature; this only says which one the hero is in, and
## whether they are allowed to change.
class_name Hero
extends RefCounted

enum Mode { ON_FOOT, RIDING, SKATING, SEATED }

var mode: Mode = Mode.ON_FOOT

var _w: World


func _init(world: World) -> void:
	_w = world


func is_on_foot() -> bool:
	return mode == Mode.ON_FOOT


## Why the hero can't switch to `to` right now, or "". (Going back on foot is always allowed.)
func why_not(to: Mode) -> String:
	if to == Mode.ON_FOOT:
		return ""
	if mode == to:
		return "You're already on it."
	if _w.player != null and _w.player.unconscious():
		return "You're out cold."
	match mode:
		Mode.RIDING:
			return "Get off the bike first."
		Mode.SKATING:
			return "Get off the skateboard first."
		Mode.SEATED:
			return "Stand up first."
	return ""


## Switches mode if allowed. Returns "" on success, else the reason.
func enter(to: Mode) -> String:
	var why := why_not(to)
	if why == "":
		mode = to
	return why


## Back on their own two feet, whatever they were doing.
func stand() -> void:
	mode = Mode.ON_FOOT
