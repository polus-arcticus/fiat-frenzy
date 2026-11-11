## CONTROLLER. What the hero can do to what they are looking at, as a short list of verbs. Each verb has a key (E uses a
## thing, Q talks), a prompt that is empty when the verb doesn't apply right now, and an action. Every frame the first
## verb that applies shows its prompt; pressing its key does it. Adding something to do (a door, a lever) is adding a verb.
##
## E at a stand opens the trading screen (Tab opens just your own bag). While a screen is open the town carries on;
## the screen stack has the controls and the mouse. Walk away from the stand, or press E again, to close it. This turns
## what the screen asks for into calls on the model (World.commerce) and hands the answer back to show.
class_name InteractionController
extends Node

## Q at someone who will talk to you (Mr. Nobody, or the banker with the letter), close enough.
signal talk_requested(who: Drone)
## E at the bus, when the game says the hero may board it.
signal board_requested
## Set by the game: can the hero board the bus right now?
var can_board := func() -> bool: return false

const CLOSE_AT := 7.0  # walk this far from the stand and the screen closes itself

## One thing the hero can do. `action` is the input action that does it ("interact" or "chat").
class Verb:
	var action: String
	var prompt: Callable  # () -> String: what to show, or "" if this doesn't apply now
	var act: Callable     # () -> void

	func _init(a: String, p: Callable, d: Callable) -> void:
		action = a
		prompt = p
		act = d


var world: World
var player: PlayerController
var hud: Hud
var screen: InventoryScreen
var aim: Aim

var _verbs: Array[Verb] = []
var _refresh_in := 0.0


func setup(w: World, p: PlayerController, h: Hud, s: InventoryScreen) -> InteractionController:
	world = w
	player = p
	hud = h
	screen = s
	aim = Aim.new(p, w)
	name = "Interaction"
	screen.buy_requested.connect(_on_buy)
	screen.consume_requested.connect(_on_consume)
	_build_verbs()
	return self


## The verbs, most specific first.
func _build_verbs() -> void:
	_verbs = [
		Verb.new("interact",
			func() -> String:
				var m := aim.machine()
				return "E   open the %s" % m.display_name().to_lower() if m != null else "",
			func(): open(aim.machine())),
		Verb.new("chat",
			func() -> String: return "Q   talk to Mr. Nobody" if aimed_sage() else "",
			func(): talk_requested.emit(world.sage_drone)),
		Verb.new("chat",
			func() -> String: return "Q   talk to the banker" if aimed_banker() != null else "",
			func(): talk_requested.emit(aimed_banker())),
		Verb.new("chat",
			func() -> String: return "Q   give the letter to the doorman" if aimed_doorman() != null else "",
			func(): talk_requested.emit(world.ecb_doorman)),
		Verb.new("interact",
			func() -> String:
				var pickup := aim.pickup()
				return pickup.prompt if pickup != null else "",
			func(): aim.pickup().take()),
		Verb.new("interact",
			func() -> String: return "E   board the bus" if can_board.call() else "",
			func(): board_requested.emit()),
	]


## The stand the crosshair is on, if it is close enough to use.
func aimed_machine() -> Machine:
	return aim.machine()


## Is the crosshair on Mr. Nobody, and is the hero near enough to talk to him?
func aimed_sage() -> bool:
	return world.sage_drone != null and world.sage.met and world.sage.in_talking_range() and aim.person() == world.sage_drone


## The ECB doorman, if the hero has a letter for him and the crosshair is on him, close by.
func aimed_doorman() -> Drone:
	var d := world.ecb_doorman
	if d == null or not world.quests.can_deliver() or player.ground_pos().distance_to(d.pos) > Sage.TALK_RANGE:
		return null
	return d if aim.person() == d else null


## A banker, if the crosshair is on one who is close and has something to say (any of them will do).
func aimed_banker() -> Drone:
	if not world.quests.state.get(QuestBook.LETTER, "") in ["offered", "active"]:
		return null
	var who := aim.person()
	if not world.quests.is_banker(who) or player.ground_pos().distance_to(who.pos) > Sage.TALK_RANGE:
		return null
	return who


func aimed_pickup() -> GunPickupView:
	return aim.pickup()


func open(m: Machine) -> void:
	screen.open(world, m)
	hud.show_prompt("")  # (the screen stack takes the controls and the mouse)


## Opens just your own inventory (Tab).
func open_player() -> void:
	open(null)


func _process(delta: float) -> void:
	if screen.visible:
		if screen.machine != null and player.ground_pos().distance_to(screen.machine.pos) > CLOSE_AT:
			screen.close()
			return
		_refresh_in -= delta
		if _refresh_in <= 0.0:
			_refresh_in = 0.25
			screen.refresh()
		return
	var shown := ""
	if player.controls_enabled:
		for v in _verbs:
			shown = v.prompt.call()
			if shown != "":
				break
	hud.show_prompt(shown)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("inventory"):
		if screen.visible:
			screen.close()
		elif player.controls_enabled:
			open_player()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("interact") and screen.visible:
		screen.close()
		get_viewport().set_input_as_handled()
	elif player.controls_enabled and not screen.visible:
		for action in ["interact", "chat"]:
			if e.is_action_pressed(action) and _do(action):
				get_viewport().set_input_as_handled()
				return


## Does the first verb for `action` that applies. Returns whether there was one.
func _do(action: String) -> bool:
	for v in _verbs:
		if v.action == action and v.prompt.call() != "":
			v.act.call()
			return true
	return false


func _on_buy(m: Machine, item: String) -> void:
	screen.refresh(world.commerce.buy(m, item).text)


func _on_consume(item: String) -> void:
	screen.refresh(world.commerce.consume(item).text)
