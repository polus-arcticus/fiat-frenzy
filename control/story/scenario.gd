## CONTROLLER. Sets up the starting world on top of the district data: the street graph, and a small
## cast on Kaiserstraße, close together so the four businesses are one little market, with the food bank
## and its cart runners a good walk down the street. Every stand starts wrecked and every vendor starts broke: the district is the
## garden of Eden, and nothing runs until the player funds it. It only builds the model; the game
## controller makes views for what it finds.
class_name Scenario
extends RefCounted

const STREET := "Kaiserstraße"
const NEAR := Vector2(30, 0)
const DRIFTER_NAMES := ["Edda", "Karl", "Mehmet", "Dragan", "Ines", "Tobi"]
## How many of them are about at the start, besides the four vendors. Few, so the economy can be tuned.
const DRIFTER_COUNT := 2

## The building the bike shop is in: a four-cornered block 15 m back from the street, just past the start.
const BIKE_SHOP_BUILDING := 174326357
## Mr. Nobody's house: a building on Battonnstraße, a little way along from the museum (which is left alone).
const SAGE_STREET := "Battonnstraße"
const SAGE_BUILDING := 249389854
const ECB_STREET := "Sonnemannstraße"
const ECB_BUILDING := 156432555  # the European Central Bank

var district: Dictionary
var cast := {}      # "hot_dog", "bakery", "lemonade", "tent", "food_bank": the keeper; "runners": the cart runners
var van: ReliefTruck
var hospital: Hospital
var facing := {}    # Machine/BarrelFire/ReliefTruck -> yaw that faces the street
var _toward := {}   # Machine -> unit vector from its kerb to the middle of the street (its customers' side)
var start := Vector2.ZERO  # where the player begins
var start_yaw := 0.0
var wreck_pos := Vector2.ZERO  # where the helicopter ends up, in the street beyond the market
var wreck_yaw := 0.0
var gun_rest := Vector2.ZERO   # where the money gun lands: just ahead of where the player begins

## Where the bike shop's door is, from the building's footprint: {id, edge, t, door, out, inward, along,
## depth, poly}. `edge` is which wall of the footprint (CityBuilder's order) and `t` how far along it the door's
## middle is; `out` points from the wall out to the street. Empty if the building isn't in the data.
var bike_shop := {}
var sage_house := {}  # the same, for Mr. Nobody's house
var ecb := {}          # and for the European Central Bank (no door is cut in it: the doorman stands outside)
## Whether the debug teleporter rings are built (run with --portals): a shortcut to Mr. Nobody's door.
var with_portals := false
## The bus: where it waits at the start ({pos, yaw}), and the traffic jam it ends up in outside Mr. Nobody's house
## ({bus: {pos, yaw}, cars: [{pos, yaw, color}], arrival, arrival_yaw}: where the hero gets off). Empty if there is no house.
var bus_stop := {}
var jam := {}

var _frame: Dictionary


func _init(data: Dictionary) -> void:
	district = data
	_frame = MapSites.street_frame(district, STREET, NEAR)
	bike_shop = MapSites.plan_door(district, BIKE_SHOP_BUILDING, STREET)
	sage_house = MapSites.plan_door(district, SAGE_BUILDING, SAGE_STREET)
	jam = MapSites.plan_jam(district, sage_house)
	ecb = MapSites.plan_door(district, ECB_BUILDING, ECB_STREET)


## Which buildings get a door cut into them, for CityBuilder: {building id: {edge, t, width, height}}.
func openings() -> Dictionary:
	var out := {}
	for layout in [bike_shop, sage_house]:
		if not layout.is_empty():
			out[layout.id] = {"edge": layout.edge, "t": layout.t, "width": MapSites.DOOR_WIDTH, "height": MapSites.DOOR_HEIGHT}
	return out


