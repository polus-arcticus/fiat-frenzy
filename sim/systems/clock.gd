## Time. One tick = one second, DAY_SECONDS ticks = one day, the last part of it night. Day 0 starts
## at 6am, so night runs from about 8:30pm to 6am.
class_name Clock
extends RefCounted

const DAY_SECONDS := 600.0
const NIGHT_FROM := 0.6  # the fraction of the day when night falls

var time := 0.0


func advance(dt: float) -> void:
	time += dt


func fraction() -> float:
	return fmod(time, DAY_SECONDS) / DAY_SECONDS


func is_night() -> bool:
	return fraction() >= NIGHT_FROM


func day() -> int:
	return int(time / DAY_SECONDS)


## Wall-clock text, e.g. "20:36".
func text() -> String:
	var h := fmod(6.0 + fraction() * 24.0, 24.0)
	return "%02d:%02d" % [int(h), int((h - floorf(h)) * 60.0)]
