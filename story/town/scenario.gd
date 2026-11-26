## CONTROLLER. The story's landing: the starting world on top of the story's district. Its first market is an atom on the station
## forecourt (Atom), found as any is: a tent city and its keeper, its bins and a fire. The town comes as the hero puts up tents, its founders
## in their order (Lodging.FOUNDERS), every stand wrecked and every owner broke: nothing runs until the player funds it (the
## tutorial walks them through it). On top: the story's own (the medical tent and its ambulance, the bike and skate shops, Mr.
## Nobody, tram 11 to the bank, the bank's gate, golf cart, market and lift). It only builds the model; the game
## controller makes views for what it finds.
class_name Scenario
extends Landing  # (the story's landing: see Landing)

const STREET := "Kaiserstraße"

## The building the bike shop is in: a four-cornered block 15 m back from the street, just past the start.
const BIKE_SHOP_BUILDING := 174326357
## Mr. Nobody's house: a building on Battonnstraße, a little way along from the museum (which is left alone).
const SAGE_STREET := "Battonnstraße"
const SAGE_BUILDING := 249389854
## The story begins on the station forecourt (Emilie-und-Oskar-Schindler-Platz): the market's middle, and the way it runs, in
## front of the arched train halls, between them and the road. Distances along it (`_fore`) are from the middle that way.
const FORECOURT_NAME := "Emilie-und-Oskar-Schindler-Platz"
const FORECOURT := Vector2(-355.0, 101.0)
const FORECOURT_DIR := Vector2(0.8, 0.6)
const START_ALONG := -24.0
const WRECK_ALONG := 34.0
const WRECK_OFF := 4.0     # (toward the road)
const HOSPITAL_ALONG := -4.0
const HOSPITAL_OFF := 11.0  # (toward the road)
## Its paving, between the station's front and the road (x, y pairs).
const FORECOURT_PAVING := [-446, 100, -420, 62, -394, 52, -365, 62, -342, 77, -322, 95, -304, 113, -290, 133, -278, 156, -272, 180,
	-268, 205, -268, 235, -305, 245, -345, 180, -406, 84]
## The market's site (Atom.seed): the square taken as a street this wide, with its far edge this far across it, toward the station.
const SITE_WIDTH := 8.0
const SITE_LINE := 12.0
const ECB_STREET := "Sonnemannstraße"
const ECB_BUILDING := 156432555  # the European Central Bank
const ECB_ZONE := "ecb"          # the market at the bank is a zone of its own, so the first market's people do not trek 2 km to it
const ECB_REGION_MARGIN := 90.0  # the zone reaches this far round the stop, the gate, the market, the shuttle's way and the door
const LIFT_ZONE := Quests.LIFT_ZONE     # the room the bank's lift goes up to: a zone of its own, built far off the map
const LIFT_ROOM_CENTRE := Vector2(-3000.0, -3000.0)
const LIFT_ROOM_HALF := Vector2(8.0, 7.0)  # half its width (x) and depth (y)
## The bank's gate: where the guard stands, by the road across from the tram's stop, and the way into the grounds.
const ECB_GATE := Vector2(2598.0, -287.0)
const ECB_GATE_INTO := Vector2(0.26, 0.97)
## The bank's market (Atom.seed): on the open ground east of the gate, taken as a street along it, the stalls with their backs
## to the east.
const ECB_MARKET := Vector2(2668.0, -252.0)
const ECB_MARKET_DIR := Vector2(-0.5, 0.866)
const ECB_MARKET_NAME := "the bank's forecourt"
## The story's map: its buildings and streets (tools/story_district.gd, from tools/story_map.gd's extract), and its land, as
## Overpass gave it (tools/story_land.gd).
const DISTRICT := "res://data/bahnhofsviertel.json"
const LAND := "res://data/raw/story_land.json"
const LAND_KEY := "story"  # what its frame's dice are named (the trees)


