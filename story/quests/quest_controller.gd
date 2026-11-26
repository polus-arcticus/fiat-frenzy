## CONTROLLER. The player's side of quests: talking to the banker who has the letter (Q), and the story's rides. The
## rules are the model's (Quests); this opens the dialogue, takes and gives back the controls, and plays the rides: tram 11
## to Börneplatz, where it breaks down outside Mr. Nobody's house; on to the bank once it is mended; the golf cart inside
## the bank's gate.
class_name QuestController
extends Node

var world: World
var player: PlayerController
var hud: Hud
var dialogue: DialogueScreen
var game: Node  # has `sim` (a SimLoop)
var scenario: Scenario
var shuttle: ShuttleView  # the golf cart at the bank's gate (null if the map has no gate)
var fade: FadeScreen
var rides: RideController  # (the ride itself: the door, the walk, the seat)
## Skip the waiting in the fades and captions (tests and tools).
var fast := false:
	set(v):
		fast = v
		if rides != null:
			rides.fast = v
var riding: bool:
	get:
		return rides != null and rides.riding

const BOARD_REACH := 6.0
const SMOKE_AT := Vector3(0.0, 3.4, 0.0)  # where a broken tram smokes from: its roof, at the pantograph

var _smoke: Node3D = null
var _delivering := false  # the dialogue being read is the receptionist's (the letter goes over), not the banker's...
var _servicing := false  # ...or the technician upstairs
var _gating := false      # ...or the doorman's at the gate (he opens it)


func setup(w: World, p: PlayerController, h: Hud, d: DialogueScreen, g: Node, sc: Scenario, f: FadeScreen, s: ShuttleView = null, r: RideController = null) -> QuestController:
	world = w
	player = p
	hud = h
	dialogue = d
	game = g
	scenario = sc
	shuttle = s
	fade = f
	rides = r
	name = "QuestController"
	return self


## The story's tram and the bank's golf cart, in the model (Transit), and the tram as it is drawn (null before it is).
func _tram() -> Vehicle:
	return world.transit.vehicle(Scenario.TRAM_QUEST)


func tram_view() -> TramView:
	return get_tree().get_first_node_in_group(VehicleView.CABIN + "_" + Scenario.TRAM_QUEST) as TramView


func _cart() -> Vehicle:
	return world.transit.vehicle("shuttle")


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


## What the hero could get on now, "tram" or "shuttle", or "". Not while out cold or on the bike.
## The tram, on the letter quest: first at the station, then, once Mr. Nobody has said farewell, where it broke down. When it
## has been all the way to the bank it is anyone's again (Scenario.held; a LineRideController). The shuttle: inside the
## bank's gate, once the doorman has opened it, and from then on back and forth between the gate and the bank's door.
func boardable() -> String:
	if riding or not world.hero.is_on_foot() or world.player.unconscious() or not player.controls_enabled:
		return ""
	var q := world.quests
	var model := _tram()
	var view := tram_view()
	var wanted := q.active() == QuestBook.LETTER and (not q.done("rode_tram") or (q.done("repaired") and not q.done("rode_on")))
	if wanted and model != null and view != null and model.state != Vehicle.State.DRIVING:
		view.door_toward(player.global_position)
		if player.global_position.distance_to(view.kerb_point()) <= BOARD_REACH:
			return "tram"
	if shuttle != null and _cart() != null and q.done("cleared_gate") and _cart().state != Vehicle.State.DRIVING:
		if player.global_position.distance_to(shuttle.kerb_point()) <= BOARD_REACH:
			return "shuttle"
	return ""


## What the interaction prompt says about getting on.
func board_prompt() -> String:
	match boardable():
		"tram":
			return "E   board tram %s" % Scenario.TRAM
		"shuttle":
			return "E   hop on the shuttle"
	return ""


## Gets on what the prompt offers; returns when the ride is over.
func board() -> void:
	match boardable():
		"tram":
			if not world.quests.done("rode_tram"):
				await ride()
			else:
				await ride_on()
		"shuttle":
			if not world.quests.done("rode_shuttle"):
				await ride_shuttle()
			else:
				await shuttle_service()


## What is said on the shuttle's rides, by the stop it is going to (its name on the line: Scenario._add_shuttle_and_reception):
## [as it sets off, as it arrives].
const SAYS := {
	"the gate": ["The shuttle sets off on its own. \"Leaving so soon? The exit is this way.\"", "The gate. The doorman nods you through."],
	"the main entrance": ["The shuttle sets off on its own. \"Please keep your hands inside the vehicle. The Bank is that way.\"",
		"The main entrance. The receptionist looks up, and down again."],
}


## The shuttle after its first ride: between the gate and the bank's door, whichever it is not at.
func shuttle_service() -> void:
	var cart := _cart()
	if shuttle != null and cart != null and cart.line != null:
		var says: Array = SAYS.get(str(cart.line.stops[cart.next_stop()].name), ["", ""])
		await _ride(shuttle, cart, "", says[0], says[1], 1.8, 1.6)


## The shuttle's first ride: from inside the gate, round the market hall and along the plaza to the bank's door.
func ride_shuttle() -> void:
	if shuttle != null:
		await _ride(shuttle, _cart(), "rode_shuttle", SAYS["the main entrance"][0],
			"The main entrance. A very large glass door, and a very small receptionist behind it.", 1.8, 1.6)


## The first ride: from the station, past the Paulskirche, to Börneplatz, where the tram breaks down outside Mr. Nobody's house.
func ride() -> void:
	await _ride_to(Scenario.TRAM_BREAKS_AT, "rode_tram",
		"Line %s to Fechenheim. The European Central Bank is near the far end. Everyone aboard is a banker." % Scenario.TRAM,
		"The tram shudders and dies. The driver opens the doors: \"Technical fault. Everybody out. We are not going anywhere.\"")


## The second: the tram is mended, and goes on to the stop for the European Central Bank.
func ride_on() -> void:
	await _ride_to(Scenario.TRAM_BANK_AT, "rode_on", "The tram hums again. On to the European Central Bank. The bankers aboard are checking their watches.",
		"%s. The driver opens the doors: \"European Central Bank. Mind the step, and the interest rates.\"" % Scenario.TRAM_BANK_AT)


## The tram straight through to the stop called `stop`.
func _ride_to(stop: String, flag: String, board: String, arrive: String) -> void:
	var model := _tram()
	if model == null or model.line == null or model.line.stop_called(stop) < 0:
		return
	await _ride(tram_view(), model, flag, board, arrive, 3.4, 2.4, model.line.stop_called(stop))


## One of the story's rides, along `model`'s line to its stop `to` (its next unless given). RideController plays it: the door,
## the walk, the seat, the walk off. Arriving says `flag` (the quest's); `board` and `arrive` are the captions.
func _ride(view: VehicleView, model: Vehicle, flag: String, board: String, arrive: String, walk: float, walk_off: float, to := -1) -> void:
	if view == null or model == null or model.line == null:
		return
	var go := func() -> bool: return world.transit.ride(model, flag, to)
	await rides.ride(view, model, go, board, arrive, walk, walk_off)


## A broken tram smokes, from breaking down until it is mended.
func _process(_delta: float) -> void:
	var broken := world.quests.done("rode_tram") and not world.quests.done("repaired")
	if broken and _smoke == null and tram_view() != null:
		_smoke = Effects.smoke(tram_view(), SMOKE_AT)
	elif not broken and _smoke != null:
		_smoke.queue_free()
		_smoke = null


## Is the broken tram smoking (tests and tools)?
func smoking() -> bool:
	return _smoke != null
