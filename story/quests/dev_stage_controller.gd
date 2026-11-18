## CONTROLLER (a developer's tool). Jumps the running game forward to a point in the story, to test what comes after it
## without playing what comes before. It does not fake the state: it sets up what the story would have, and then plays the
## real rides (the quest controller's `fast` mode), so the world is as the game would have left it. Forward only: to go back,
## load a chapter checkpoint (SaveStore.CHAPTERS) or start again.
## Reached from the pause menu (debug builds) and from the command line: `godot --path . -- --skip-intro --stage=gate`.
class_name DevStageController
extends Node

## id, label: in story order. Jumping to one plays every step up to it that has not happened yet.
const STAGES := [
	["offer", "Letter in hand, at the market"],
	["jam", "Bus ride done: Mr. Nobody's street"],
	["bus", "Farewell said: the bus is waiting"],
	["gate", "At the bank's gate (doorman)"],
	["inside", "Through the gate, at the shuttle"],
	["desk", "At the reception desk"],
	["lift", "Letter delivered, at the lift"],
	["room", "Upstairs, in the instrument room"],
]

var game: Node
var busy := false


func setup(g: Node) -> DevStageController:
	game = g
	name = "DevStageController"
	return self


static func known(id: String) -> bool:
	return STAGES.any(func(s): return s[0] == id)


## Plays the story forward to `id`. Returns false if it could not (busy, not free to move, or unknown).
func go(id: String) -> bool:
	var target := -1
	for i in STAGES.size():
		if STAGES[i][0] == id:
			target = i
	var w: World = game.world
	var qc: QuestController = game.quest_controller
	if target < 0 or busy or not game.player.controls_enabled or not w.hero.is_on_foot() or qc.riding_the_bus:
		return false
	busy = true
	var was_fast := qc.fast
	qc.fast = true
	for i in target + 1:
		await _step(STAGES[i][0])
		_refill()
	qc.fast = was_fast
	busy = false
	game.hud.notify("Dev: %s" % STAGES[target][1])
	return true


func _step(id: String) -> void:
	var w: World = game.world
	var q := w.quests
	var qc: QuestController = game.quest_controller
	var sc: Scenario = game.scenario
	match id:
		"offer":
			if q.state.get(QuestBook.LETTER, "") in ["", "offered"]:
				for m in w.machines:
					m.working = true
				q.state[QuestBook.LETTER] = "active"
				var bs := q.bankers()
				q.giver = bs[0] if not bs.is_empty() else null
				if w.player.carry.count("letter") == 0:
					w.player.carry.add("letter", 1)
				w.events.append("Dev: the letter is yours.")
			if not q.done("rode_bus"):
				_put(sc.bus_stop.pos + Vector2(0.0, 4.0))
		"jam":
			if not q.done("rode_bus"):
				_put(sc.bus_stop.pos + Vector2(0.0, 4.0))
				game.advance(0.2)
				await qc.ride()
		"bus":
			if not q.done("jam_cleared"):
				w.sage.tell(Stories.FIRST)
				q.farewell_to_sage()
				for i in 3:
					await get_tree().process_frame
				var k: Vector3 = game.bus.kerb_point()
				_put(Vector2(k.x, k.z))
		"gate":
			if not q.done("rode_on"):
				var k: Vector3 = game.bus.kerb_point()
				_put(Vector2(k.x, k.z))
				game.advance(0.2)
				await qc.ride_on()
		"inside":
			if not q.done("cleared_gate"):
				q.clear_gate()
			if not q.done("rode_shuttle"):
				var k: Vector3 = game.shuttle.kerb_point()
				_put(Vector2(k.x, k.z))
		"desk":
			if not q.done("rode_shuttle"):
				game.advance(0.2)
				await qc.ride_shuttle()
		"lift":
			if q.state.get(QuestBook.LETTER, "") != "done":
				q.deliver()
			if w.cast.lift != null:
				_put(w.cast.lift.exit_point())
		"room":
			if w.cast.lift != null and w.player.zone != Scenario.LIFT_ZONE:
				var out := w.cast.lift.twin.exit_point()
				w.portals.cross(w.player, w.cast.lift)
				_put(out)
				game.player.level_gaze()
				game.advance(0.2)


## Puts the hero on the ground at `at`.
func _put(at: Vector2) -> void:
	game.player.teleport(Vector3(at.x, 0.1, at.y), game.player.rotation.y)
	game.world.player.pos = at


## (The rides take sim minutes in no time: the hero is not looking after themselves.)
func _refill() -> void:
	for need in Drone.NEEDS:
		game.world.player.bars[need] = 1.0
