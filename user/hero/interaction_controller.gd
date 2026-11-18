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
## E at the bus or the shuttle, when the game says the hero may get on.
signal board_requested
## Set by the game: what the prompt says about getting on something right now ("E   board the bus"), or "" if nothing can be
## boarded.
var board_prompt := func() -> String: return ""

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
var tents: TentScreen  # E at a tent opens this instead of the trading screen (see Lodging)
var aim: Aim

var _verbs: Array[Verb] = []
var _refresh_in := 0.0


func setup(w: World, p: PlayerController, h: Hud, s: InventoryScreen, t: TentScreen = null) -> InteractionController:
	world = w
	player = p
	hud = h
	screen = s
	tents = t
	aim = Aim.new(p, w)
	name = "Interaction"
	screen.buy_requested.connect(_on_buy)
	screen.consume_requested.connect(_on_consume)
	if tents != null:
		tents.add_requested.connect(func(tent: Machine):
			var cost := world.lodging.add_bed(tent)
			world.gun.credit_hero(cost)  # (money the hero puts in is experience for them too)
			tents.refresh("A bed is added ($%.0f, printed by the gun). %s" % [cost, "Someone will come for it." if tent.working else "Nobody will come while the tent is wrecked."]))
		tents.remove_requested.connect(func(tent: Machine):
			var left = world.lodging.remove_bed(tent)
			tents.refresh("A free bed is taken away." if left == null else ("%s packs up and leaves town." % (left.label if left.label != "" else "A drifter") if left is Drone else "Nobody here can leave.")))
		tents.warm_requested.connect(func(tent: Machine): tents.refresh(world.commerce.warm_at(tent)))
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
		Verb.new("interact",
			func() -> String:
				var pickup := aim.pickup()
				return pickup.prompt if pickup != null else "",
			func(): aim.pickup().take()),
		Verb.new("interact",
			func() -> String: return board_prompt.call(),
			func(): board_requested.emit()),
	]


## The stand the crosshair is on, if it is close enough to use.
func aimed_machine() -> Machine:
	return aim.machine()


## Adds a verb after the ones there are (a feature's own: the story's talks are added this way, see StoryVerbs).
func add_verb(action: String, prompt: Callable, act: Callable) -> void:
	_verbs.append(Verb.new(action, prompt, act))


func aimed_pickup() -> GunPickupView:
	return aim.pickup()


func open(m: Machine) -> void:
	if m != null and m.shelter != null and tents != null:
		tents.open(world, m)
	else:
		screen.open(world, m)
	hud.show_prompt("")  # (the screen stack takes the controls and the mouse)


## Opens just your own inventory (Tab).
func open_player() -> void:
	open(null)


func _process(delta: float) -> void:
	if tents != null and tents.visible:
		if player.ground_pos().distance_to(tents.tent.pos) > CLOSE_AT + tents.tent.modules() * Machine.MODULE_WIDTH:
			tents.close()
			return
		_refresh_in -= delta
		if _refresh_in <= 0.0:
			_refresh_in = 0.5
			tents.refresh()
		return
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
		elif player.controls_enabled or player.is_seated():  # (the bag can be opened from a seat on the bus too: to eat and drink on the way)
			open_player()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("interact") and (screen.visible or (tents != null and tents.visible)):
		screen.close()
		if tents != null:
			tents.close()
		get_viewport().set_input_as_handled()
	elif player.controls_enabled and not screen.visible and not (tents != null and tents.visible):
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