## The story's district: its buildings and streets, and, when its land has been fetched, its water (solid), its green and trees,
## and its street furniture, brought into the district's metres the way a tile's are (TileSource.district).
static func load_district(path := DISTRICT, land := LAND) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for b in d.buildings:  # (colours are kept as HTML strings in the file: tools/story_district.gd)
		for o in [b] + b.get("parts", []):
			if o.has("colour"):
				o["colour"] = Color.from_string(str(o.colour), Color.WHITE)
	for r in d.get("routes", []):
		if str(r.ref) == TRAM:
			r["colour"] = TRAM_COLOUR  # (coloured along its track: RailBuilder)
	if not d.has("squares"):
		d["squares"] = []
	d.squares.append({"poly": FORECOURT_PAVING.duplicate(), "surface": "paving_stones"})  # (the map has no area for it)
	if FileAccess.file_exists(land):
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(land))
		var frame := MapFrame.of_district(d, LAND_KEY)
		d["water"] = OsmWater.of(raw, frame, d)
		d["green"] = OsmDressing.of(raw, frame, d)
		d["street"] = StreetThings.points_in(raw, frame)
		d["rail"] = OsmRail.of(raw, frame)  # (empty until the land is fetched again with railways in it: tools/story_land.gd)
	return d

## Who is who, by role: the story's own people ("bike_shop", "skate_shop", "sage", "doorman", "receptionist", "technician"), the
## market's tent keeper ("tent"), and whichever of its founders have come so far (FOUNDER_CAST: "depot", "medic", "runners" (a
## list), "lemonade", "bakery", "thrift", "camp", "hot_dog"), and the bank's market's ("ecb_" and the same). Looked up afresh each
## time: the market grows in play, a tent at a time (Atom, Lodging.FOUNDERS).
var cast: Dictionary:
	get:
		return _cast_now()
## The founders' roles (Lodging.FOUNDERS), by the name the story calls them.
const FOUNDER_CAST := {"bottle_depot": "depot", "first_aid": "medic", "runner": "runners", "lemonade_stand": "lemonade",
	"bakery": "bakery", "thrift_stall": "thrift", "scrap_camp": "camp", "hot_dog_stand": "hot_dog"}
var market: Machine     # the tent city of the first market (the atom on the station forecourt)
var ecb_market: Machine  # and of the market at the bank (null if there is none)
var hospital: Hospital   # the medical tent, the story's own (its ambulance brings the hero in: Rescue)
var _own := {}           # the story's own people, by role
var _world: World
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
## Where the tram lets the hero off for the European Central Bank, and its doorman: {at: the tram's stop, doorman: pos,
## doorman_faces: pos}. The bank's grounds begin across the road from the stop, and the gate is on that side. Empty if the map
## has no bank or no such stop.
var ecb_stop := {}
## The security gate at the bank's frontage, and the shuttle's way to the door (see SecurityGate.plan). Empty if there is no stop.
var ecb_gate := {}
var ecb_region := Rect2()  # the patch of map that is the bank's market's zone
var lift := {}  # the lift in the plaza ({pos, facing}) and the room it goes up to ({centre, half}); empty if the map has no bank
var roads: RoadGraph  # the streets (also the world's road graph, see build())


func _init(data: Dictionary) -> void:
	district = data
	roads = RoadGraph.new()
	for r in district.roads:
		roads.add_polyline(MapSites.pts(r.pts))
	bike_shop = MapSites.plan_door(district, BIKE_SHOP_BUILDING, STREET)
	sage_house = MapSites.plan_door(district, SAGE_BUILDING, SAGE_STREET)
	var next_door := MapSites.neighbour(district, bike_shop, STREET)
	skate_shop = MapSites.plan_door(district, next_door, STREET) if next_door >= 0 else {}
	ecb = MapSites.plan_door(district, ECB_BUILDING, ECB_STREET)
	ecb_stop = _plan_ecb_stop()
	ecb_gate = SecurityGate.plan(ecb_stop, ecb)
	if not ecb_gate.is_empty():  # the bank's zone: the stop, the gate, the market, the shuttle's whole way and the door, and a margin
		var r := Rect2(ecb_stop.at, Vector2.ZERO)
		for p in [ecb.door, ecb_gate.pad, ecb_gate.entrance, ECB_MARKET] + Array(ecb_gate.route):
			r = r.expand(p)
		ecb_region = r.grow(ECB_REGION_MARGIN)
		_clear_the_banks_way()


