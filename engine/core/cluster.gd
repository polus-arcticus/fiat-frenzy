## The standard cluster: the collection of people a block of the city starts with, defined once. It is the town the economy is
## balanced on: with the welfare office's fountain at Welfare.DOLLARS_A_DAY ($12 a resident a day), a cluster the hero has
## funded once runs on its own with nobody in the medical tent, and its owners save slowly toward building their stands up
## (Trades; tools/epoch.gd watches it grow for a year). Change what is in it and that balance has to be measured again.
##
## What is in it:
##   the four trades at tier 0  a bakery, a hot dog stand, a lemonade stand and a tent; their owners start with VENDOR_WALLET
##   supply                     the food bank (its keeper with KEEPER_WALLET) and RUNNERS cart runners (RUNNER_WALLET each)
##   residents                  DRIFTERS drifters with PURSE dollars each
##   for the night and the sick a barrel fire, and the medical tent with its ambulance
##   the outside world          the Red Cross van's stop and the welfare office
## As a block is found (`found`): every stand wrecked and every owner broke. The hero gets it going (`fund`): each owner is
## given what their repair costs, their reserve and a little over, once.
##
## Everyone in it has a bed in the tent (see Lodging): it is built with as many beds as people, and a free bed draws a newcomer.
##
## Where it stands: along one side of a street (a SITE: {point on the centre line, along, out toward the
## buildings, width of the carriageway, line: how far out the building line is}). The stands are at the kerb with their counters
## to the carriageway (there is no traffic: people walk in the road), the tent, the fire and the medical tent against the
## buildings, the food bank and the welfare office further along, the van parked in the lane. On open ground (tests, benches)
## it is laid out along an open street (`open_site`).
class_name Cluster
extends RefCounted

const STANDS := ["bakery", "hot_dog_stand", "lemonade_stand", "tent"]
const VENDOR_WALLET := 30.0
const KEEPER_WALLET := 8.0
const RUNNERS := 2
const RUNNER_WALLET := 20.0
const DRIFTERS := 6
const PURSE := 15.0
const FUND_OVER := 5.0  # what the hero gives an owner over their repair and reserve

## Where each thing stands: [metres along the street from the site, where across it]. Across is "kerb" (just on the
## pavement), "wall" (this far in from the building line), or "road" (this far out from the kerb into the carriageway).
## The tent is the first of its modules: it grows down the street from there, one module for every few beds (see Lodging), so
## nothing stands beyond it.
const LAYOUT := {
	"bakery": [-7.5, "kerb", 0.6], "hot_dog_stand": [-2.5, "kerb", 0.6], "lemonade_stand": [2.5, "kerb", 0.6],
	"fire": [5.5, "wall", 1.0], "tent": [9.0, "wall", 2.0], "food_bank": [-16.0, "kerb", 0.6], "runners": [-12.5, "road", 1.5],
	"drifters": [-5.0, "road", 2.0], "welfare_office": [-24.0, "kerb", 0.6], "hospital": [-31.0, "wall", 2.0], "van": [12.0, "road", 1.6],
}


## An open street through `at`, running east (the default site, where there is no map).
static func open_site(at: Vector2) -> Dictionary:
	return {"point": at, "along": Vector2(1, 0), "out": Vector2(0, 1), "width": 7.0, "line": 6.0}


## The point `along` metres down the site's street, placed across it as LAYOUT says.
static func spot(site: Dictionary, along: float, across: String, by: float) -> Vector2:
	var kerb: float = float(site.width) * 0.5
	var lateral: float = kerb + by
	if across == "wall":
		lateral = maxf(float(site.line) - by, kerb + 0.5)
	elif across == "road":
		lateral = kerb - by
	return (site.point as Vector2) + (site.along as Vector2) * along + (site.out as Vector2) * lateral


static func _at(site: Dictionary, what: String, shift := 0.0) -> Vector2:
	var l: Array = LAYOUT[what]
	return spot(site, l[0] + shift, l[1], l[2])


## Builds a cluster in `zone` at `site` (or along an open street through `at`, if there is none), everything working.
## `drifters`, `food_bank` and `purse` vary it (tests use a bigger purse, or no food bank); `outside` false leaves out the van and
## the welfare office (a town on its own).
static func build(w: World, zone: String, at: Vector2, drifters := DRIFTERS, food_bank := true, purse := PURSE, outside := true, site := {}) -> void:
	if site.is_empty():
		site = open_site(at)
	var street_side: Vector2 = -(site.out as Vector2)  # (what faces the carriageway)
	w.build_zone = zone
	var tent: Machine = null
	for kind in STANDS:
		var v := w.add_vendor(kind, _at(site, kind), VENDOR_WALLET, true, true)
		var m := w.machine_of(v)
		m.front = street_side
		v.pos = m.post()
		if m.shelter != null:
			tent = m
			m.wing = signf(Vector2(-street_side.y, street_side.x).dot(site.along))  # (its modules go on down the street)
	if food_bank:
		var keeper := w.add_food_bank(_at(site, "food_bank"), KEEPER_WALLET)
		var fb := w.food_bank_of(keeper)
		fb.front = street_side
		keeper.pos = fb.post()
		for i in RUNNERS:
			w.add_runner(_at(site, "runners", i * 1.5), RUNNER_WALLET)
	for i in drifters:
		w.add_drifter(_at(site, "drifters", i * 2.0), purse)
	w.add_fire(_at(site, "fire"))
	w.add_hospital(_at(site, "hospital"), street_side)
	if outside:
		var van := w.add_relief_truck(_at(site, "van"))
		van.heading = site.along
		w.add_welfare_office(_at(site, "welfare_office"), street_side)
	w.lodging.house_everyone(tent)  # a bed for everyone


## The standard cluster as a block is found: built, then every stand wrecked and every owner's money gone (taken out of
## what the world was seeded with, so the books still balance).
static func found(w: World, zone: String, at: Vector2, site := {}) -> void:
	build(w, zone, at, DRIFTERS, true, PURSE, true, site)
	for d in w.zones.drones_in(zone):
		if d.kind == "vendor":
			w.machine_of(d).working = false
			w.ledger.printed -= d.wallet
			d.wallet = 0.0


## The hero gets a found cluster going: each owner is given (new money, as the gun gives it: Levels.give) what it takes to repair their stand, keep their
## reserve, and a little over. Call after World.begin_play.
static func fund(w: World, zone: String) -> void:
	for d in w.zones.drones_in(zone):
		if d.kind == "vendor":
			w.levels.give(d, w.machine_of(d).repair_cost + Drone.RESERVE + FUND_OVER)
