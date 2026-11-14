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
const KERB_STALL := 4.6        # a stall's middle, this far from the centre line: at the kerb edge of the pavement
const TENT_DEPTH := 2.6        # a tent's middle, this far in from the building line
const HOSPITAL_CENTRE := 6.3   # the medical tent's middle: its open end a step back from the kerb, its back wall on the pavement
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
var skate_shop := {}  # and the skate shop's, in the building next door
var sage_house := {}  # the same, for Mr. Nobody's house
var ecb := {}          # and for the European Central Bank (no door is cut in it: the doorman stands outside)
## The bus: where it waits at the start ({pos, yaw}), and the traffic jam it ends up in outside Mr. Nobody's house
## ({bus: {pos, yaw}, cars: [{pos, yaw, color}], arrival, arrival_yaw}: where the hero gets off). Empty if there is no house.
var bus_stop := {}
var jam := {}
## Where the bus stops at the European Central Bank, and its doorman: {bus: pos, via: [points the bus drives through to
## line up with the street], doorman: pos, doorman_faces: pos}. The named street is a long way from the building's own
## wall in the data, so the gate is on the street. Empty if the street is not in the data.
var ecb_stop := {}
## The streets (also the world's road graph, see build()): the bus's way to the jam is worked out on them.
var roads: RoadGraph

var _frame: Dictionary


func _init(data: Dictionary) -> void:
	district = data
	_frame = MapSites.street_frame(district, STREET, NEAR)
	roads = RoadGraph.new()
	for r in district.roads:
		roads.add_polyline(MapSites.pts(r.pts))
	var street_dir: Vector2 = _frame.dir
	var lane := _spot(-16.0, 1.0, float(_frame.width) * 0.25)  # the bus waits in its own (right-hand) lane, at the kerb
	bus_stop = {"pos": lane.pos, "yaw": atan2(street_dir.x, street_dir.y), "dir": street_dir, "kerb_side": lane.away}
	bike_shop = MapSites.plan_door(district, BIKE_SHOP_BUILDING, STREET)
	sage_house = MapSites.plan_door(district, SAGE_BUILDING, SAGE_STREET)
	var next_door := MapSites.neighbour(district, bike_shop, STREET)
	skate_shop = MapSites.plan_door(district, next_door, STREET) if next_door >= 0 else {}
	jam = _plan_jam()
	ecb = MapSites.plan_door(district, ECB_BUILDING, ECB_STREET)
	ecb_stop = _plan_ecb_stop()


## The bus's last stop: on the named street nearest the European Central Bank, pulled up in its right-hand lane after
## lining up with the street, and the doorman on the pavement on the bank's side.
func _plan_ecb_stop() -> Dictionary:
	if ecb.is_empty() or jam.is_empty():
		return {}
	var street := MapSites.street_frame(district, ECB_STREET, ecb.door)
	if street.is_empty():
		return {}
	var from: Vector2 = jam.bus.pos
	var along: Vector2 = street.dir
	if along.dot((street.point as Vector2) - from) < 0.0:
		along = -along
	var right := Vector2(-along.y, along.x)
	var width: float = street.width
	var stop: Vector2 = (street.point as Vector2) + along * 8.0 + right * (width * 0.25)
	var via: Vector2 = (street.point as Vector2) - along * 30.0 + right * (width * 0.25)  # lined up, a little before it
	var bank_side := 1.0 if right.dot((ecb.door as Vector2) - (street.point as Vector2)) >= 0.0 else -1.0
	var gate: Vector2 = (street.point as Vector2) + along * 8.0 + right * bank_side * (width * 0.5 + 2.0)
	return {"bus": stop, "via": [via], "doorman": gate, "doorman_faces": gate - right * bank_side * 20.0}


