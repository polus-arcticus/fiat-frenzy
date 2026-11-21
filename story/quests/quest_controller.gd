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
var shuttle: ShuttleView  # the golf cart at the bank's gate (null if the map has no gate)
var fade: FadeScreen
## Skip the waiting in the fades and captions (tests and tools).
var fast := false
var riding_the_bus := false

const BOARD_REACH := 6.0

var _jam_built := false
var _jam_cleared := false
var _delivering := false  # the dialogue being read is the receptionist's (the letter goes over), not the banker's...
var _servicing := false  # ...or the technician upstairs
var _gating := false      # ...or the doorman's at the gate (he opens it)


func setup(w: World, p: PlayerController, h: Hud, d: DialogueScreen, g: Node, sc: Scenario, b: BusView, f: FadeScreen, s: ShuttleView = null) -> QuestController:
	world = w
	player = p
	hud = h
	dialogue = d
	game = g
	scenario = sc
	bus = b
	shuttle = s
	fade = f
	name = "QuestController"
	return self


## Q at any banker (they all have the letter in mind), at the doorman at the gate, or at the receptionist to hand it over.
func talk(who: Drone) -> void:
	if who == world.cast.doorman:
		_talk_gate()
		return
	if who == world.cast.receptionist:
		_talk_reception()
		return
	if who == world.cast.technician:
		_talk_technician()
		return
	if not world.quests.is_banker(who) or dialogue.visible or not player.controls_enabled:
		return
	var state: String = world.quests.state.get(QuestBook.LETTER, "")
	if state == "offered":
		dialogue.handler = self
		game.sim.hold("quest")
		hud.show_prompt("")
		player.look_toward(Vector3(who.pos.x, 1.55, who.pos.y))
		dialogue.read(_speaker(who), QuestBook.quest(QuestBook.LETTER).offer)
	elif state == "active":
		world.chatter.say_line(who, QuestBook.quest(QuestBook.LETTER).reminder)


## The doorman at the gate: with the letter, he reads it and lifts the barrier and sends the hero to the shuttle; after that he
## reminds them where it is; before, he asks what business they have.
func _talk_gate() -> void:
	var d := world.cast.doorman
	if dialogue.visible or not player.controls_enabled:
		return
	if world.quests.can_clear_gate():
		_gating = true
		_start_reading(d, QuestBook.quest(QuestBook.LETTER).gate)
	elif world.quests.done("cleared_gate"):
		world.chatter.say_line(d, QuestBook.quest(QuestBook.LETTER).gate_reminder)
	else:
		world.chatter.say_line(d, QuestBook.quest(QuestBook.LETTER).gate_asked)


## The receptionist at the bank's door takes the letter.
func _talk_reception() -> void:
	if dialogue.visible or not player.controls_enabled:
		return
	if not world.quests.can_deliver():
		if world.quests.state.get(QuestBook.UPGRADE, "") == "active" and not world.quests.done("rode_lift"):
			world.chatter.say_line(world.cast.receptionist, QuestBook.quest(QuestBook.UPGRADE).lift_reminder)
		return
	_delivering = true
	_start_reading(world.cast.receptionist, QuestBook.quest(QuestBook.LETTER).delivery)


## The technician upstairs: the first time, his piece (and the quest is done); after that, a line about the bench.
func _talk_technician() -> void:
	var d := world.cast.technician
	if dialogue.visible or not player.controls_enabled:
		return
	if not world.quests.done("met_technician"):
		_servicing = true
		_start_reading(d, QuestBook.quest(QuestBook.UPGRADE).technician)
	else:
		world.chatter.say_line(d, QuestBook.quest(QuestBook.UPGRADE).technician_again)


func _start_reading(d: Drone, lines: Array) -> void:
	dialogue.handler = self
	game.sim.hold("quest")
	hud.show_prompt("")
	player.look_toward(Vector3(d.pos.x, 1.55, d.pos.y))
	dialogue.read(_speaker(d), lines)


## Who is talking, for the dialogue's heading: their name and what they do.
func _speaker(d: Drone) -> String:
	var job := world.profession_of(d)
	return d.label if job == "" else "%s  ·  %s" % [d.label, job]


## The request has been read through: the quest is accepted, or the gate opens, or the letter goes over.
func dialogue_finished() -> void:
	if _servicing:
		world.quests.meet_technician()
	elif _delivering:
		world.quests.deliver()
	elif _gating:
		world.quests.clear_gate()
	else:
		world.quests.accept(QuestBook.LETTER)
	dialogue.close()


func dialogue_closed() -> void:
	_delivering = false
	_servicing = false
	_gating = false
	game.sim.hold("quest", false)


## Can the hero get on something now?
func can_board() -> bool:
	return boardable() != ""


## What the hero could get on now, "bus" or "shuttle", or "". Not while out cold or on the bike, and only on the letter quest.
## The bus: first at its stop, before the first ride; later where it stands in the cleared street, once Mr. Nobody has said
## farewell. The shuttle: inside the bank's gate, once the doorman has opened it.
func boardable() -> String:
	if world.quests.active() != QuestBook.LETTER or riding_the_bus:
		return ""
	if not world.hero.is_on_foot() or world.player.unconscious() or not player.controls_enabled:
		return ""
	if world.bus != null:
		if not world.quests.done("rode_bus"):
			if world.bus.state == Bus.State.AT_STOP and player.ground_pos().distance_to(world.bus_stop) <= BOARD_REACH:
				return "bus"
		elif world.quests.done("jam_cleared") and not world.quests.done("rode_on") and world.bus.state == Bus.State.ARRIVED:
			if player.global_position.distance_to(bus.kerb_point()) <= BOARD_REACH:
				return "bus"
	if shuttle != null and world.shuttle != null and world.quests.done("cleared_gate") and not world.quests.done("rode_shuttle"):
		if world.shuttle.state == Bus.State.AT_STOP and player.global_position.distance_to(shuttle.kerb_point()) <= BOARD_REACH:
			return "shuttle"
	return ""


