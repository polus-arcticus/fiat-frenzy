## CONTROLLER. Meeting Mr. Nobody and talking to him again. The model (Sage) decides when he notices the hero,
## walks over and arrives, and what he will tell at the hero's level; this opens the dialogue screen when he
## arrives (or when the hero presses E at him), turns the camera to him, takes the controls and stops the clock
## while they talk, and gives everything back when the screen closes, however it is closed.
class_name SageController
extends Node

var world: World
var player: PlayerController
var hud: Hud
var dialogue: DialogueScreen
var game: Node  # has `sim` (a SimLoop)



func setup(w: World, p: PlayerController, h: Hud, d: DialogueScreen, g: Node) -> SageController:
	world = w
	player = p
	hud = h
	dialogue = d
	game = g
	name = "SageController"
	return self


func _process(_delta: float) -> void:
	if world.sage.arrived and not dialogue.visible:
		_begin()


## The hero pressed E at him (the interaction controller says when).
func talk() -> void:
	if world.sage.in_talking_range() and not dialogue.visible and player.controls_enabled:
		_begin()


func _begin() -> void:
	world.sage.begin_talking()
	dialogue.handler = self
	game.sim.hold("sage")
	hud.show_prompt("")
	var at := world.sage_drone.pos
	player.look_toward(Vector3(at.x, 1.55, at.y))
	if world.sage.met:
		_show_menu()
	else:
		dialogue.read(_who(), world.sage.tell(Stories.FIRST))


## What to call him: "Stranger" until he has said who he is.
func _who() -> String:
	return world.sage_drone.label


## The first meeting is over: on to the list of stories.
func dialogue_finished() -> void:
	_show_menu()


func _show_menu() -> void:
	if not world.sage.name_known:
		world.sage.learn_name()  # the first meeting is over: now we know his name
	var intro := "What shall it be, my dear?" if world.sage.told.size() > 1 else "Now. Ask, and I shall answer with something nearby."
	dialogue.menu(_who(), intro, world.sage.topics_for(world.player.growth.level))


func dialogue_chosen(id: String) -> void:
	if id == DialogueScreen.FAREWELL:
		dialogue.close()
		return
	var pages := world.sage.tell(id)
	if pages.is_empty():
		_show_menu()
	else:
		dialogue.read(_who(), pages)


func dialogue_closed() -> void:
	world.sage.end_talking()
	game.sim.hold("sage", false)
