## A source of warmth, and somewhere to be near it: a few spots, and how hard it warms. Tents and barrel
## fires both have one.
##
## Warmth falls off with distance by a softened inverse-square law: at distance d it gives
##   warm_rate * R0^2 / (R0^2 + d^2)
## so it is strongest beside the fire, a quarter as strong at twice R0, and negligible a few metres off.
## It costs one division on the squared distance (no square root), and the R0 term keeps the value
## finite when someone stands right on top of it.
##
## A fire is open-air: anyone near it feels it, sheltered or not. A tent warms only the people who have
## bought a bed and taken a berth in it.
class_name Shelter
extends RefCounted

const R0_SQ := 2.25  # the distance (1.5 m, squared) at which a source gives half its full strength
const RANGE := 10.0  # beyond this, nothing

var capacity := 4
var warm_rate := 0.02  # warmth a second at the very centre
var centre := Vector2.ZERO
var open_air := false
var berth_radius := 0.9  # how far from the middle each place is (a tent is smaller inside than a fire's ring)
var berths: Array = []  # the drones in it


func _init(spots: int, rate: float, at := Vector2.ZERO, in_the_open := false) -> void:
	capacity = spots
	warm_rate = rate
	centre = at
	open_air = in_the_open


func has_room() -> bool:
	return berths.size() < capacity


func admit(d: Drone) -> void:
	berths.append(d)
	d.sheltered_in = self


func release(d: Drone) -> void:
	berths.erase(d)
	d.sheltered_in = null


## Warmth a second felt by someone at `centre.distance_squared_to(them) == d2`.
func gain_at_sq(d2: float) -> float:
	return warm_rate * R0_SQ / (R0_SQ + d2)


## Where the `index`th person sits round the source, so nobody sits on top of anybody.
func berth_pos(at: Vector2, index: int) -> Vector2:
	return at + Vector2.from_angle(TAU * float(index) / maxf(capacity, 1) + 0.4) * berth_radius
