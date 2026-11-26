## The standard cluster: the collection of people a block of the city starts with, defined once. It is an atom grown through all
## its founders (Atom, Lodging.FOUNDERS), with a block's worth more: RUNNERS cart runners in all, more organics, the Red Cross
## van's stop (and DRIFTERS residents, none by default). It is the town the economy is balanced on: with its bottles worth Deposit.DEPOSIT at
## its bottle depot (whoever is short of cash collects them), a cluster the hero has funded once runs on its own with nobody
## collapsing, and its owners save slowly toward building their stands up (Trades; tools/epoch.gd watches it grow for a year).
## Change what is in it and that balance has to be measured again.
##
## As it is built (`build`): every stand working, its owner with VENDOR_WALLET. As a block is found (`found`): every stand
## wrecked but the tent city, and every owner broke. The hero gets it going (`fund`): each owner is given what their repair
## costs, their reserve and a little over, once.
##
## Where it stands: along one side of a street (a SITE: {point on the centre line, along, out toward the buildings, width of the
## carriageway, line: how far out the building line is}), laid out as the atom is (Atom.LAYOUT). On open ground (tests,
## benches) it is laid out along an open street (`open_site`).
class_name Cluster
extends RefCounted

const VENDOR_WALLET := 30.0
const RUNNERS := 2
const RUNNER_WALLET := 20.0
## Residents with no trade of their own (none by default: with the atom's founders, six of them were 100+ collapses a season, the
## mouths outgrowing the producers, 2026-11-25; a town is its founders, Lodging). Tests may add some.
const DRIFTERS := 0
const PURSE := 15.0
const FUND_OVER := 5.0  # what the hero gives an owner over their repair and reserve
## How many atoms' worth of leftovers a block's organics give (WasteBin.KINDS): one feeds an atom but not a block (five collapsed
## in a season), 1.5 or more is so much that every stall sits at its floor and earns nothing. At 1.2 nobody collapsed and the
## lemonade stand ran short enough to save a little (2026-11-22).
const ORGANICS := 1.2
const ROOM_TO_GROW := 4  # tents its tent city may still have put up, beyond the ones it starts with (it is bigger than an Atom)
const VAN_AT := [12.0, "road", 1.6]  # where the van parks, as Atom.LAYOUT: in the lane by the tent city


## An open street through `at`, running east (the default site, where there is no map).
static func open_site(at: Vector2) -> Dictionary:
	return {"point": at, "along": Vector2(1, 0), "out": Vector2(0, 1), "width": 7.0, "line": 6.0}


## The point `along` metres down the site's street, placed across it: "kerb" (just on the pavement), "wall" (this far in from
## the building line), or "road" (this far out from the kerb into the carriageway).
static func spot(site: Dictionary, along: float, across: String, by: float) -> Vector2:
	var kerb: float = float(site.width) * 0.5
	var lateral: float = kerb + by
	if across == "wall":
		lateral = maxf(float(site.line) - by, kerb + 0.5)
	elif across == "road":
		lateral = kerb - by
	return (site.point as Vector2) + (site.along as Vector2) * along + (site.out as Vector2) * lateral


## Builds a cluster in `zone` at `site` (or along an open street through `at`, if there is none), everything working.
## `drifters`, `supply` and `purse` vary it (tests use a bigger purse, or no supply: no runners, and no bins but the garbage);
## `outside` false leaves out the van and the bottle depot (a town on its own). Returns its tent city.
static func build(w: World, zone: String, at: Vector2, drifters := DRIFTERS, supply := true, purse := PURSE, outside := true, site := {}) -> Machine:
	if site.is_empty():
		site = open_site(at)
	var skip := []
	if not supply:
		skip.append("runner")
	if not outside:
		skip.append("bottle_depot")
	var bins: Array = ["garbage"]  # (the tent city is built up of scrap the runners pool into it)
	if supply:
		bins = WasteBin.station_kinds() + ["organics", "fountain"]  # (two organics: a bin feeds an atom, and a block is near twice that)
	var city := Atom.seed(w, zone, at, site, bins)
	Atom.grow(w, city, -1, skip)
	for d in w.zones.drones_in(zone):  # (built working, its owners with money: `found` wrecks it again)
		if d.kind == "vendor":
			w.machine_of(d).working = true
			w.machine_of(d).refresh()
			w.ledger.printed += VENDOR_WALLET - d.wallet
			d.wallet = VENDOR_WALLET
	for b in w.zones.bins_in(zone):
		if b.kind == "organics" and supply:
			b.rate = float(WasteBin.KINDS.organics.rate) * ORGANICS / 2.0  # (the two share ORGANICS bins' worth)
	w.build_zone = zone
	if supply:
		var runners := w.zones.runners_in(zone).size()
		for i in range(runners, RUNNERS):
			w.add_runner(Atom._at(site, "runner") - (site.along as Vector2) * 1.5 * i, RUNNER_WALLET)
	var street_side: Vector2 = -(site.out as Vector2)
	for i in drifters:
		w.add_drifter(spot(site, -5.0 + i * 2.0, "road", 2.0), purse)
	if outside:
		var van := w.add_relief_truck(spot(site, VAN_AT[0], VAN_AT[1], VAN_AT[2]))
		van.heading = site.along
	w.lodging.house_everyone(city)  # a tent each
	city.residence.tents_cap = city.residence.tents + ROOM_TO_GROW  # (laid out bigger than an atom: room for a few more all the same)
	return city


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
