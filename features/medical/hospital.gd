## The medical tent. A few beds where people who have collapsed are brought, and looked after for free:
## each patient's bars refill until they are well enough to be up and about. No money changes hands.
class_name Hospital
extends RefCounted

const BEDS := 4
const CARE_RATE := 0.012  # a second, on each survival bar: about a minute and a half from empty to fit
const WAKE_AT := 0.6      # a patient is discharged once their lowest bar is back to this

var zone := "district"
var pos := Vector2.ZERO
var front := Vector2(0, 1)  # unit vector from the tent out to the street
var patients: Array[Drone] = []
var admitted_total := 0
var _solid: Footprint = null


func _init(at: Vector2, toward_street := Vector2(0, 1)) -> void:
	pos = at
	front = toward_street


func solid() -> Footprint:
	if _solid == null:
		_solid = Footprint.of("hospital", pos, front)
	return _solid


func display_name() -> String:
	return "Medical tent"


## Where the ambulance parks: out in the street, to the market side of the entrance so it doesn't block it.
func bay() -> Vector2:
	return pos + front * 4.5 + Vector2(-front.y, front.x) * 7.5


func bed_pos(index: int) -> Vector2:
	var side := Vector2(-front.y, front.x)
	return pos + side * (-1.35 + 0.9 * float(index)) - front * 0.2


## Where a patient who is up again stands: just outside the tent, a step apart from the last.
func exit_pos(index: int) -> Vector2:
	var side := Vector2(-front.y, front.x)
	return pos + front * 2.4 + side * (-1.2 + 0.7 * float(index % 4))


func free_beds() -> int:
	return BEDS - patients.size()


func admit(d: Drone) -> void:
	patients.append(d)
	admitted_total += 1
	d.care = "patient"
	d.pos = bed_pos(patients.size() - 1)
	d.route = PackedVector2Array()


## Looks after everyone in a bed. Returns the ones now well enough to go.
func step(dt: float) -> Array[Drone]:
	var well: Array[Drone] = []
	for d in patients:
		for n in Drone.NEEDS:
			d.bars[n] = minf(1.0, d.bars[n] + CARE_RATE * d.care_rate * dt)
		if d.neediest() >= (d.wake_at if d.wake_at > 0.0 else WAKE_AT):
			well.append(d)
	for d in well:
		patients.erase(d)
		d.care = ""
		d.pos = exit_pos(admitted_total + well.find(d))
	return well
