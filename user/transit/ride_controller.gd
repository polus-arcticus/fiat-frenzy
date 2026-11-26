## CONTROLLER. One ride, on anything (a Vehicle, drawn by a VehicleView): the door opens, the hero walks in and sits, the vehicle
## drives itself (the town carries on all the while: nothing is paused), and where it stops the door opens again and the hero
## steps out onto the kerb on its door's side. Whoever wants a ride (the line rider, the story's quests) says what sets the
## vehicle off and what the captions say; the walking, the seat and the doors are all here.
class_name RideController
extends Node

var world: World
var player: PlayerController
var hud: Hud
var game: Node  # has `advance(seconds)` (the world run by hand: tests and tools)
## Skip the waiting in the captions and walks, and run the world here (tests and tools: no frames to wait for).
var fast := false
var riding := false


func setup(w: World, p: PlayerController, h: Hud, g: Node) -> RideController:
	world = w
	player = p
	hud = h
	game = g
	name = "RideController"
	return self


## The ride on `model`, drawn as `view`: `go` sets it off (Transit.ride or Transit.board; false: it didn't, and the hero gets
## up again). `board` and `arrive` are the captions; `walk_in` and `walk_off` how long the walks to the seat and out take.
## Returns when the hero is off again (or has passed out on the way: then the medical tent's controller gives them back their
## body, not this).
func ride(view: VehicleView, model: Vehicle, go: Callable, board := "", arrive := "", walk_in := 3.4, walk_off := 2.4) -> void:
	if riding or model == null:
		return
	riding = true
	player.controls_enabled = false
	hud.show_prompt("")
	view.door_toward(player.global_position)
	view.open_door()
	await _wait(0.9)
	await _walk([player.global_position, view.kerb_point(), view.doorway_point(), view.seat_point()], walk_in)
	player.scripted = false
	player.teleport(view.seat_point(), view.rotation.y + PI)  # facing the front
	player.level_gaze()
	player.sit(view, view.seat_local())
	world.hero.enter(Hero.Mode.SEATED)
	view.close_door()
	if board != "":
		hud.show_caption(board, 0.0 if fast else 3.0)
	await _wait(0.8)
	if go.call():
		while model.state == Vehicle.State.DRIVING:
			if fast:
				_follow(view, model)
				game.advance(1.0)
			await get_tree().process_frame
	_follow(view, model)
	await _wait(0.6)
	view.door_to_alight()
	view.open_door()
	if world.player.care != "":
		riding = false  # (they passed out on the way: nobody gets up; the ambulance comes to the vehicle)
		return
	if arrive != "":
		hud.show_caption(arrive, 0.0 if fast else 3.5)
	await _wait(0.9)
	world.hero.stand()
	player.stand()
	var gathered := world.commerce.scoop_aboard(model)# whatever is lying on the floor goes with them
	if gathered > 0.0:
		hud.notify("picked up $%d from the floor" % roundi(gathered))
	player.scripted = true
	var out := view.kerb_point()
	await _walk([player.global_position, view.doorway_point(), out], walk_off)
	player.scripted = false
	player.teleport(Vector3(out.x, out.y + 0.1, out.z), 0.0)
	var outward := out - view.doorway_point()
	player.look_toward(Vector3(out.x + outward.x * 6.0, 1.5, out.z + outward.z * 6.0))  # facing away from the door
	player.level_gaze()
	world.player.pos = Vector2(out.x, out.z)
	world.transit.disembark(model)
	if world.player.care == "":
		player.controls_enabled = true
	riding = false
	await _wait(1.2)
	view.close_door()


## Where the vehicle is in the model, for its view and the seated hero (tests and tools step the world without frames).
func _follow(view: VehicleView, model: Vehicle) -> void:
	view.place(model.pos, VehicleView._yaw_of(model.heading))
	player.update_seat()


func _wait(seconds: float) -> void:
	if fast:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout


## Walk the hero along `points` (world positions of their feet) in `seconds`, turning to look where they are going. They are
## moved by this and not by the keys while it lasts. (Fast: they are simply put at the end.)
func _walk(points: Array, seconds: float) -> void:
	player.scripted = true
	world.hero.stand()
	player.stand()
	if fast:
		player.teleport(points[points.size() - 1], player.rotation.y)
		return
	var total := 0.0
	for i in points.size() - 1:
		total += (points[i] as Vector3).distance_to(points[i + 1])
	var tween := create_tween()
	tween.tween_method(_walk_step.bind(points, total), 0.0, 1.0, seconds)
	await tween.finished


func _walk_step(t: float, points: Array, total: float) -> void:
	var at := t * total
	for i in points.size() - 1:
		var leg: float = (points[i] as Vector3).distance_to(points[i + 1])
		if at <= leg or i == points.size() - 2:
			var k := clampf(at / maxf(leg, 0.001), 0.0, 1.0)
			player.global_position = (points[i] as Vector3).lerp(points[i + 1], k)
			var ahead: Vector3 = points[i + 1]
			player.look_toward(Vector3(ahead.x, 1.3, ahead.z), 0.08)
			return
		at -= leg