func build() -> World:
	seed(1133)
	var w := World.new()
	w.roads = RoadGraph.new()
	for r in district.roads:
		w.roads.add_polyline(MapSites.pts(r.pts))
	w.clock.time = 0.033 * Clock.DAY_SECONDS  # 6:47 in the morning, the time the intro names

	# Same-side neighbours need about 4.5 m between centres (a stall is 2.2 m wide, the tent and its
	# barrel about 4 m); the two sides of the street face each other.
	cast["hot_dog"] = _vendor(w, "hot_dog_stand", "Hot dog vendor", 0.0, 1.0, 8.0)
	cast["tent"] = _vendor(w, "tent", "Tent keeper", 7.0, 1.0, 4.0)
	cast["bakery"] = _vendor(w, "bakery", "Baker", -1.0, -1.0, 6.0)
	cast["lemonade"] = _vendor(w, "lemonade_stand", "Lemonade seller", 4.5, -1.0, 10.0)

	var fire := w.add_fire(_at(-7.0, 1.0))
	facing[fire] = _yaw_to_street(1.0)
	van = w.add_relief_truck(_at(22.0, 0.0))
	facing[van] = (_frame.dir as Vector2).angle() * -1.0 + PI / 2.0

	# The medical tent well down the street from the market, its ambulance parked out in the street in front.
	var to_street: Vector2 = -Vector2(-(_frame.dir as Vector2).y, (_frame.dir as Vector2).x) * -1.0
	hospital = w.add_hospital(_at(24.0, -1.0), to_street)
	facing[hospital] = _yaw_to_street(-1.0)
	facing[w.ambulances[0]] = facing[van]

	for i in DRIFTER_COUNT:
		var d := w.add_drifter(_at(randf_range(-12.0, 12.0), randf_range(-1.0, 1.0)), randf_range(3.0, 12.0))
		d.label = DRIFTER_NAMES[i]

	# The food bank, 40 m down the street from the market, with two cart runners waiting by it.
	var keeper := w.add_food_bank(_at(-42.0, -1.0), 8.0)
	var fb := w.food_bank_of(keeper)
	facing[fb] = _yaw_to_street(-1.0)
	var dir: Vector2 = _frame.dir
	fb.front = -Vector2(-dir.y, dir.x) * -1.0
	keeper.pos = fb.post()
	cast["food_bank"] = keeper
	var runners: Array[Drone] = []
	for k in 2:
		var r := w.add_runner(_at(-38.0 - 3.0 * k, 1.0), 15.0)
		r.label = ["Runner Jakob", "Runner Lena"][k]
		runners.append(r)
	cast["runners"] = runners
	_add_bike_shop(w)
	_add_sage(w)
	_add_doorman(w)
	if with_portals:
		_add_portals(w)
	start = _at(-24.0, 0.0)  # far enough that "walk over to the hot dog vendor" is a real first step
	start_yaw = atan2(-(_frame.dir as Vector2).x, -(_frame.dir as Vector2).y)
	var street_dir: Vector2 = _frame.dir
	bus_stop = {"pos": _at(-16.0, 1.0), "yaw": atan2(street_dir.x, street_dir.y)}
	w.bus_stop = bus_stop.pos
	wreck_pos = offset_on_street(_at(34.0, 0.0), 0.0, 0.0)
	wreck_yaw = start_yaw + 0.5
	gun_rest = start + (_frame.dir as Vector2) * 3.4
	return w


## The bike shop: its owner behind a counter inside the building, facing the door. Added last, so the
## drifters and the other vendors keep the drone numbers they always had.
func _add_bike_shop(w: World) -> void:
	if bike_shop.is_empty():
		return
	var inward: Vector2 = bike_shop.inward
	var counter: Vector2 = (bike_shop.door as Vector2) + inward * minf(bike_shop.depth * 0.55, 9.0)
	var owner := w.add_vendor("bike_shop", counter, 800.0, true, true)
	owner.label = "Bike shop owner"
	var m := w.machine_of(owner)
	m.front = -inward  # the customers are on the door side of the counter
	facing[m] = atan2(inward.x, inward.y)  # the yaw that faces `front`
	_toward[m] = m.front
	owner.pos = m.post()
	cast["bike_shop"] = owner


## Mr. Nobody, standing on the pavement outside his door, looking along the street. Added last of all.
func _add_sage(w: World) -> void:
	if sage_house.is_empty():
		return
	var out: Vector2 = sage_house.out
	var sage := w.add_sage((sage_house.door as Vector2) + out * 2.6)
	sage.face_to = sage.pos + out * 20.0
	cast["sage"] = sage
	# He waits for a guest in the middle of his room, on the line in from his door (so the way there is straight).
	w.sage.set_house(sage_house.poly, (sage_house.door as Vector2) + (sage_house.inward as Vector2) * minf(5.0, float(sage_house.depth) * 0.5))


