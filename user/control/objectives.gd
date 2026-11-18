## What the hero is being asked to do, as the HUD shows it: a line of text, a point for the beacon, and news of what they have
## just done. The user space only knows this shape; the story fills it in (the tutorial is one: see Tutorial). With nothing
## to say, it says nothing.
class_name Objectives
extends RefCounted


## Called every frame with where the hero stands.
func update(_player: Vector2) -> void:
	pass


## What the hero has just done, in words, once each.
func take_news() -> Array[String]:
	return []


## The objective line.
func text() -> String:
	return ""


## Where the beacon points, or null.
func marker() -> Variant:
	return null