## The jam outside Mr. Nobody's house, with the bus joining it the way it arrives: the direction of the last stretch of
## its journey along Battonnstraße.
func _plan_jam() -> Dictionary:
	if sage_house.is_empty():
		return {}
	var street := MapSites.street_frame(district, SAGE_STREET, sage_house.door)
	if street.is_empty():
		return {}
	var probe := roads.route(bus_stop.pos, street.point)
	var fwd: Vector2 = street.dir
	if probe.size() >= 2 and fwd.dot(probe[probe.size() - 1] - probe[probe.size() - 2]) < 0.0:
		fwd = -fwd
	return MapSites.plan_jam(district, sage_house, fwd)


## Which buildings get a door cut into them, for CityBuilder: {building id: {edge, t, width, height}}.
func openings() -> Dictionary:
	var out := {}
	for layout in [bike_shop, skate_shop, sage_house]:
		if not layout.is_empty():
			out[layout.id] = {"edge": layout.edge, "t": layout.t, "width": MapSites.DOOR_WIDTH, "height": MapSites.DOOR_HEIGHT}
	return out


func build() -> World:
	seed(1133)
	var w := World.new()
	w.roads = roads
	w.clock.time = 0.033 * Clock.DAY_SECONDS  # 6:47 in the morning, the time the intro names

	# The landing street, laid out across its width. From the centre line out to either building: the carriageway (the middle:
	# the bus's lane, and where people walk, for there is no traffic now), the kerb, the stalls (their backs to the road,
	# serving the pavement), the walkway down the middle of the pavement, and against the buildings the tents (open to the
	# walkway). Along the street, neighbours on one side need about 4.5 m between centres.
	var stall := KERB_STALL
	cast["hot_dog"] = _vendor(w, "hot_dog_stand", "Hot dog vendor", 0.0, 1.0, 8.0, stall, false)
	cast["bakery"] = _vendor(w, "bakery", "Baker", -1.0, -1.0, 6.0, stall, false)
	cast["lemonade"] = _vendor(w, "lemonade_stand", "Lemonade seller", 4.5, -1.0, 10.0, stall, false)
	cast["tent"] = _vendor(w, "tent", "Tent keeper", 7.0, 1.0, 4.0, -TENT_DEPTH, true)

	var fire_spot := _spot(3.5, 1.0, -2.0)  # by the tent, against the buildings: off the walkway
	var fire := w.add_fire(fire_spot.pos)
	facing[fire] = atan2(-(fire_spot.toward as Vector2).x, -(fire_spot.toward as Vector2).y)
	var van_spot := _spot(22.0, 1.0, 0.0)
	van = w.add_relief_truck(van_spot.pos)
	facing[van] = (_frame.dir as Vector2).angle() * -1.0 + PI / 2.0

	# The medical tent on the left-hand pavement, well down the street from the market, its open end toward the road and the
	# ambulance's bay on the carriageway in front of it.
	var clinic := _spot(26.0, -1.0, HOSPITAL_CENTRE)
	hospital = w.add_hospital(clinic.pos, clinic.toward)
	facing[hospital] = atan2(-(clinic.toward as Vector2).x, -(clinic.toward as Vector2).y)
	facing[w.ambulances[0]] = facing[van]

	for i in DRIFTER_COUNT:
		var d := w.add_drifter(_at(randf_range(-12.0, 12.0), randf_range(-1.0, 1.0)), randf_range(3.0, 12.0))
		d.label = DRIFTER_NAMES[i]

	# The food bank, 40 m down the street from the market on the left kerb like a stall, with two cart runners waiting on the
	# pavement beside it.
	var bank := _spot(-42.0, -1.0, KERB_STALL)
	var keeper := w.add_food_bank(bank.pos, 8.0)
	var fb := w.food_bank_of(keeper)
	facing[fb] = atan2(-(bank.away as Vector2).x, -(bank.away as Vector2).y)
	fb.front = bank.away
	keeper.pos = fb.post()
	cast["food_bank"] = keeper
	var runners: Array[Drone] = []
	for k in 2:
		var r := w.add_runner(_spot(-38.0 - 3.0 * k, -1.0, KERB_STALL + 2.2).pos, 15.0)
		r.label = ["Runner Jakob", "Runner Lena"][k]
		runners.append(r)
	cast["runners"] = runners
	_add_bike_shop(w)
	_add_sage(w)
	_add_doorman(w)
	_add_skate_shop(w)
	start = _at(-24.0, 0.0)  # far enough that "walk over to the hot dog vendor" is a real first step
	start_yaw = atan2(-(_frame.dir as Vector2).x, -(_frame.dir as Vector2).y)
	w.add_bus(bus_stop.pos, (_frame.dir as Vector2).angle())
	for layout in [bike_shop, skate_shop, sage_house]:  # the shops and the sage's house are warm inside
		if not layout.is_empty():
			w.heating.add_building(layout.poly)
	# Walkers keep out of the buildings (the shops with a door cut in them are hollow: people stand inside those)
	var hollow := openings()
	for bd in district.buildings:
		if not hollow.has(int(bd.id)):
			w.nav.add_static("district", MapSites.pts(bd.poly))
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