## The European Central Bank's doorman, on the pavement outside the front wall. Added after Mr. Nobody.
func _add_doorman(w: World) -> void:
	if ecb.is_empty():
		return
	var out: Vector2 = ecb.out
	var d := w.add_doorman((ecb.door as Vector2) + out * 2.6)
	d.face_to = d.pos + out * 20.0
	cast["doorman"] = d


## The places the hero already knows of, for the map. (Mr. Nobody is not one of them.)
func landmarks(w: World) -> Array:
	var marks: Array = []
	marks.append({"pos": w.machine_of(cast.hot_dog).pos, "label": "market", "color": Color(0.9, 0.7, 0.25)})
	if not w.hospitals.is_empty():
		marks.append({"pos": w.hospitals[0].pos, "label": "medical tent", "color": Color(0.9, 0.25, 0.25)})
	if not w.food_banks.is_empty():
		marks.append({"pos": w.food_banks[0].pos, "label": "food bank", "color": Color(0.35, 0.7, 0.4)})
	marks.append({"pos": bus_stop.pos, "label": "bus stop", "color": Color(0.85, 0.75, 0.2)})
	if not bike_shop.is_empty():
		marks.append({"pos": bike_shop.door, "label": "bike shop", "color": Color(0.3, 0.5, 0.85)})
	return marks


## The teleporter: one ring at the kerb just behind where the hero begins, its twin a few steps from Mr. Nobody
## (so you arrive facing him). Nothing here moves any drone, so it can go in after everything else.
func _add_portals(w: World) -> void:
	if sage_house.is_empty():
		return
	var dir: Vector2 = _frame.dir
	var side_in := -Vector2(-dir.y, dir.x)  # from the +1 kerb toward the middle of the street
	var home := Portal.new(offset_on_street(_at(-30.0, 1.0), 0.0, -2.0), side_in, "To Mr. Nobody")
	var out: Vector2 = sage_house.out
	var along: Vector2 = sage_house.along
	var far := Portal.new((sage_house.door as Vector2) + out * 3.5 - along * 6.0, along, "Back to the market")
	w.portals.add_pair(home, far)


func _vendor(w: World, kind: String, label: String, along: float, side: float, wallet: float) -> Drone:
	var d := w.add_vendor(kind, _at(along, side), wallet, false, false)
	d.label = label
	var m := w.machine_of(d)
	facing[m] = _yaw_to_street(side)
	var dir: Vector2 = _frame.dir
	_toward[m] = -Vector2(-dir.y, dir.x) * side
	m.front = _toward[m]
	d.pos = m.post()
	return d


## A spot `dist` metres in front of a stand (on the customers' side, toward the middle of the street) and
## the yaw that faces the stand from there. Tests and the capture tool stand here instead of guessing
## which way the street runs.
func front_of(m: Machine, dist: float) -> Dictionary:
	var spot: Vector2 = m.pos + (_toward[m] as Vector2) * dist
	var to := m.pos - spot
	return {"pos": spot, "yaw": atan2(-to.x, -to.y)}


## `from` moved `along` metres down the street and `lateral` metres across it (positive is toward side +1).
func offset_on_street(from: Vector2, along: float, lateral: float) -> Vector2:
	var dir: Vector2 = _frame.dir
	return from + dir * along + Vector2(-dir.y, dir.x) * lateral


## The street's direction where the market is.
func street_dir() -> Vector2:
	return _frame.dir


## A point `along` metres down the street from the anchor, at the kerb on `side` (+1 or -1).
func _at(along: float, side: float) -> Vector2:
	var dir: Vector2 = _frame.dir
	var nrm := Vector2(-dir.y, dir.x)
	return (_frame.point as Vector2) + dir * along + nrm * side * (float(_frame.width) * 0.5 - 0.8)


func _yaw_to_street(side: float) -> float:
	var dir: Vector2 = _frame.dir
	var toward := -Vector2(-dir.y, dir.x) * side  # from the kerb to the middle of the street
	return atan2(-toward.x, -toward.y)