## What the map has standing across the gate's frontage and the shuttle's way (hedges, walls, fences, trees) is taken out:
## the gate is the story's own barrier there, and the hero walks up to it from the tram.
const GATE_CLEAR := Rect2(-27.0, -12.0, 54.0, 29.0)  # in the gate's frame (u, v): out to the road, and in past the barriers
const WAY_CLEAR := 2.5                              # metres either side of the shuttle's way


func _clear_the_banks_way() -> void:
	var cuts: Array = []
	var frontage := PackedVector2Array()
	for corner in [GATE_CLEAR.position, Vector2(GATE_CLEAR.end.x, GATE_CLEAR.position.y), GATE_CLEAR.end, Vector2(GATE_CLEAR.position.x, GATE_CLEAR.end.y)]:
		frontage.append(SecurityGate.world_of(ecb_gate, corner))
	cuts.append(frontage)
	var way := PackedVector2Array([ecb_gate.pad]) + (ecb_gate.route as PackedVector2Array) + PackedVector2Array([ecb_gate.entrance])
	for k in way.size() - 1:
		var d := (way[k + 1] - way[k]).normalized() * WAY_CLEAR
		var n := Vector2(-d.y, d.x)
		cuts.append(PackedVector2Array([way[k] - d + n, way[k + 1] + d + n, way[k + 1] + d - n, way[k] - d - n]))
	var street: Dictionary = district.get("street", {})
	var lines: Array = street.get("lines", [])
	for cut in cuts:
		var left: Array = []
		for l in lines:
			for piece in Geometry2D.clip_polyline_with_polygon(l.pts, cut):
				left.append({"kind": l.kind, "pts": piece})
		lines = left
	district = district.duplicate()  # (the story's own copy: the map as loaded stays as the map has it)
	if street.has("lines"):
		district["street"] = street.duplicate()
		district.street["lines"] = lines
	var green: Dictionary = district.get("green", {})
	if green.has("trees"):
		var kept := PackedVector2Array()
		for p in green.trees:
			if not cuts.any(func(cut): return Geometry2D.is_point_in_polygon(p, cut)):
				kept.append(p)
		district["green"] = green.duplicate()
		district.green["trees"] = kept


## The bank's end of the tram ride: the eastbound line's stop for it (TRAM_BANK_AT), and the doorman at the gate across the road.
func _plan_ecb_stop() -> Dictionary:
	if ecb.is_empty():
		return {}
	for route in district.get("routes", []):
		if str(route.ref) != TRAM or not _eastbound(route):
			continue
		for s in route.stops:
			if str(s.name) == TRAM_BANK_AT:
				var into := ECB_GATE_INTO.normalized()
				return {"at": Vector2(s.at[0], s.at[1]), "doorman": ECB_GATE, "doorman_faces": ECB_GATE - into * 20.0}
	return {}


static func _eastbound(route: Dictionary) -> bool:
	return float(route.pts[route.pts.size() - 2]) > float(route.pts[0])


## Which buildings get a door cut into them, for CityBuilder: {building id: {edge, t, width, height}}.
func openings() -> Dictionary:
	var out := {}
	for layout in [bike_shop, skate_shop, sage_house]:
		if not layout.is_empty():
			out[layout.id] = {"edge": layout.edge, "t": layout.t, "width": MapSites.DOOR_WIDTH, "height": MapSites.DOOR_HEIGHT}
	return out