## The skate shop, next to the bike shop: its owner behind a counter, like the bike shop's. Added after everyone else, so no
## earlier drone changes its number.
func _add_skate_shop(w: World) -> void:
	if skate_shop.is_empty():
		return
	var inward: Vector2 = skate_shop.inward
	var counter: Vector2 = (skate_shop.door as Vector2) + inward * minf(skate_shop.depth * 0.55, 9.0)
	var owner := w.add_vendor("skate_shop", counter, 600.0, true, true)
	owner.label = "Skate shop owner"
	var m := w.machine_of(owner)
	m.front = -inward
	facing[m] = atan2(inward.x, inward.y)
	_toward[m] = m.front
	owner.pos = m.post()
	cast["skate_shop"] = owner


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
	var at: Vector2 = (ecb.door as Vector2) + out * 2.6
	var faces: Vector2 = at + out * 20.0
	if not ecb_stop.is_empty():  # at the gate on the street, where the bus stops
		at = ecb_stop.doorman
		faces = ecb_stop.doorman_faces
	var d := w.add_doorman(at)
	d.face_to = faces
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
	if not skate_shop.is_empty():
		marks.append({"pos": skate_shop.door, "label": "skate shop", "color": Color(0.9, 0.5, 0.2)})
	return marks


func _vendor(w: World, kind: String, label: String, along: float, side: float, wallet: float, lateral: float, faces_road: bool) -> Drone:
	var spot := _spot(along, side, lateral)
	var d := w.add_vendor(kind, spot.pos, wallet, false, false)
	d.label = label
	var m := w.machine_of(d)
	var toward: Vector2 = spot.toward if faces_road else spot.away
	facing[m] = atan2(-toward.x, -toward.y)
	_toward[m] = toward
	m.front = toward
	d.pos = m.post()
	return d


## A point on the street, laid out across it: `along` metres down it from the anchor, on `side` (+1 the right, -1 the left)
## and `lateral` metres out from the centre line (negative: that far in from the building line instead). Returns {pos,
## toward (a unit vector from there toward the middle of the street), away (the other way, toward the buildings)}. Measured
## from the real road where it stands, which bends a little: a straight line through the market does not follow it.
func _spot(along: float, side: float, lateral: float) -> Dictionary:
	var global: Vector2 = (_frame.point as Vector2) + (_frame.dir as Vector2) * along
	var here := MapSites.street_frame(district, STREET, global)
	var nrm := Vector2(-(here.dir as Vector2).y, (here.dir as Vector2).x)
	var out := lateral
	if lateral < 0.0:  # measured in from the building line
		var pave: Array = here.pave
		var reach: float = float(pave[1 if side > 0.0 else 0]) if pave.size() == 2 else float(here.width) * 0.5 + 3.0
		out = reach + lateral
	var toward := -nrm * side
	return {"pos": (here.point as Vector2) + nrm * side * out, "toward": toward, "away": -toward}


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


## The carriageway's width where the market is.
func street_width() -> float:
	return float(_frame.width)


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
