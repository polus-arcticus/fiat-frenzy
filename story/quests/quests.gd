## Quests: a small questing system. A quest is offered once its conditions are met, accepted, and then walked
## through its objectives in order. The quests themselves are data (QuestBook); this holds who has what:
## `state` maps a quest id to "offered", "active" or "done", and `flags` are things that happened that a quest cares
## about (the bus ride). It watches the world and never changes it, except to hand over the letter on acceptance.
class_name Quests
extends RefCounted

## The room the bank's lift goes up to: a zone of its own, far off the map.
const LIFT_ZONE := "cast.lift"
const FED := 0.8     # a banker is "well fed" with hunger at least this high...
const HUNGRY := 0.5  # ...after having been hungry (below this): it counts the first time one has had a proper meal

var state := {}
var flags := {}
var giver: Drone = null  # the banker who has the letter
var fed := {}            # banker's uid -> true once they have been hungry and then eaten
var _was_hungry := {}

var _w: World


func _init(world: World) -> void:
	_w = world


## The bankers about: the ones from the helicopter.
func bankers() -> Array[Drone]:
	var out: Array[Drone] = []
	for d in _w.drones:
		if d.look == "banker":
			out.append(d)
	return out


## Is this one of the bankers (any of whom can give the letter)?
func is_banker(d: Drone) -> bool:
	return d != null and d.look == "banker"


func _nearest_banker() -> Drone:
	var best: Drone = giver
	var bd := INF
	for b in bankers():
		var dist := b.pos.distance_to(_w.player.pos) if _w.player != null else 0.0
		if dist < bd:
			bd = dist
			best = b
	return best


## How many bankers have had a meal since they were hungry.
func fed_count() -> int:
	return fed.size()


## Every stand in the bankers' town is running (the bike shop always is) and there are bankers, each of whom has been fed. (Having
## eaten once is enough: they get hungry again, and the town need not keep all of them full at the same moment.)
func letter_ready() -> bool:
	var bs := bankers()
	if bs.is_empty():
		return false
	for m in _w.zones.machines_in(bs[0].zone):  # (the stands of the bankers' own town: the far market at the bank is another zone)
		if not m.working:
			return false
	for b in bs:
		if not fed.has(b.uid):
			return false
	return true


func step(_dt := 0.0) -> void:
	for b in bankers():
		if b.bars.hunger < HUNGRY:
			_was_hungry[b.uid] = true
		elif b.bars.hunger >= FED and _was_hungry.has(b.uid) and not fed.has(b.uid):
			fed[b.uid] = true
			_w.events.append("%s has had a proper meal (%d of %d bankers fed)." % [b.label if b.label != "" else "A banker", fed.size(), bankers().size()])
	if state.get(QuestBook.UPGRADE, "") == "active" and _w.player != null and _w.player.zone == LIFT_ZONE:
		flags["rode_lift"] = true
	if not state.has(QuestBook.LETTER) and letter_ready():
		state[QuestBook.LETTER] = "offered"
		giver = bankers()[0]
		for b in bankers():
			b.profession = "Banker with a letter"  # any of them will do: they are all in the same boat
		_w.events.append("The bankers want a word with you: aim at any of them and press Q.")


## Accepts an offered quest. Returns false if it wasn't on offer.
func accept(id: String) -> bool:
	if state.get(id, "") != "offered":
		return false
	state[id] = "active"
	if id == QuestBook.LETTER:
		_w.player.carry.add("letter", 1)
	_w.events.append("Quest: %s" % QuestBook.quest(id).title)
	return true


## Can the doorman at the gate wave the hero through? On the letter quest, at the bank (the bus has been all the way), still
## carrying the letter and not yet through.
func can_clear_gate() -> bool:
	return active() == QuestBook.LETTER and done("rode_on") and not done("cleared_gate") and _w.player.carry.count("letter") > 0


## The doorman has looked at the letter and opens the gate. (The shuttle is for the way in.)
func clear_gate() -> bool:
	if not can_clear_gate():
		return false
	flags["cleared_gate"] = true
	_w.events.append("The doorman at the gate lifts the barrier.")
	return true


## Is the hero where the letter goes: on the quest, through the gate, still carrying it?
func can_deliver() -> bool:
	return active() == QuestBook.LETTER and done("cleared_gate") and _w.player.carry.count("letter") > 0 and not done("delivered")


## Hand the letter over: it leaves the bag, the objective is met and the quest is done.
func deliver() -> bool:
	if not can_deliver():
		return false
	_w.player.carry.take("letter", 1)
	flags["delivered"] = true
	state[QuestBook.LETTER] = "done"
	_w.events.append("Quest complete: %s" % QuestBook.quest(QuestBook.LETTER).title)
	if _w.cast.lift != null and _w.cast.technician != null:  # the bank has somewhere to send them next
		state[QuestBook.UPGRADE] = "active"
		_w.events.append("Quest: %s" % QuestBook.quest(QuestBook.UPGRADE).title)
	return true


## Has the hero got what the technician had to say? (The room's bench is for later.)
func meet_technician() -> void:
	flags["met_technician"] = true
	if state.get(QuestBook.UPGRADE, "") == "active":
		state[QuestBook.UPGRADE] = "done"
		_w.events.append("Quest complete: %s" % QuestBook.quest(QuestBook.UPGRADE).title)


## The hero has said farewell to Mr. Nobody. If they came in on the bus and are on the letter quest, the traffic jam
## clears, and the bus can go on. (Returns whether it did.)
func farewell_to_sage() -> bool:
	if active() != QuestBook.LETTER or not done("rode_bus") or not _w.sage.met or done("jam_cleared"):
		return false
	flags["jam_cleared"] = true
	_w.events.append("The traffic starts to move again, and the bus waits at the kerb.")
	return true


func set_flag(key: String) -> void:
	flags[key] = true


func done(key: String) -> bool:
	match key:
		"met_sage":
			return _w.sage.met
		_:
			return flags.get(key, false)


## The quest being followed, or "".
func active() -> String:
	for id in state:
		if state[id] == "active":
			return id
	return ""


## What to do now: {text, at: Vector2 or null}, or {} if there is nothing on. An offer waiting to be taken up is
## an objective too (go and talk to the banker).
func objective() -> Dictionary:
	for id in state:
		if state[id] == "offered" and giver != null:
			return {"text": "The bankers have a letter and want a word: aim at any of them and press Q.", "at": _nearest_banker().pos}
	var id := active()
	if id == "":
		return {}
	for o in QuestBook.quest(id).objectives:
		if not done(o.key):
			return {"text": o.text, "at": _place(o.at)}
	return {}


func _place(name: String) -> Variant:
	match name:
		"bus_stop":
			return _w.bus_stop if _w.bus_stop.is_finite() else null
		"sage":
			return _w.cast.sage.pos if _w.cast.sage != null else null
		"ecb":
			return _w.cast.doorman.pos if _w.cast.doorman != null else null
		"shuttle":
			return _w.shuttle.pos if _w.shuttle != null else null
		"reception":
			return _w.cast.receptionist.pos if _w.cast.receptionist != null else null
		"lift":
			return _w.cast.lift.pos if _w.cast.lift != null else null
		"technician":
			return _w.cast.technician.pos if _w.cast.technician != null else null
		"bus":
			return _w.bus.pos if _w.bus != null else null
	return null
