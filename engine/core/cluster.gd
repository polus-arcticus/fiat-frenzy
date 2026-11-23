## The standard cluster: the collection of people a block of the city starts with, defined once. It is the town the economy is
## balanced on: with its bottles worth Deposit.DEPOSIT at its bottle depot (whoever is short of cash collects them), a cluster
## the hero has funded once runs on its own with nobody in the medical tent, and its owners save slowly toward building their
## stands up (Trades; tools/epoch.gd watches it grow for a year). Change what is in it and that balance has to be measured again.
##
## What is in it:
##   the four trades at tier 0  a bakery, a hot dog stand, a lemonade stand and a tent; their owners start with VENDOR_WALLET
##   supply                     its bins (WasteBin: garbage, recycling, two organics, a fountain) and RUNNERS cart runners
##                              (RUNNER_WALLET each), who salvage them into the stands
##   residents                  DRIFTERS drifters with PURSE dollars each
##   for the night and the sick a barrel fire, and the medical tent with its ambulance
##   the outside world          the Red Cross van's stop and the bottle depot
## As a block is found (`found`): every stand wrecked but the tent city, and every owner broke. The hero gets it going (`fund`):
## each owner is given what their repair costs, their reserve and a little over, once.
##
## Everyone in it, the bottle depot's attendant included, has a tent of their own in the tent city (see Lodging): it is built with
## one tent per person, and every tent added brings someone new.
##
## Where it stands: along one side of a street (a SITE: {point on the centre line, along, out toward the
## buildings, width of the carriageway, line: how far out the building line is}). The stands are at the kerb with their counters
## to the carriageway (there is no traffic: people walk in the road), the tent, the fire and the medical tent against the
## buildings, the fountain, the bottle depot and the bins further along, the van parked in the lane. On open ground (tests, benches)
## it is laid out along an open street (`open_site`).
class_name Cluster
extends RefCounted

const STANDS := ["bakery", "hot_dog_stand", "lemonade_stand", "tent"]
const VENDOR_WALLET := 30.0
const RUNNERS := 2
const RUNNER_WALLET := 20.0
const DRIFTERS := 6
const PURSE := 15.0
const FUND_OVER := 5.0  # what the hero gives an owner over their repair and reserve
## How many atoms' worth of leftovers a block's organics give (WasteBin.KINDS): one feeds an atom's 7 but not a block's 13 (five
## collapse in a season), 1.5 or more is so much that every stall sits at its floor and earns nothing. At 1.2 nobody collapses
## and the lemonade stand runs short enough to save a little (about $100 in 120 days: tools/../.godot/probe, 2026-11-22).
const ORGANICS := 1.2
const ROOM_TO_GROW := 4  # tents its tent city may still have put up, beyond the ones it starts with (it is bigger than an Atom)

## Where each thing stands: [metres along the street from the site, where across it]. Across is "kerb" (just on the
## pavement), "wall" (this far in from the building line), or "road" (this far out from the kerb into the carriageway).
## The tent is the first of its modules: it grows down the street from there, one module for every few beds (see Lodging), so
## nothing stands beyond it.
const LAYOUT := {
	"bakery": [-7.5, "kerb", 0.6], "hot_dog_stand": [-2.5, "kerb", 0.6], "lemonade_stand": [2.5, "kerb", 0.6],
	"fire": [5.5, "wall", 1.0], "tent": [9.0, "wall", 2.0], "fountain": [-16.0, "kerb", 0.6], "runners": [-12.5, "road", 1.5],
	"drifters": [-5.0, "road", 2.0], "bottle_depot": [-24.0, "kerb", 0.6], "hospital": [-31.0, "wall", 2.0], "van": [12.0, "road", 1.6], "bins": [-39.5, "wall", 1.5],  # (four bins, 2.2 m apart: clear of the medical tent)
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
## `drifters`, `supply` and `purse` vary it (tests use a bigger purse, or no supply: no runners, and no bins but the garbage);
## `outside` false leaves out the van and the bottle depot (a town on its own).
static func build(w: World, zone: String, at: Vector2, drifters := DRIFTERS, supply := true, purse := PURSE, outside := true, site := {}) -> void:
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
		if m.residence != null:
			tent = m
			m.residence.wing = signf(Vector2(-street_side.y, street_side.x).dot(site.along))  # (its row goes on down the street)
	var kinds := ["garbage"]  # (the tent city is built up of scrap the runners pool into it)
	if supply:
		kinds = ["garbage", "recycling", "organics", "organics"]  # (two organics: a bin feeds an atom's 7, and a block is near twice that)
		w.add_bin("fountain", _at(site, "fountain")).front = street_side
		for i in RUNNERS:
			w.add_runner(_at(site, "runners", i * 1.5), RUNNER_WALLET)
	for b in w.add_bin_station(_at(site, "bins"), site.along, kinds):
		b.front = street_side
		if b.kind == "organics":
			b.rate = float(WasteBin.KINDS.organics.rate) * ORGANICS / 2.0  # (the two share ORGANICS bins' worth)
	for i in drifters:
		w.add_drifter(_at(site, "drifters", i * 2.0), purse)
	w.add_fire(_at(site, "fire"))
	w.add_hospital(_at(site, "hospital"), street_side)
	if outside:
		var van := w.add_relief_truck(_at(site, "van"))
		van.heading = site.along
		w.add_bottle_depot(_at(site, "bottle_depot"), street_side)
	w.lodging.house_everyone(tent)  # a tent each
	tent.residence.tents_cap = tent.residence.tents + ROOM_TO_GROW  # (laid out bigger than an atom: room for a few more all the same)


## The standard cluster as a block is found: built, then every stand but the tent city wrecked and every owner's money gone (taken out of
## what the world was seeded with, so the books still balance).
static func found(w: World, zone: String, at: Vector2, site := {}) -> void:
	build(w, zone, at, DRIFTERS, true, PURSE, true, site)
	for d in w.zones.drones_in(zone):
		if d.kind == "vendor":
			w.machine_of(d).working = w.machine_of(d).shelter != null  # (the tent city stands: it is where everyone lives)
			w.ledger.printed -= d.wallet
			d.wallet = 0.0


## The hero gets a found cluster going: each owner is given (new money, as the gun gives it: Levels.give) what it takes to repair
## their stand if it is wrecked, keep their reserve, and a little over. Call after World.begin_play.
static func fund(w: World, zone: String) -> void:
	for d in w.zones.drones_in(zone):
		if d.kind == "vendor":
			var m := w.machine_of(d)
			w.levels.give(d, (0.0 if m.working else m.repair_cost) + Drone.RESERVE + FUND_OVER)