func build() -> World:
	var w := World.new()
	_world = w
	w.roads = roads
	w.clock.time = 0.033 * Clock.DAY_SECONDS  # 6:47 in the morning, the time the intro names

	# The first market: an atom (Atom) on the station forecourt, along the square in front of the train halls, as found: its tent
	# city and keeper, its bins and a fire. The town is its founders, who come a tent at a time as the hero puts tents up (the
	# tutorial walks them through it).
	var dir := _forecourt_dir()
	var station := _toward_station()
	market = Atom.seed(w, Zones.HOME, FORECOURT, market_site())
	# The medical tent on the forecourt's road side, a little back toward where the hero begins, its open end to the square:
	# where the hero is brought when they collapse (the story's own: an atom's is a first aid post).
	var clinic := _fore(HOSPITAL_ALONG, -HOSPITAL_OFF)
	hospital = w.add_hospital(clinic, station)
	facing[hospital] = atan2(-station.x, -station.y)
	facing[w.ambulances[0]] = dir.angle() * -1.0 + PI / 2.0
	_add_bike_shop(w)
	_add_sage(w)
	_add_doorman(w)
	_add_skate_shop(w)
	_add_shuttle_and_reception(w)
	_add_ecb_market(w)
	_add_lift(w)
	_add_plaza_fire(w)
	start = _fore(START_ALONG, 0.0)  # across the square from the tent city: a real first walk
	start_yaw = atan2(-dir.x, -dir.y)
	_add_trams(w)
	for layout in [bike_shop, skate_shop, sage_house]:  # the shops and the sage's house are warm inside
		if not layout.is_empty():
			w.heating.add_building(layout.poly)
	# Walkers keep out of the buildings (the shops with a door cut in them are hollow: people stand inside those)
	var hollow := openings()
	for bd in district.buildings:
		if not hollow.has(int(bd.id)):
			var outline := MapSites.pts(bd.poly)
			w.nav.add_static("district", outline)
			if not ecb_region.has_area() or not _bounds(outline).intersects(ecb_region):
				continue
			w.nav.add_static(ECB_ZONE, outline)  # (and the bank's neighbours are walls in the bank's zone too)
	for prop in LandmarkStyles.PROPS:  # nor through a fountain
		var ground := Landmarks.footprint(prop)
		if not ground.is_empty():
			w.nav.add_static("district", ground)
	for piece in district.get("water", {}).get("pieces", []):  # nor into the Main (over its bridges, streets cut out of it)
		w.nav.add_static("district", piece)
		if ecb_region.has_area() and _bounds(piece).intersects(ecb_region):
			w.nav.add_static(ECB_ZONE, piece)
	for area in district.get("green", {}).get("areas", []):  # the parks: cold for the hero (Cold), and where a camp may go
		if area.kind == "green":
			w.parks.append(area.poly)
	if ecb_region.has_area():
		w.zones.regions[ECB_ZONE] = ecb_region
	wreck_pos = _fore(WRECK_ALONG, -WRECK_OFF)  # on the square, under the arched halls
	wreck_yaw = start_yaw + 0.5
	gun_rest = start + dir * 3.4
	# (Nobody of the story's own is housed in the tent city: the shop owners live in their shops, Mr. Nobody in his house, the
	# bank's people at the bank, and the bankers come later, by helicopter. Its tents are the founders'.)
	return w


## The first market's site (Atom.seed): the forecourt, taken as a street along it, the stalls with their backs to the station.
## Not read off a street of the map, so it is the story's to say (FORECOURT, SITE_WIDTH, SITE_LINE).
func market_site() -> Dictionary:
	return {"point": FORECOURT, "along": _forecourt_dir(), "out": _toward_station(), "width": SITE_WIDTH, "line": SITE_LINE, "street": FORECOURT_NAME}


## Who is who now: the story's own, the tent keepers, and the founders who have come (`cast`).
func _cast_now() -> Dictionary:
	var out := _own.duplicate()
	if _world == null:
		return out
	for pair in [["", market], ["ecb_", ecb_market]]:
		var city: Machine = pair[1]
		if city == null:
			continue
		out[pair[0] + "tent"] = _world.drone(city.owner)
		var runners: Array[Drone] = []
		for d in _world.lodging.housed(city):
			var role := _world.lodging.role_of(d)
			if role == "runner":
				runners.append(d)
			elif FOUNDER_CAST.has(role):
				out[pair[0] + FOUNDER_CAST[role]] = d
		if not runners.is_empty():
			out[pair[0] + "runners"] = runners
	return out