## What the interaction prompt says about getting on.
func board_prompt() -> String:
	match boardable():
		"bus":
			return "E   board the bus"
		"shuttle":
			return "E   hop on the shuttle"
	return ""


func board() -> void:
	match boardable():
		"bus":
			if not world.quests.done("rode_bus"):
				ride()
			else:
				ride_on()
		"shuttle":
			ride_shuttle()


## The shuttle: from inside the gate, round the market hall and along the plaza to the bank's door. It is a golf cart and it
## drives itself; the route is laid out by hand (see SecurityGate).
func ride_shuttle() -> void:
	if scenario.ecb_gate.is_empty() or shuttle == null:
		return
	var gate: Dictionary = scenario.ecb_gate
	var via: Array = []
	for p in gate.route:
		via.append(p)
	await _ride({
		"dest": gate.entrance, "via": via, "flag": "rode_shuttle", "direct": true, "walk": 1.8, "walk_off": 1.6,
		"board": "The shuttle sets off on its own. \"Please keep your hands inside the vehicle. The Bank is that way.\"",
		"arrive": "The main entrance. A very large glass door, and a very small receptionist behind it.",
	}, shuttle, world.shuttle)


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


## One ride, by default on the bus. The door opens, the hero walks in and sits down, the vehicle drives itself along its way
## (the town carries on all the while: nothing is paused), and where it stops the door opens again and the hero steps out onto
## the kerb on its right-hand side. `vehicle` and `model` say which vehicle (the bus, or the shuttle); `leg.direct` is a route
## laid out by hand (the shuttle's), not the streets.
func _ride(leg: Dictionary, vehicle: VehicleView = null, model: Bus = null) -> void:
	if vehicle == null:
		vehicle = bus
		model = world.bus
	if model == null:
		return
	riding_the_bus = true
	player.controls_enabled = false
	hud.show_prompt("")
	vehicle.open_door()
	await _wait(0.9)
	await _walk([player.global_position, vehicle.kerb_point(), vehicle.doorway_point(), vehicle.seat_point()], leg.get("walk", 3.4))
	player.scripted = false
	player.teleport(vehicle.seat_point(), vehicle.rotation.y + PI)  # facing the front
	player.level_gaze()
	player.sit(vehicle, vehicle.seat_local())
	world.hero.enter(Hero.Mode.SEATED)
	vehicle.close_door()
	hud.show_caption(leg.board, 0.0 if fast else 3.0)
	await _wait(0.8)
	world.transit.board(leg.dest, leg.flag, leg.via, model, leg.get("direct", false))
	while model.state == Bus.State.DRIVING:
		if fast:  # tests and tools: no frames to wait for, so run the world here
			_follow_model(vehicle, model)
			game.advance(1.0)
		await get_tree().process_frame
	_follow_model(vehicle, model)
	await _wait(0.6)
	vehicle.open_door()
	if world.player.care != "":
		# They passed out on the way. Nobody gets up: the ambulance will come to the vehicle, and the medical tent's
		# controller (not this) gives them their body and controls back when they wake.
		riding_the_bus = false
		return
	hud.show_caption(leg.arrive, 0.0 if fast else 3.5)
	await _wait(0.9)
	world.hero.stand()
	player.stand()
	var gathered := world.commerce.scoop_aboard()  # whatever is lying on the floor of the bus goes with them
	if gathered > 0.0:
		hud.notify("picked up $%d from the floor of the bus" % roundi(gathered))
	player.scripted = true
	var out := vehicle.kerb_point()
	await _walk([player.global_position, vehicle.doorway_point(), out], leg.get("walk_off", 2.4))
	player.scripted = false
	player.teleport(Vector3(out.x, 0.1, out.z), 0.0)
	var outward := out - vehicle.doorway_point()
	player.look_toward(Vector3(out.x + outward.x * 6.0, 1.5, out.z + outward.z * 6.0))  # facing away from the door
	player.level_gaze()
	world.player.pos = Vector2(out.x, out.z)
	world.transit.disembark(model)
	if world.player.care == "":
		player.controls_enabled = true
	riding_the_bus = false
	await _wait(1.2)
	vehicle.close_door()


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
func _follow_model(vehicle: VehicleView = null, model: Bus = null) -> void:
	if vehicle == null:
		vehicle = bus
		model = world.bus
	vehicle.place(model.pos, VehicleView._yaw_of(model.heading))
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


## What a save needs of this controller (the quests themselves are in the model): whether the traffic jam has been laid out
## and whether it has driven off.
func save_state() -> Dictionary:
	return {"jam_built": _jam_built, "jam_cleared": _jam_cleared}


## Puts the scene back as a save left it: the stuck cars are there if the jam was built and has not cleared.
func load_state(state: Dictionary) -> void:
	_jam_cleared = state.get("jam_cleared", false)
	if state.get("jam_built", false) and not _jam_cleared:
		_build_jam()
	_jam_built = state.get("jam_built", false)


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
