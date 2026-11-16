## The European Central Bank's security gate, as data: where each piece stands, the way the shuttle drives from it to the
## bank's door, and whether the gate is open. Nothing here draws anything (see SecurityGateView).
##
## Everything is laid out in the gate's own frame: its origin is where the guard stands on the pavement (a little past the
## kerb, level with the bus stop), `u` runs along the street and `v` runs away from it, into the bank's grounds. `plan` turns
## the frame into the world, from where the bus stops. (The shuttle's route round the market hall is laid out by hand for this
## map: a test checks that it clears every building.)
class_name SecurityGate
extends RefCounted

# --- the pieces, in the gate's frame (u, v), in metres
const GUARD := Vector2(-2.3, 0.8)       # where the guard stands, in front of his booth
const BOOTH := Vector2(-2.3, 3.7)       # the booth's middle...
const BOOTH_SIZE := Vector2(2.4, 2.4)   # ...and its footprint
const DRIVE_U0 := 2.5                   # the vehicle way in runs from here...
const DRIVE_U1 := 9.5                   # ...to here, across the frontage
const BARRIER_V := 2.2                  # the boom barrier, across it, at this depth...
const GATE_V := 6.5                     # ...and the sliding gate further in
const TURNSTILE := Vector2(-6.5, 5.0)   # the pedestrian way in, beside the booth
const PAD := Vector2(6.0, 15.0)         # where the shuttle waits, inside
const BOLLARDS_V := 3.0
const BOLLARDS_U := [11.5, 13.7, 15.9, 18.1, 20.3, 22.5, -9.5, -11.7]
const BLOCKS := [  # big concrete blocks: {u0, u1, v, depth, height}
	{"u0": -27.0, "u1": -13.0, "v": 3.2, "depth": 1.6, "height": 1.1},
	{"u0": 12.0, "u1": 27.0, "v": 5.4, "depth": 1.6, "height": 0.9},
]
const FLAG_POLES := [[-24.0, 9.0], [-21.5, 9.0], [-19.0, 9.0], [-16.5, 9.0]]  # (u, v): the four flags

## The shuttle's way from the pad to the bank's door: east along the lawn north of the market hall, round the hall's east end, then
## west along the plaza between the hall and the tower, which is closed at its west end and open only to the east. World
## coordinates (for this map); the stop itself is laid out from the door.
const ROUTE := [Vector2(2480, -195), Vector2(2590, -170), Vector2(2592, -120), Vector2(2580, -88), Vector2(2540, -80), Vector2(2500, -80), Vector2(2470, -77)]
const ENTRANCE_BACK := 8.0     # the shuttle stops this far out from the door...
const RECEPTION_OUT := 2.6     # ...and the receptionist waits this far out from it


## The frame in the world: {origin, into (the way away from the street), along (u's direction), yaw}. `stop` is the bus's
## last stop (Scenario.ecb_stop).
static func plan(stop: Dictionary, ecb: Dictionary) -> Dictionary:
	if stop.is_empty() or ecb.is_empty():
		return {}
	var origin: Vector2 = stop.doorman
	var into: Vector2 = (origin - (stop.doorman_faces as Vector2)).normalized()  # (he faces the street: the gate is the other way)
	var along := Vector2(into.y, -into.x)  # (the view's local x: see world_of)
	var door: Vector2 = ecb.door
	var out: Vector2 = ecb.out
	var plan := {"origin": origin, "into": into, "along": along, "yaw": atan2(into.x, into.y)}
	plan["guard"] = world_of(plan, GUARD)
	plan["pad"] = world_of(plan, PAD)
	var route := PackedVector2Array()
	for p in ROUTE:
		route.append(p)
	plan["route"] = route
	plan["entrance"] = door + out * ENTRANCE_BACK
	plan["reception"] = door + out * RECEPTION_OUT
	plan["pad_heading"] = (route[0] - (plan.pad as Vector2)).angle()
	return plan


## A spot in the gate's frame, in the world.
static func world_of(plan: Dictionary, local: Vector2) -> Vector2:
	return (plan.origin as Vector2) + (plan.along as Vector2) * local.x + (plan.into as Vector2) * local.y


## Is the gate open? The guard opens it when he has looked at the letter.
static func is_open(w: World) -> bool:
	return w.quests.done("cleared_gate")
