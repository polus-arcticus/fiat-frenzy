## The story's scripted cast (the animatronics): the people who do not live by the town's rules, held by role so the story can
## find them. Each has no needs, takes part in no errands, and stays where the scenario puts them. The world holds one (`World.cast`)
## but knows nothing of who is in it.
class_name Cast
extends RefCounted

var sage: Drone = null          # Mr. Nobody, on Battonnstraße
var doorman: Drone = null       # the ECB doorman, at the gate
var receptionist: Drone = null  # the ECB receptionist, at the door: the letter quest ends with them
var technician: Drone = null    # the instrument technician, in the room upstairs
var lift: Portal = null         # the lift in the bank's plaza, up to that room


## Mr. Nobody, standing at `at`: an unremarkable stranger. He never bends down for loose money, which is how you can tell he is
## strange.
func add_sage(w: World, at: Vector2) -> Drone:
	sage = _scripted(w, at, "sage", "sage", "Stranger")  # (a stranger until he introduces himself: Sage.learn_name)
	return sage


## The doorman at the European Central Bank's gate, in a hi-vis vest. He checks visitors in and guides them to the shuttle.
func add_doorman(w: World, at: Vector2) -> Drone:
	doorman = _scripted(w, at, "clerk", "guard", "ECB doorman")
	return doorman


## The receptionist at the bank's door, in a suit.
func add_receptionist(w: World, at: Vector2) -> Drone:
	receptionist = _scripted(w, at, "clerk", "clerk", "ECB receptionist")
	return receptionist


## The technician in the instrument room.
func add_technician(w: World, at: Vector2) -> Drone:
	technician = _scripted(w, at, "clerk", "clerk", "Instrument technician")
	return technician


func _scripted(w: World, at: Vector2, kind: String, look: String, label: String) -> Drone:
	var d := w.add_drifter(at, 0.0)
	d.kind = kind
	d.look = look
	d.label = label
	d.make_needless()
	d.aloof = true
	return d
