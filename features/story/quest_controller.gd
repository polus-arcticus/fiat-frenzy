## CONTROLLER. The player's side of quests: talking to the banker who has the letter (Q), and the bus ride. The
## rules are the model's (Quests); this opens the dialogue, takes and gives back the controls, and plays the
## bus ride (the hero boards and sits, the bus drives itself to the traffic jam on Battonnstraße, the hero steps out).
class_name QuestController
extends Node

var world: World
var player: PlayerController
var hud: Hud
var dialogue: DialogueScreen
var game: Node  # has `sim` (a SimLoop)
var scenario: Scenario
var bus: BusView
var fade: FadeScreen
## Skip the waiting in the fades and captions (tests and tools).
var fast := false
var riding_the_bus := false

const BOARD_REACH := 6.0

var _jam_built := false
var _jam_cleared := false
var _delivering := false  # the dialogue being read is the doorman's, not the banker's


func setup(w: World, p: PlayerController, h: Hud, d: DialogueScreen, g: Node, sc: Scenario, b: BusView, f: FadeScreen) -> QuestController:
	world = w
	player = p
	hud = h
	dialogue = d
	game = g
	scenario = sc
	bus = b
	fade = f
	name = "QuestController"
	return self


## Q at any banker (they all have the letter in mind), or at the doorman to hand it over.
func talk(who: Drone) -> void:
	if who == world.ecb_doorman:
		_talk_doorman()
		return
	if not world.quests.is_banker(who) or dialogue.visible or not player.controls_enabled:
		return
	var state: String = world.quests.state.get(QuestBook.LETTER, "")
	if state == "offered":
		dialogue.handler = self
		game.sim.hold("quest")
		hud.show_prompt("")
		player.look_toward(Vector3(who.pos.x, 1.55, who.pos.y))
		dialogue.read(who.label, QuestBook.quest(QuestBook.LETTER).offer)
	elif state == "active":
		world.chatter.say_line(who, QuestBook.quest(QuestBook.LETTER).reminder)


func _talk_doorman() -> void:
	if not world.quests.can_deliver() or dialogue.visible or not player.controls_enabled:
		return
	_delivering = true
	dialogue.handler = self
	game.sim.hold("quest")
	hud.show_prompt("")
	var d := world.ecb_doorman
	player.look_toward(Vector3(d.pos.x, 1.55, d.pos.y))
	dialogue.read(d.label, QuestBook.quest(QuestBook.LETTER).delivery)


## The request has been read through: the quest is accepted.
func dialogue_finished() -> void:
	if _delivering:
		world.quests.deliver()
	else:
		world.quests.accept(QuestBook.LETTER)
	dialogue.close()


func dialogue_closed() -> void:
	_delivering = false
	game.sim.hold("quest", false)


## Can the hero board the bus now? Not while out cold or on the bike, and only on the letter quest. First at its stop,
## before the first ride; later where it stands in the cleared street, once Mr. Nobody has said farewell.
func can_board() -> bool:
	if world.quests.active() != QuestBook.LETTER or riding_the_bus or world.bus == null:
		return false
	if not world.hero.is_on_foot() or world.player.unconscious() or not player.controls_enabled:
		return false
	if not world.quests.done("rode_bus"):
		return world.bus.state == Bus.State.AT_STOP and player.ground_pos().distance_to(world.bus_stop) <= BOARD_REACH
	if world.quests.done("jam_cleared") and not world.quests.done("rode_on") and world.bus.state == Bus.State.ARRIVED:
		return player.global_position.distance_to(bus.kerb_point()) <= BOARD_REACH
	return false


func board() -> void:
	if not can_board():
		return
	if not world.quests.done("rode_bus"):
		ride()
	else:
		ride_on()


## The first ride: to the traffic jam outside Mr. Nobody's house.
func ride() -> void:
	if scenario.jam.is_empty():
		return
	_build_jam()  # the queue is there to be seen on the way in
	await _ride({
		"dest": scenario.jam.bus.pos, "via": [], "flag": "rode_bus",
		"board": "The bus to the European Central Bank. Everyone aboard is a banker.",
		"arrive": "Traffic. Of course. The driver opens the doors: \"Everybody out. We are not going anywhere.\"",
	})


## The second: the traffic has cleared, and the bus goes on to the European Central Bank.
func ride_on() -> void:
	if scenario.ecb_stop.is_empty():
		return
	await _ride({
		"dest": scenario.ecb_stop.bus, "via": scenario.ecb_stop.via, "flag": "rode_on",
		"board": "On to the European Central Bank. The bankers aboard are checking their watches.",
		"arrive": "Sonnemannstraße. The driver opens the doors: \"European Central Bank. Mind the step, and the interest rates.\"",
	})