## Tram line 11, both ways, along its own tracks (the district's `routes`): a car each way, waiting at the station and at the
## bank's end. Each goes round: off one edge of the map, on at the other. The eastbound one is the letter quest's first (`held`):
## it takes the hero to TRAM_BREAKS_AT, breaks down outside Mr. Nobody's house, and, mended, goes on to TRAM_BANK_AT.
const TRAM := "11"
const TRAM_COLOUR := Color(0.80, 0.14, 0.50)  # (the story's choice: the map gives the line none)
const TRAM_QUEST := "tram_east"
const TRAM_BREAKS_AT := "Börneplatz"
const TRAM_BANK_AT := "Ostbahnhof/Sonnemannstraße"
const TRAM_WAITS := {"tram_east": "Hauptbahnhof", "tram_west": TRAM_BANK_AT}
const TRAM_STOP_REACH := 5.0


func _add_trams(w: World) -> void:
	for r in district.get("routes", []):
		if str(r.ref) != TRAM:
			continue
		var way := MapSites.pts(r.pts)
		var places: Array = r.stops.map(func(s): return {"name": str(s.name), "at": Vector2(s.at[0], s.at[1])})
		var line := Line.through(way, places, "%s %s" % [TRAM, str(r.to).get_slice(" ", 0)], TRAM_STOP_REACH, 30.0)
		if line == null:
			continue
		line.number = TRAM
		line.colour = TRAM_COLOUR
		var called := TRAM_QUEST if _eastbound(r) else "tram_west"
		w.transit.add_on(called, "tram", line, maxi(0, line.stop_called(TRAM_WAITS[called])))


## The bike shop: its owner behind a counter inside the building, facing the door. Added last, so the
## drifters and the other vendors keep the drone numbers they always had.
func _add_bike_shop(w: World) -> void:
	if bike_shop.is_empty():
		return
	var inward: Vector2 = bike_shop.inward
	var counter: Vector2 = (bike_shop.door as Vector2) + inward * minf(bike_shop.depth * 0.55, 9.0)
	var owner := w.add_vendor("bike_shop", counter, 800.0, true, true)
	owner.profession = "Bike shop owner"
	var m := w.machine_of(owner)
	m.front = -inward  # the customers are on the door side of the counter
	facing[m] = atan2(inward.x, inward.y)  # the yaw that faces `front`
	owner.pos = m.post()
	_own["bike_shop"] = owner


## The skate shop, next to the bike shop: its owner behind a counter, like the bike shop's. Added after everyone else, so no
## earlier drone changes its number.
func _add_skate_shop(w: World) -> void:
	if skate_shop.is_empty():
		return
	var inward: Vector2 = skate_shop.inward
	var counter: Vector2 = (skate_shop.door as Vector2) + inward * minf(skate_shop.depth * 0.55, 9.0)
	var owner := w.add_vendor("skate_shop", counter, 600.0, true, true)
	owner.profession = "Skate shop owner"
	var m := w.machine_of(owner)
	m.front = -inward
	facing[m] = atan2(inward.x, inward.y)
	owner.pos = m.post()
	_own["skate_shop"] = owner


## Mr. Nobody, standing on the pavement outside his door, looking along the street. Added last of all.
func _add_sage(w: World) -> void:
	if sage_house.is_empty():
		return
	var out: Vector2 = sage_house.out
	var sage := w.cast.add_sage(w,(sage_house.door as Vector2) + out * 2.6)
	sage.face_to = sage.pos + out * 20.0
	_own["sage"] = sage
	# He waits for a guest in the middle of his room, on the line in from his door (so the way there is straight).
	w.sage.set_house(sage_house.poly, (sage_house.door as Vector2) + (sage_house.inward as Vector2) * minf(5.0, float(sage_house.depth) * 0.5))


## The European Central Bank's doorman, on the pavement outside the front wall. Added after Mr. Nobody.
func _add_doorman(w: World) -> void:
	if ecb.is_empty():
		return
	var out: Vector2 = ecb.out
	var at: Vector2 = (ecb.door as Vector2) + out * 2.6
	var faces: Vector2 = at + out * 20.0
	if not ecb_stop.is_empty():  # at the gate, across the road from the tram's stop
		at = ecb_stop.doorman
		faces = ecb_stop.doorman_faces
	if not ecb_gate.is_empty():  # in front of the guard's booth, facing the road
		at = ecb_gate.guard
		faces = at - (ecb_gate.into as Vector2) * 20.0
	var d := w.cast.add_doorman(w,at)
	d.face_to = faces
	_own["doorman"] = d


## The shuttle, waiting inside the gate, and the receptionist at the bank's door.
func _add_shuttle_and_reception(w: World) -> void:
	if ecb_gate.is_empty():
		return
	# The golf cart's line, laid out by hand (SecurityGate.plan): from its pad inside the gate, round the market hall and along
	# the plaza, to the bank's door; and back.
	var way := PackedVector2Array([ecb_gate.pad])
	way.append_array(PackedVector2Array(ecb_gate.route))
	way.append(ecb_gate.entrance)
	var line := Line.through(way, [{"at": ecb_gate.pad, "name": "the gate"}, {"at": ecb_gate.entrance, "name": "the main entrance"}], "", 1.0, 20.0, 10.0)
	var cart := w.transit.add_on("shuttle", "cart", line) if line != null else null
	if cart == null:
		cart = w.transit.add("shuttle", "cart", ecb_gate.pad, ecb_gate.pad_heading)
	cart.heading = ecb_gate.pad_heading
	cart.prev_heading = cart.heading
	var r := w.cast.add_receptionist(w,ecb_gate.reception)
	r.face_to = (ecb_gate.reception as Vector2) + (ecb.out as Vector2) * 20.0
	_own["receptionist"] = r


## The lift in the plaza beside the receptionist's desk, and the room it goes up to: a stage-set room of its own, in a zone of its
## own, where the instrument technician waits at his bench. A pair of doorways (see Portals) carries the hero between.
func _add_lift(w: World) -> void:
	if ecb_gate.is_empty():
		return
	var out: Vector2 = ecb.out
	var along: Vector2 = ecb.along
	var below := LIFT_ROOM_CENTRE + Vector2(0.0, LIFT_ROOM_HALF.y - 2.6)  # by the room's back wall, facing into it
	var door_up := Portal.new((ecb_gate.reception as Vector2) + along * 6.0, out, "Lift")
	var door_down := Portal.new(below, Vector2(0.0, -1.0), "Lift down")
	door_up.kind = "lift"
	door_down.kind = "lift"
	door_up.zone = ECB_ZONE
	door_down.zone = LIFT_ZONE
	w.portals.add_pair(door_up, door_down)
	w.cast.lift = door_up
	var c := LIFT_ROOM_CENTRE
	var h := LIFT_ROOM_HALF
	w.heating.add_building(PackedVector2Array([c - h, c + Vector2(h.x, -h.y), c + h, c + Vector2(-h.x, h.y)]))  # (warm upstairs)
	w.heating.add_building(ecb.poly)  # and the bank itself
	lift = {"up": door_up, "down": door_down, "centre": LIFT_ROOM_CENTRE, "half": LIFT_ROOM_HALF}
	w.zones.regions[LIFT_ZONE] = Rect2(LIFT_ROOM_CENTRE - LIFT_ROOM_HALF - Vector2(12, 12), (LIFT_ROOM_HALF + Vector2(12, 12)) * 2.0)
	w.build_zone = LIFT_ZONE
	var t := w.cast.add_technician(w,LIFT_ROOM_CENTRE + Vector2(-2.0, -LIFT_ROOM_HALF.y + 3.2))
	t.face_to = t.pos + Vector2(0.0, 20.0)
	_own["technician"] = t
	w.build_zone = Zones.HOME
	w.zones.asleep.append(LIFT_ZONE)  # the room waits, as the bank's market does, until the hero is in it


## The market the hero finds on getting off the tram for the bank, in a zone of its own: an atom (Atom) grown through all its
## founders at once, its stands wrecked as the first market's are, on the open ground beside the gate (a site of the story's
## own, as the forecourt's is: ECB_MARKET).
func _add_ecb_market(w: World) -> void:
	if ecb_gate.is_empty():
		return
	var dir := ECB_MARKET_DIR.normalized()
	var site := {"point": ECB_MARKET, "along": dir, "out": Vector2(dir.y, -dir.x), "width": SITE_WIDTH, "line": SITE_LINE, "street": ECB_MARKET_NAME}
	ecb_market = Atom.seed(w, ECB_ZONE, ECB_MARKET, site)
	Atom.grow(w, ecb_market)
	w.build_zone = Zones.HOME
	w.zones.asleep.append(ECB_ZONE)  # the bank's people wait, fresh, until the hero gets there


