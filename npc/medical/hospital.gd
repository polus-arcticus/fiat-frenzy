## Where people who have collapsed are looked after, for free: each patient's bars refill until they are well enough to be up
## and about. No money changes hands. The medical trade's premises (Catalog.TRADES): a first aid post (tier 0, one bed, run by a
## medic, who tends whoever is down in the zone themselves) or the medical tent (tier 1, BEDS beds and an ambulance).
class_name Hospital
extends Premises

const BEDS := 4
const CARE_RATE := 0.012  # a second, on each survival bar: about a minute and a half from empty to fit
const WAKE_AT := 0.6      # a patient is discharged once their lowest bar is back to this
const BEDS_OF := {"first_aid": 1, "medical_tent": BEDS}

var patients: Array[Drone] = []
var admitted_total := 0


func _init(at := Vector2.ZERO, toward_street := Vector2(0, 1), what := "medical_tent") -> void:
	kind = what
	trade = "medical"
	tier = Catalog.TRADES.medical.find(what)
	pos = at
	front = toward_street


func beds() -> int:
	return BEDS_OF.get(kind, BEDS)


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
	return beds() - patients.size()


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
