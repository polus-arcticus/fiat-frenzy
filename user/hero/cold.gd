## How hard the cold is on the hero. The street's people are hardened to it (Needs.DAY_COOLING, a full warmth bar lasts half an
## hour by day); the hero is new out here, and without clothes gets only so far from a fire. That is said in blocks, walking:
## from a full bar to nothing, about DAY_BLOCKS by day and NIGHT_BLOCKS at night. Clothes stretch it (Drone.insulation: an old
## coat, 0.3, goes 1.4 times as far; a coat, 0.6, 2.5 times). Fires, tents and warm rooms warm the hero as much faster as the
## cold bites harder, so a fire still fills the bar in moments (see Needs.decay).
class_name Cold
extends RefCounted

const BLOCK := 110.0        # metres: a block of the Bahnhofsviertel (Moselstraße to Elbestraße along Kaiserstraße, 112 m)
const WALK := 4.5           # metres a second: the hero's walk (PlayerController.walk_speed)
const DAY_BLOCKS := 2.0
const NIGHT_BLOCKS := 0.75


## Seconds a full bar lasts in the open, without clothes: x by day, y at night (Drone.cold_spans).
static func spans() -> Vector2:
	return Vector2(DAY_BLOCKS, NIGHT_BLOCKS) * BLOCK / WALK
