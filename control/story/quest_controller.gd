## CONTROLLER. The player's side of quests: talking to the banker who has the letter (Q), and the bus ride. The
## rules are the model's (Quests); this opens the dialogue, takes and gives back the controls, and plays the
## bus ride (fade out, the bus moves to the traffic jam on Battonnstraße, fade in, the hero steps out).
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


## Q at the banker with the letter, or at the doorman to hand it over.
func talk(who: Drone) -> void:
	if who == world.ecb_doorman:
		_talk_doorman()
		return
	if who != world.quests.giver or dialogue.visible or not player.controls_enabled:
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


## Can the hero board the bus now: on the quest, at the bus, on foot, and it is still at its stop.
func can_board() -> bool:
	if world.quests.active() != QuestBook.LETTER or world.quests.done("rode_bus") or riding_the_bus:
		return false
	if world.riding.riding() or world.player.unconscious() or not player.controls_enabled:
		return false
	return player.ground_pos().distance_to(world.bus_stop) <= BOARD_REACH


func board() -> void:
	if can_board():
		ride()


## The bus ride to the European Central Bank, which gets as far as the traffic jam outside Mr. Nobody's house.
func ride() -> void:
	if scenario.jam.is_empty():
		return
	riding_the_bus = true
	player.controls_enabled = false
	game.sim.hold("bus")
	hud.show_prompt("")
	hud.show_caption("The bus to the European Central Bank. Everyone aboard is a banker.", 0.0 if fast else 2.2)
	await fade.fade_to(1.0, 0.0 if fast else 0.9)
	await _wait(2.0)
	_build_jam()
	var arrival: Vector2 = scenario.jam.arrival
	var door: Vector2 = scenario.sage_house.door
	var to := door - arrival
	player.teleport(Vector3(arrival.x, 0.1, arrival.y), atan2(-to.x, -to.y))
	player.level_gaze()
	world.player.pos = arrival
	world.quests.set_flag("rode_bus")
	await fade.fade_to(0.0, 0.0 if fast else 0.9)
	hud.show_caption("Traffic. Of course. The driver opens the doors: \"Everybody out. We are not going anywhere.\"", 0.0 if fast else 3.5)
	game.sim.hold("bus", false)
	player.controls_enabled = true
	riding_the_bus = false


func _build_jam() -> void:
	var b: Dictionary = scenario.jam.bus
	bus.place(b.pos, b.yaw)
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
