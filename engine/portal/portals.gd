## Teleporters: rings that come in pairs. Stepping into one puts you out of the other.
class_name Portals
extends RefCounted

var all: Array[Portal] = []
var _w: World  # (only to name new rings; may be null in a test)


func _init(world: World = null) -> void:
	_w = world


## Makes two rings that lead to each other. Returns [a, b].
func add_pair(a: Portal, b: Portal) -> Array[Portal]:
	a.twin = b
	b.twin = a
	if _w != null:
		_w.mint(a)
		_w.mint(b)
	all.append(a)
	all.append(b)
	return [a, b]


## Carry `who` (the hero or any walker) through `ring` to its twin: they come out clear of it, in the twin's zone.
func cross(who: Drone, ring: Portal) -> void:
	who.zone = ring.twin.zone
	who.pos = ring.twin.exit_point()


## The ring that `p` is standing in, or null. (A player who has just come out of one is clear of it.)
func at(p: Vector2) -> Portal:
	for portal in all:
		if portal.contains(p):
			return portal
	return null
