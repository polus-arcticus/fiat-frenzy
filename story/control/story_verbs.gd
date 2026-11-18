## CONTROLLER. What the hero can say to the story's people (Q): Mr. Nobody, a banker with the letter, the bank's doorman, its
## receptionist, the technician upstairs. Each is a verb added to the hero's InteractionController (its prompt is empty when it
## does not apply), and saying it asks the game to start that conversation (`talk_requested`).
class_name StoryVerbs
extends RefCounted

var world: World
var ic: InteractionController


## Adds the story's talks to `interaction`.
func setup(w: World, interaction: InteractionController) -> StoryVerbs:
	world = w
	ic = interaction
	ic.add_verb("chat",
		func() -> String: return "Q   talk to Mr. Nobody" if aimed_sage() else "",
		func(): ic.talk_requested.emit(world.cast.sage))
	ic.add_verb("chat",
		func() -> String: return "Q   talk to the banker" if aimed_banker() != null else "",
		func(): ic.talk_requested.emit(aimed_banker()))
	ic.add_verb("chat",
		func() -> String: return "Q   show the doorman the letter" if aimed_doorman() != null and world.quests.can_clear_gate() else ("Q   talk to the doorman" if aimed_doorman() != null else ""),
		func(): ic.talk_requested.emit(world.cast.doorman))
	ic.add_verb("chat",
		func() -> String:
			if aimed_receptionist() == null:
				return ""
			return "Q   give the letter to the receptionist" if world.quests.can_deliver() else "Q   talk to the receptionist",
		func(): ic.talk_requested.emit(world.cast.receptionist))
	ic.add_verb("chat",
		func() -> String: return "Q   talk to the technician" if aimed_technician() != null else "",
		func(): ic.talk_requested.emit(world.cast.technician))
	return self


func _near(d: Drone) -> bool:
	return ic.player.ground_pos().distance_to(d.pos) <= Sage.TALK_RANGE


## Is the crosshair on Mr. Nobody, and is the hero near enough to talk to him?
func aimed_sage() -> bool:
	return world.cast.sage != null and world.sage.met and world.sage.in_talking_range() and ic.aim.person() == world.cast.sage


## The doorman at the bank's gate, if the crosshair is on him, close by. (Always: he checks the letter, reminds you where the
## shuttle is, or asks your business, whichever fits.)
func aimed_doorman() -> Drone:
	var d := world.cast.doorman
	if d == null or not _near(d):
		return null
	return d if ic.aim.person() == d else null


## The receptionist at the bank's door, if the hero is through the gate with the letter, and the crosshair is on them, close by.
func aimed_receptionist() -> Drone:
	var d := world.cast.receptionist
	var asked: bool = world.quests.state.get(QuestBook.UPGRADE, "") == "active" and not world.quests.done("rode_lift")
	if d == null or not (world.quests.can_deliver() or asked) or not _near(d):
		return null
	return d if ic.aim.person() == d else null


## The technician upstairs, if the crosshair is on him and the hero is close.
func aimed_technician() -> Drone:
	var d := world.cast.technician
	if d == null or not _near(d):
		return null
	return d if ic.aim.person() == d else null


## A banker, if the crosshair is on one who is close and has something to say (any of them will do).
func aimed_banker() -> Drone:
	if not world.quests.state.get(QuestBook.LETTER, "") in ["offered", "active"]:
		return null
	var who := ic.aim.person()
	if not world.quests.is_banker(who) or not _near(who):
		return null
	return who
