## CONTROLLER. Walking through a teleporter ring. The rule is the model's (Portals, Portal); this moves the
## player's body to the twin ring and says so. Called every frame by GameController.
class_name PortalController
extends Node

var world: World
var player: PlayerController
var hud: Hud


func setup(w: World, p: PlayerController, h: Hud) -> PortalController:
	world = w
	player = p
	hud = h
	return self


## Sends the player through if they are standing in a ring. Returns true if they went.
func update() -> bool:
	if world.player.care != "" or not player.controls_enabled:
		return false
	var ring := world.portals.at(player.ground_pos())
	if ring == null or ring.twin == null:
		return false
	var out := ring.twin.exit_point()
	player.teleport(Vector3(out.x, 0.1, out.y), ring.twin.exit_yaw())
	player.level_gaze()
	world.portals.cross(world.player, ring)
	world.cash.collect_for_player()
	hud.notify("You step through the ring.")
	return true
