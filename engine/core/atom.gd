## The atom: the smallest town that keeps itself going, and the seed of every new tile (a coordinate in, a tile meshed, an atom
## put down on a street of it). One of each role the town needs, each with a tent in its tent city:
##   the tent keeper   the tent city itself: the spawn factory (see Lodging). It stands from the start.
##   food              a bakery (bread needs only leftovers; the hot dog stand, which needs bread, comes with growth)
##   drink             a lemonade stand
##   supply            two cart runners, who salvage the town's base inputs from its bins (WasteBin) to whatever wants them
##   money             the bottle depot and its attendant (Deposit: whoever is short of cash takes the town's bottles there)
##   care              a medic and their first aid post (one bed; it grows into the medical tent)
## And its bins (not a role: what the town runs on): a station of three, garbage (scrap: what the tent city is built up of),
## recycling and organics (leftovers: what the bakery and the lemonade stand make bread and lemonade of), and a water fountain;
## on a tile, the map's own bins near the market where it has them (TileLanding). And a barrel fire by the market for whoever is
## not housed (the hero, new to the street, gets only a block or two from one: Cold).
## No drifters: the seven are each other's customers. Everything after is growth: every tent put up brings someone (Lodging), and
## the tent city's first tier holds the atom's worth of tents (MachineDef.cap), so growing past it means building it up.
## The stands are found wrecked and their owners broke, as a cluster is (Cluster.fund gets them going). The Red Cross van is not
## part of it (that is the story's).
## Measured (tools/probe_atomic.gd): on its own, no van, no collapses in 120 days, about 24 sales a day. Grown by newcomers who
## are only mouths (drifters, runners) it does not hold: +4 gives about 146 collapses in 120 days, +7 about 650, the baker
## hoarding. Growth has to bring producers too (the weighted roll of who comes: Lodging.NEWCOMERS).
class_name Atom
extends RefCounted

## The roles, in the order they are laid out. Its size is how many tents the first tier of a tent city holds.
const ROLES := ["tent", "bakery", "lemonade_stand", "salvager", "runner", "bottle_depot", "first_aid"]
## Where each stands on its street: [metres along from the site, across ("kerb", "wall" or "road", see Cluster.spot), by].
## "bins" is the middle of its bin station (along the street); "fountain" its water fountain.
const LAYOUT := {
	"bakery": [-2.5, "kerb", 0.6], "lemonade_stand": [2.5, "kerb", 0.6], "tent": [7.0, "wall", 2.0],
	"salvager": [-9.0, "road", 1.5], "runner": [-6.5, "road", 1.5], "bottle_depot": [-14.0, "kerb", 0.6],
	"first_aid": [-19.0, "wall", 2.0], "bins": [-24.0, "wall", 1.5], "fire": [-4.0, "wall", 1.0], "fountain": [-9.0, "kerb", 0.6],
}
const SALVAGER_WALLET := 8.0  # (what the food bank's keeper, whose place this is, started with: the town starts as it did)


## The atom's own bins on `site`: a station of three against the wall, and a fountain at the kerb, each facing the street. (A
## tile swaps in the map's own where it has them near: TileLanding.)
static func add_bins(w: World, site: Dictionary) -> void:
	var street_side: Vector2 = -(site.out as Vector2)
	for b in w.add_bin_station(_at(site, "bins"), site.along):
		b.front = street_side
	w.add_bin("fountain", _at(site, "fountain")).front = street_side


static func _at(site: Dictionary, role: String) -> Vector2:
	var l: Array = LAYOUT[role]
	return Cluster.spot(site, l[0], l[1], l[2])


## Puts an atom down in `zone` on `site` (a street frame: see Cluster; an open street through `at` if there is none), as it is
## found: the tent city standing and everyone housed, the stands wrecked and their owners broke. Returns the tent city.
static func seed(w: World, zone: String, at: Vector2, site := {}) -> Machine:
	if site.is_empty():
		site = Cluster.open_site(at)
	var street_side: Vector2 = -(site.out as Vector2)
	w.build_zone = zone
	var city: Machine = null
	for kind in ["bakery", "lemonade_stand", "tent"]:
		var v := w.add_vendor(kind, _at(site, kind), 0.0, kind == "tent", true)
		var m := w.machine_of(v)
		m.front = street_side
		v.pos = m.post()
		if m.residence != null:
			city = m
			m.residence.wing = signf(Vector2(-street_side.y, street_side.x).dot(site.along))
	w.add_runner(_at(site, "salvager"), SALVAGER_WALLET)
	w.add_runner(_at(site, "runner"), Cluster.RUNNER_WALLET)
	w.add_bottle_depot(_at(site, "bottle_depot"), street_side)
	w.add_first_aid(_at(site, "first_aid"), street_side)
	add_bins(w, site)
	w.add_fire(_at(site, "fire"))  # a barrel fire by the market: its people are housed (warm), but a stranger is not (see Cold)
	w.lodging.house_everyone(city)
	return city
