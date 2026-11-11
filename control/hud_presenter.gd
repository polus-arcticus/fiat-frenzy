## CONTROLLER. Every frame, tells the HUD and the beacon what the model says: the hero's bars and cash, the clock,
## the gun, whoever is aimed at, the objective (a quest if one is on, otherwise the tutorial's), the news feed, and
## "picked up $N". The HUD itself only draws what it is given.
class_name HudPresenter
extends RefCounted

var world: World
var hud: Hud
var player: PlayerController
var gun: GunController
var inventory: InventoryScreen
var tutorial: Tutorial
var marker: MarkerView

var _events_seen := 0
var _picked_up := 0.0
var _pickup_in := 0.0


func _init(w: World, h: Hud, p: PlayerController, g: GunController, inv: InventoryScreen, t: Tutorial, m: MarkerView) -> void:
	world = w
	hud = h
	player = p
	gun = g
	inventory = inv
	tutorial = t
	marker = m


## Money the hero picked up since last time, to be reported in a batch.
func picked_up(amount: float) -> void:
	_picked_up += amount


func update(delta: float, time_scale: float) -> void:
	_pickup_in -= delta
	if _pickup_in <= 0.0:
		_pickup_in = 0.5
		if _picked_up > 0.0:
			hud.notify("picked up $%d" % roundi(_picked_up))
			_picked_up = 0.0
	hud.show_player(world.player, world.ledger.player_cash)
	hud.show_world(world, time_scale)
	hud.show_mode(gun.mode)
	hud.show_charge(gun.charge, gun.contract_value(gun.charge))
	hud.show_target(null if inventory.visible else gun.aim().drone, world)
	tutorial.update(player.ground_pos())
	var quest := world.quests.objective()
	hud.show_objective(quest.text if not quest.is_empty() else tutorial.text())
	var m: Variant = current_marker()
	if m == null:
		marker.hide_marker()
	else:
		marker.point_at(m, "%d m" % int(player.ground_pos().distance_to(m)), player.ground_pos())
	while _events_seen < world.events.size():
		hud.notify(world.events[_events_seen])
		_events_seen += 1


## Where the beacon points: the quest's objective if there is one on, otherwise the tutorial's.
func current_marker() -> Variant:
	var quest := world.quests.objective()
	return quest.at if not quest.is_empty() else tutorial.marker()
