## Who needs the player's help right now, shown as a gold glow (`Drone.aura`): a vendor whose business is wrecked and
## not yet funded, and a banker who has not yet had a proper meal. The glow goes out when they have what they need,
## so a glance down the street says who is left to look after. Nothing here changes the world but the flag.
class_name Attention
extends RefCounted

var _w: World


func _init(world: World) -> void:
	_w = world


func step() -> void:
	for z in _w.zones.running():
		for d in _w.zones.drones_in(z):
			d.aura = wants_help(d)


## Does this person need the player's help?
func wants_help(d: Drone) -> bool:
	if d.kind == "vendor" and d.station >= 0:
		var m := _w.machine_of(d)
		return not m.working and not Catalog.machine(m.kind).rich  # the rich owner of the bike shop never needs anything
	if d.look == "banker":
		return not _w.quests.fed.has(d.id)
	return false