## One bus ride. The door opens, the hero walks in and sits down, the bus drives itself along the streets (the town
## carries on all the while: nothing is paused), and where it stops the door opens again and the hero steps out onto
## the kerb on its right-hand side.
func _ride(leg: Dictionary) -> void:
	if world.bus == null:
		return
	riding_the_bus = true
	player.controls_enabled = false
	hud.show_prompt("")
	bus.open_door()
	await _wait(0.9)
	await _walk([player.global_position, bus.kerb_point(), bus.doorway_point(), bus.seat_point()], 3.4)
	player.scripted = false
	player.teleport(bus.seat_point(), bus.rotation.y + PI)  # facing the front of the bus
	player.level_gaze()
	player.sit(bus, BusView.SEAT_LOCAL)
	world.hero.enter(Hero.Mode.SEATED)
	bus.close_door()
	hud.show_caption(leg.board, 0.0 if fast else 3.0)
	await _wait(0.8)
	world.transit.board(leg.dest, leg.flag, leg.via)
	while world.bus.state == Bus.State.DRIVING:
		if fast:  # tests and tools: no frames to wait for, so run the world here
			_follow_model()
			game.advance(1.0)
		await get_tree().process_frame
	_follow_model()
	await _wait(0.6)
	bus.open_door()
	if world.player.care != "":
		# They passed out on the way. Nobody gets up: the ambulance will come to the bus, and the medical tent's
		# controller (not this) gives them their body and controls back when they wake.
		riding_the_bus = false
		return
	hud.show_caption(leg.arrive, 0.0 if fast else 3.5)
	await _wait(0.9)
	world.hero.stand()
	player.stand()
	player.scripted = true
	var out := bus.kerb_point()
	await _walk([player.global_position, bus.doorway_point(), out], 2.4)
	player.scripted = false
	player.teleport(Vector3(out.x, 0.1, out.z), 0.0)
	var outward := out - bus.doorway_point()
	player.look_toward(Vector3(out.x + outward.x * 6.0, 1.5, out.z + outward.z * 6.0))  # facing away from the door
	player.level_gaze()
	world.player.pos = Vector2(out.x, out.z)
	world.transit.disembark()
	if world.player.care == "":
		player.controls_enabled = true
	riding_the_bus = false
	await _wait(1.2)
	bus.close_door()


## The jam clears: every stuck car drives off down its lane, the front ones first.
func clear_jam() -> void:
	if _jam_cleared:
		return
	_jam_cleared = true
	var cars := get_tree().get_nodes_in_group("stuck_cars")
	if fast or cars.is_empty():
		for c in cars:
			c.queue_free()
		return
	var fwd: Vector2 = scenario.jam.fwd
	cars.sort_custom(func(a, b): return _lead(a, fwd) > _lead(b, fwd))  # the front of the queue goes first
	var delay := 0.0
	for c in cars:
		var heading := Vector3(sin(c.rotation.y), 0.0, cos(c.rotation.y))  # a car's front is its +Z, as the bus's is
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(c, "position", c.position + heading * 160.0, 9.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(c.queue_free)
		delay += 0.7


## How far a car is ahead in the way it is going, along the street: the bigger, the nearer the front of its queue.
func _lead(car: Node3D, fwd: Vector2) -> float:
	var heading := Vector2(sin(car.rotation.y), cos(car.rotation.y))
	return Vector2(car.position.x, car.position.z).dot(fwd) * (1.0 if heading.dot(fwd) >= 0.0 else -1.0)


func _process(_delta: float) -> void:
	if not _jam_cleared and world.quests.done("jam_cleared"):
		clear_jam()


## Where the bus is in the model, for the view and the seated hero (tests and tools step the world without frames).
func _follow_model() -> void:
	bus.place(world.bus.pos, BusView._yaw_of(world.bus.heading))
	player.update_seat()


## Walk the hero along `points` (world positions of their feet) in `seconds`, turning to look where they are going.
## They are moved by this and not by the keys while it lasts. (Fast: they are simply put at the end.)
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


## One frame of _walk: the hero a fraction `t` of the way along the path.
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


func _build_jam() -> void:
	if _jam_built:
		return
	_jam_built = true
	for c in scenario.jam.cars:
		game.add_child(BusView.car(c.pos, c.yaw, c.color))


func _wait(seconds: float) -> void:
	if fast:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout
