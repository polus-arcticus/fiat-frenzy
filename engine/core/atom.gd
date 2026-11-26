## The atom: the smallest town that keeps itself going, and the seed of every new tile (a coordinate in, a tile meshed, an atom
## put down on a street of it). It starts as a tent city and its keeper (the spawn factory: Lodging), its bins and a barrel fire,
## and grows by the one mechanic there is: every tent the hero puts up brings someone, and the first to come are its founders,
## always in the same order (Lodging.FOUNDERS):
##   money     the bottle depot and its attendant (Deposit: whoever is short of cash takes the town's bottles there)
##   care      a medic and their first aid post (one bed; it grows into the medical tent)
##   supply    a cart runner, who salvages the town's base inputs from its bins (WasteBin) to whatever wants them
##   drink     a lemonade stand
##   food      a bakery (bread needs only leftovers)
##   clothes   a thrift stall (the tailor), of scrap
##   boards    a homeless camp, of scrap
##   meat      a hot dog stand (it needs the bakery's bread)
## Each comes as a newcomer does, into the tent the hero put up; a business is found wrecked and its owner broke (the hero's
## money gets it going: Cluster.fund). After the founders, newcomers are the dice's (drifters and runners). The tent city's
## first tier holds the keeper and the founders (MachineDef.cap), so growing past them means building it up.
## Its bins (not a role: what the town runs on): a station of three, garbage (scrap: what the tent city is built up of),
## recycling and organics (leftovers: what the bakery and the lemonade stand make bread and lemonade of), and a water fountain;
## on a tile, the map's own bins near the market where it has them (TileLanding). And a barrel fire by the market for whoever is
## not housed (the hero, new to the street, gets only a block or two from one: Cold).
## The Red Cross van is not part of it (that is the story's).
class_name Atom
extends RefCounted

## Where each thing stands on its street: [metres along from the site, across ("kerb", "wall" or "road", see Cluster.spot), by].
## The founders' places (Lodging.FOUNDERS) by their role, and the tent city, the bins (the middle of the station), the fountain
## and the fire. The tent row grows down the street from "tent", so nothing stands beyond it.
const LAYOUT := {
	"tent": [7.0, "wall", 2.0], "lemonade_stand": [2.5, "kerb", 0.6], "bakery": [-2.5, "kerb", 0.6], "fire": [-4.0, "wall", 1.0],
	"runner": [-6.5, "road", 1.5], "hot_dog_stand": [-7.0, "kerb", 0.6], "fountain": [-10.0, "kerb", 0.6],
	"bottle_depot": [-14.0, "kerb", 0.6], "first_aid": [-19.0, "wall", 2.0], "bins": [-24.0, "wall", 1.5],
	"thrift_stall": [-32.0, "wall", 2.0], "scrap_camp": [-39.0, "wall", 2.0],  # (past the bins: room for a pile beside each)
}


## How many people an atom holds when it has grown: its keeper and its founders (the first tier of its tent city: Catalog).
static func size() -> int:
	return 1 + Lodging.FOUNDERS.size()


## The atom's own bins on `site`: a station (WasteBin.station_kinds, or `kinds`) against the wall, and a fountain at the kerb, each
## facing the street. (A tile swaps in the map's own where it has them near: TileLanding.)
static func add_bins(w: World, site: Dictionary, kinds: Array = []) -> void:
	var street_side: Vector2 = -(site.out as Vector2)
	for b in w.add_bin_station(_at(site, "bins"), site.along, kinds.filter(func(k): return k != "fountain")):
		b.front = street_side
	if kinds.is_empty() or kinds.has("fountain"):
		w.add_bin("fountain", _at(site, "fountain")).front = street_side


static func _at(site: Dictionary, role: String) -> Vector2:
	var l: Array = LAYOUT[role]
	return Cluster.spot(site, l[0], l[1], l[2])


## Puts an atom down in `zone` on `site` (a street frame: see Cluster; an open street through `at` if there is none), as it is
## found: the tent city standing, its keeper in its one tent, its bins and fire, and a place on the street kept for each founder.
## `bins`: the station's kinds (WasteBin.station_kinds unless given; with "fountain" for the fountain). Returns the tent city.
static func seed(w: World, zone: String, at: Vector2, site := {}, bins: Array = []) -> Machine:
	if site.is_empty():
		site = Cluster.open_site(at)
	var street_side: Vector2 = -(site.out as Vector2)
	w.build_zone = zone
	var keeper := w.add_vendor("tent", _at(site, "tent"), 0.0, true, true)
	var city := w.machine_of(keeper)
	city.front = street_side
	keeper.pos = city.post()
	city.residence.wing = signf(Vector2(-street_side.y, street_side.x).dot(site.along))
	for f in Lodging.FOUNDERS:
		city.residence.slots[f.role] = {"at": _at(site, f.role), "front": street_side}
	add_bins(w, site, bins)
	w.add_fire(_at(site, "fire"))  # a barrel fire by the market: its people are housed (warm), but a stranger is not (see Cold)
	w.lodging.house_everyone(city)
	return city


## Grows `city` through its founders at once, as the hero would by putting up a tent for each (at no cost):
## the next `n` of them (all, unless given), but for the roles in `skip` (a town laid out without them). Returns who came.
static func grow(w: World, city: Machine, n := -1, skip: Array = []) -> Array[Drone]:
	var came: Array[Drone] = []
	var left := Lodging.FOUNDERS.size() if n < 0 else n
	while left > 0 and not w.lodging.next_founder(city, skip).is_empty():
		if not w.lodging.add_tent(city):
			break
		var d := w.lodging.arrive(city, skip)
		if d == null:
			break
		came.append(d)
		left -= 1
	return came
