## The atom: the smallest town that keeps itself going, and the seed of every new tile (a coordinate in, a tile meshed, an atom
## put down on a street of it). One of each role the town needs, each with a tent in its tent city:
##   the tent keeper   the tent city itself: the spawn factory (see Lodging). It stands from the start.
##   food              a bakery (bread needs only flour; the hot dog stand, which needs bread, comes with growth)
##   drink             a lemonade stand
##   supply            the food bank and its keeper, and one cart runner
##   money             the welfare office and its clerk
##   care              a medic and their first aid post (one bed; it grows into the medical tent)
## And a pile of scrap in the street (not a role: what the runner pools into the tent city to build it up into a hostel), and a
## barrel fire by the market for whoever is not housed (the hero, new to the street, gets only a block or two from one: Cold).
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
const ROLES := ["tent", "bakery", "lemonade_stand", "food_bank", "runner", "welfare_office", "first_aid"]
## Where each stands on its street: [metres along from the site, across ("kerb", "wall" or "road", see Cluster.spot), by].
const LAYOUT := {
	"bakery": [-2.5, "kerb", 0.6], "lemonade_stand": [2.5, "kerb", 0.6], "tent": [7.0, "wall", 2.0],
	"food_bank": [-9.0, "kerb", 0.6], "runner": [-6.5, "road", 1.5], "welfare_office": [-14.0, "kerb", 0.6],
	"first_aid": [-19.0, "wall", 2.0], "scrap": [-24.0, "wall", 1.5], "fire": [-4.0, "wall", 1.0],
}


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
		if m.shelter != null:
			city = m
			m.wing = signf(Vector2(-street_side.y, street_side.x).dot(site.along))
	var keeper := w.add_food_bank(_at(site, "food_bank"), Cluster.KEEPER_WALLET)
	w.food_bank_of(keeper).front = street_side
	keeper.pos = w.food_bank_of(keeper).post()
	w.add_runner(_at(site, "runner"), Cluster.RUNNER_WALLET)
	w.add_welfare_office(_at(site, "welfare_office"), street_side)
	w.add_first_aid(_at(site, "first_aid"), street_side)
	w.add_scrap_pile(_at(site, "scrap"))  # (what the runner pools into the tent city to build it up: see ScrapPile)
	w.add_fire(_at(site, "fire"))  # a barrel fire by the market: its people are housed (warm), but a stranger is not (see Cold)
	w.lodging.house_everyone(city)
	return city