## A barrel fire on the plaza beside the main entrance, where the shuttle lets the hero off (see Cold). (The bank's market has its
## atom's own.)
func _add_plaza_fire(w: World) -> void:
	if ecb_gate.is_empty():
		return
	w.build_zone = ECB_ZONE
	var out: Vector2 = ((ecb_gate.entrance as Vector2) - (ecb.door as Vector2)).normalized()  # (from the door, onto the plaza)
	var aside := Vector2(-out.y, out.x)
	if aside.x > 0.0:  # (to the west of it: the shuttle comes in from the east)
		aside = -aside
	var at: Vector2 = (ecb_gate.entrance as Vector2) + aside * 5.0
	facing[w.add_fire(at)] = atan2(out.x, out.y)
	w.build_zone = Zones.HOME


func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


func story() -> bool:
	return true


## The golf cart is the story's own, drawn and ridden by it (QuestController).
func own_rides() -> Array:
	return ["shuttle"]


## The tram at the station is the letter quest's until it has taken the hero to the bank: it waits for them there, and where it
## breaks down. After that it is anyone's, like the one the other way.
func held(w: World, called: String) -> bool:
	return called == TRAM_QUEST and not w.quests.done("rode_on")


func title() -> String:
	return "Frankfurt, Bahnhofsviertel to the old town"


func landmarks(w: World) -> Array:
	var marks: Array = []
	marks.append({"pos": market.pos, "label": "tent city", "color": Color(0.45, 0.35, 0.6)})
	if not w.hospitals.is_empty():
		marks.append({"pos": w.hospitals[0].pos, "label": "medical tent", "color": Color(0.9, 0.25, 0.25)})
	var station: Array = w.bins.filter(func(b): return b.kind == "organics" and b.zone == w.bins[0].zone)
	if not station.is_empty():
		marks.append({"pos": station[0].pos, "label": "bins", "color": Color(0.35, 0.7, 0.4)})
	var tram := w.transit.vehicle(TRAM_QUEST)
	if tram != null:
		marks.append({"pos": tram.home, "label": "tram %s" % TRAM, "color": TRAM_COLOUR})
	if not bike_shop.is_empty():
		marks.append({"pos": bike_shop.door, "label": "bike shop", "color": Color(0.3, 0.5, 0.85)})
	if not skate_shop.is_empty():
		marks.append({"pos": skate_shop.door, "label": "skate shop", "color": Color(0.9, 0.5, 0.2)})
	return marks


## A spot `dist` metres in front of a stand (on the customers' side, toward the middle of the street) and
## the yaw that faces the stand from there. Tests and the capture tool stand here instead of guessing
## which way the street runs.
func front_of(m: Machine, dist: float) -> Dictionary:
	var spot: Vector2 = m.pos + m.front * dist
	var to := m.pos - spot
	return {"pos": spot, "yaw": atan2(-to.x, -to.y)}


## `from` moved `along` metres down the forecourt (the way the market runs) and `lateral` metres across it (positive toward the
## station).
func offset_on_street(from: Vector2, along: float, lateral: float) -> Vector2:
	var dir := _forecourt_dir()
	return from + dir * along + _toward_station() * lateral


## The way the market runs along the forecourt (the hero faces it as they begin).
func street_dir() -> Vector2:
	return _forecourt_dir()


func _forecourt_dir() -> Vector2:
	return FORECOURT_DIR.normalized()


## Across the forecourt, toward the station's front.
func _toward_station() -> Vector2:
	var dir := _forecourt_dir()
	return Vector2(-dir.y, dir.x)


## A point on the forecourt: `along` metres from the market's middle the way it runs, `across` metres toward the station.
func _fore(along: float, across: float) -> Vector2:
	return offset_on_street(FORECOURT, along, across)
