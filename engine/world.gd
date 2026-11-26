## The model and its composition root: it holds the state, owns every system and ticks them. It knows nothing of nodes, input
## or rendering. The rules each system owns are in docs/ENGINE.md; each system's file says what it does.
class_name World
extends RefCounted

var clock := Clock.new()
var ledger := Ledger.new()
var drones: Array[Drone] = []
var machines: Array[Machine] = []
## People passing through (Passersby): drones too, but not of the town's, so nothing that counts `drones` counts them.
var visitors: Array[Drone] = []
## The zone that everything added from now on belongs to. A scenario sets it before building each patch.
var build_zone := "district"
var relief_trucks: Array[ReliefTruck] = []
var fires: Array[BarrelFire] = []
var bins: Array[WasteBin] = []  # the town's base inputs: its garbage, recycling and organics bins, and its fountains
var hospitals: Array[Hospital] = []
## Where more bins are to be had further out than anyone walks, by the map: [{zone, kind, at, front, walk (metres from the
## market)}] (SiteFinder.rounds). From the map, not saved: built again with it. A round is opened by a runner whose rig
## reaches it (open_round).
var rounds: Array = []
var bottle_depots: Array[BottleDepot] = []  # where bottles are worth their deposit, and the town's fund (see Deposit)
var vehicles: Array[Vehicle] = []  # what the hero can ride: the bus, the bank's golf cart, a train (Transit; each by its name)
var ambulances: Array[Ambulance] = []
var bills: Array[Bill] = []  # printed money, in flight or lying about
var roads: RoadGraph = null  # optional: with one, drones walk the streets
## The parks on the map (the green, OsmDressing: kind "green"), as polygons: where a camp may be pitched (Placing), and where
## the night wind bites (Cold). From the map, not saved: built again with it. None in the story's Frankfurt (yet).
var parks: Array[PackedVector2Array] = []
## The shape of the land (Landform): how high it is anywhere, how steep, metres above the sea. It sets the walkers' pace
## (Walking) and keeps stalls and camps off slopes. From the map and its elevation, not saved: built again with it. Flat (every
## height 0) where there is no elevation: the story's Frankfurt, the headless tests.
var landform := Landform.new()
## The story's scripted cast, by role (Mr. Nobody, the bank's people, its lift): the story's to fill and read. The world only
## holds it (it is the composition root); nothing in the engine looks inside.
var cast := Cast.new()
var gun_owned := false       # the hero has the money gun (set by whoever hands it over)
var player: Drone = null     # the local hero's body: bars and a bag. Not in `drones`, so no NPC logic drives it
## Every hero this world has known, the local one included. Only the local one is here and ticked; the others (from a merged
## save, or co-op friends who are offline) are away, but their pockets and stakes go on (see Ledger, Equity).
var heroes: Array[Drone] = []
var events: Array[String] = []

## Who made this save: a random name, made once, that prefixes the uid of everything made during play (see mint).
var author := ""
## While the world is being built from its map (a scenario, a tile's seed), things are named after their zone and the order they
## are made in, so the same tile built twice names everything the same way: that is what lets two saves of one tile be merged.
## After `begin_play`, things are named after the author.
var seeding := true
var _seeded := {}  # zone -> how many things have been named in it while seeding
var _made := 0     # how many things have been named during play
var _lookup := {}  # uid -> Drone or Machine (the things others refer to by uid)

## The model's only dice. Nothing in the sim calls the global randf: so a world run twice from the same state does the same
## thing, and a tile seeded twice comes out the same (see random()).
var rng := RandomNumberGenerator.new()
## (Saved as a number, so a loaded world rolls the same dice the saved one would have.)
var rng_state: String:  # (a string: a save goes through JSON, whose numbers are doubles and would round all 64 bits of it)
	get:
		return str(rng.state)
	set(v):
		rng.state = v.to_int()
var _zone_rngs := {}  # zone -> its own dice while it is being seeded

## Things that have turned up since the views last looked (a newcomer, things a save had): the game controller makes views for
## them and empties it. Not saved.
var arrivals: Array = []

# The engine's systems (engine/)
var zones: Zones
var summary: TileSummary
var deposit: Deposit
var trades: Trades
var lodging: Lodging
var walking: Walking
var relief: Relief
var levels: Levels
var portals: Portals
var nav: Navigation
var heating: Heating
# The people's (npc/)
var needs: Needs
var logistics: Logistics
var borders: Borders
var cash: Cash
var rescue: Rescue
var chatter: Chatter
var passersby: Passersby
# The hero's (user/) and the story's (story/): only in the game's world (see _init)
var gun: Gun
var gun_tree: GunTree
var commerce: Commerce
var loadout: Loadout
var placing: Placing
var hero: Hero
var riding: Riding
var transit: Transit
var skating: Skating
var sage: Sage
var quests: Quests
var attention: Attention

## The systems that take a turn at the end of every tick, in this order (each has `step(dt)`). A new feature that needs
## one adds its system here and nowhere in `tick`.
var _end_of_tick: Array = []
## The systems whose state is saved, by their field here (Snapshot saves them; Merge merges a system by its class's MERGE table
## if it has one, else takes the host's). Summary, Walking, Navigation and Heating hold nothing a save needs (the scenario
## rebuilds them). This is the one list: a new system with state is added here, beside its field.
const SAVED := ["clock", "ledger", "needs", "logistics", "relief", "gun", "gun_tree", "commerce", "cash", "levels", "rescue", "chatter",
	"hero", "riding", "sage", "portals", "transit", "skating", "quests", "attention", "zones", "borders", "deposit", "trades",
	"lodging", "passersby"]


## `game` false makes an engine-only world: the simulation and its people (engine/ and npc/), and none of the hero's or the
## story's systems (no gun, commerce, riding, skating, transit, sage, quests or attention: those fields stay null). That is
## the world a headless run (a bench, a map of anywhere) needs. The game's world, the default, has them all.
func _init(game := true) -> void:
	author = Crypto.new().generate_random_bytes(5).hex_encode()
	rng.seed = hash("fiat frenzy")
	needs = Needs.new(self)
	logistics = Logistics.new(self)
	walking = Walking.new(self)
	relief = Relief.new(self)
	cash = Cash.new(self)
	levels = Levels.new(self)
	rescue = Rescue.new(self)
	chatter = Chatter.new(self)
	portals = Portals.new(self)
	nav = Navigation.new(self)
	heating = Heating.new(self)
	zones = Zones.new(self)
	summary = TileSummary.new(self)
	borders = Borders.new(self)
	deposit = Deposit.new(self)
	trades = Trades.new(self)
	lodging = Lodging.new(self)
	passersby = Passersby.new(self)
	_end_of_tick = [rescue, borders, trades, lodging, passersby, chatter]
	if game:
		_attach_game()


## The hero's systems (user/) and the story's (story/), and their turns: the hero first (their needs and where they are), the bus
## before everyone else, the story's watchers last.
func _attach_game() -> void:
	gun = Gun.new(self)
	gun_tree = GunTree.new(self)
	commerce = Commerce.new(self)
	loadout = Loadout.new(self)
	placing = Placing.new(self)
	hero = Hero.new(self)
	riding = Riding.new(self)
	transit = Transit.new(self)
	skating = Skating.new(self)
	sage = Sage.new(self)
	quests = Quests.new(self)
	attention = Attention.new(self)
	transit.arrived.connect(func(v: Vehicle) -> void:  # (a vehicle's arrival is whatever its flag says to the story: Quests)
		if v.flag != "":
			quests.set_flag(v.flag))
	_end_of_tick = [hero, transit] + _end_of_tick + [sage, quests, attention]


# ---------------------------------------------------------------- names

## Gives `thing` its uid, for good. Seeded things are "<zone>#<n>"; things made in play are "<author>/<n>", so two saves never
## hand out the same name.
func mint(thing: Object) -> Object:
	if seeding:
		var n: int = _seeded.get(build_zone, 0)
		_seeded[build_zone] = n + 1
		thing.uid = "%s#%d" % [build_zone, n]
	else:
		thing.uid = "%s/%d" % [author, _made]
		_made += 1
	if thing is Drone or thing is Machine:
		_lookup[thing.uid] = thing
	return thing


## The dice for building and play. While seeding, each zone has dice of its own, seeded by its name, so what a tile's seed
## rolls does not depend on which tiles were built before it.
func random() -> RandomNumberGenerator:
	if not seeding:
		return rng
	if not _zone_rngs.has(build_zone):
		var r := RandomNumberGenerator.new()
		r.seed = hash(build_zone)
		_zone_rngs[build_zone] = r
	return _zone_rngs[build_zone]


## Shuffles `arr` in place with the world's dice (Fisher-Yates).
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## The building is over: from now on, new things are named after the author.
func begin_play() -> void:
	seeding = false


## The drone or machine called `uid`, or null.
func thing(uid: String) -> Object:
	return _lookup.get(uid)


## The lookup is rebuilt from the lists (after a load or a merge has replaced them).
func reindex() -> void:
	_lookup.clear()
	for list in [drones, visitors, machines, heroes]:
		for t in list:
			_lookup[t.uid] = t
	if player != null:
		_lookup[player.uid] = player
	zones.invalidate()


## `thing` is gone for good (a passerby): nothing can be looked up by its uid any more.
func forget(thing: Object) -> void:
	_lookup.erase(thing.uid)


# ---------------------------------------------------------------- building the town

func add_drifter(at: Vector2, wallet := 0.0) -> Drone:
	var d := Drone.new(at, wallet)
	d.zone = build_zone
	mint(d)
	d.label = Names.of(d.uid)  # (a real name: what they do is their profession, see profession_of)
	var dice := random()
	d.heading = dice.randf() * TAU
	for n in Drone.NEEDS:  # desync the crowd so they don't all go shopping at once
		d.bars[n] = dice.randf_range(0.6, 1.0)
	drones.append(d)
	zones.invalidate()
	ledger.printed += wallet
	return d


## A vendor owns one machine, where they stand. `working` false means it starts broken.
func add_vendor(machine_kind: String, at: Vector2, wallet := 0.0, working := true, stocked := true) -> Drone:
	var d := add_drifter(at, wallet)
	d.kind = "vendor"
	var m := Machine.new(machine_kind, d.uid, at, working, stocked)
	m.zone = d.zone
	mint(m)
	m.growth = d.growth  # the business and its owner level together
	d.stand = m.uid
	machines.append(m)
	zones.invalidate()
	if Catalog.machine(machine_kind).rich:
		d.make_needless()  # an owner who has no needs and stays at the counter
	return d


## The bottle depot, its kiosk at `at` facing `toward`, with its attendant behind the counter. The fund (the attendant's wallet)
## starts with `fund` dollars. Returns the attendant.
func add_bottle_depot(at: Vector2, toward := Vector2(0, 1), fund := 0.0) -> Drone:
	var depot := BottleDepot.new(at, toward)
	depot.zone = build_zone
	mint(depot)
	var attendant := add_drifter(depot.post(), fund)
	attendant.kind = "attendant"
	attendant.look = "keeper"  # (an apron, not a suit)
	attendant.make_needless()
	attendant.aloof = true
	depot.owner = attendant.uid
	bottle_depots.append(depot)
	return attendant


## A cart runner: waits at `at`, and salvages the town's base inputs from its bins (WasteBin) to whatever wants them, for a fee.
func add_runner(at: Vector2, wallet := 15.0) -> Drone:
	var d := add_drifter(at, wallet)
	d.kind = "runner"
	d.runner = Runner.new()
	d.home = at
	d.speed = d.runner.rig().speed
	return d


## The player's body: survival bars and a bag. They start with a little cash and some bread and water; after
## that their money is what they pick up and what their stakes earn.
func add_player(at: Vector2, cash := 25.0) -> Drone:
	player = Drone.new(at, 0.0)
	player.zone = build_zone
	player.uid = author + "/hero"  # a hero is never seeded: two saves of one tile have two heroes
	_lookup[player.uid] = player
	heroes.append(player)
	ledger.local = player.uid
	player.kind = "player"
	player.label = "You"
	player.care_rate = 5.0  # the tent fusses over the hero: a short sleep, and they wake properly well
	player.wake_at = 0.95
	player.cold_spans = Cold.spans()  # new to the street: a couple of blocks from a fire by day, less at night
	for n in Drone.NEEDS:
		player.bars[n] = 1.0
	ledger.player_cash += cash
	ledger.printed += cash
	for item in Commerce.START_KIT:
		player.carry.add(item, Commerce.START_KIT[item])
	return player


func add_relief_truck(at: Vector2) -> ReliefTruck:
	var t := ReliefTruck.new(at)
	t.zone = build_zone
	mint(t)
	relief_trucks.append(t)
	return t


## The medical tent, with an ambulance parked outside it. `toward_street` is the unit vector from the
## tent out to the street.
## A first aid post (one bed, no ambulance) at `at`, facing `toward_street`, and its medic, who minds it and tends whoever is down
## in the zone (see Rescue). Returns the medic.
func add_first_aid(at: Vector2, toward_street: Vector2, wallet := 0.0) -> Drone:
	var h := Hospital.new(at, toward_street, "first_aid")
	h.zone = build_zone
	mint(h)
	hospitals.append(h)
	var medic := add_drifter(h.post(), wallet)
	medic.kind = "medic"
	medic.home = h.post()  # (where they wait between patients)
	h.owner = medic.uid
	zones.invalidate()
	return medic


func add_hospital(at: Vector2, toward_street: Vector2) -> Hospital:
	var h := Hospital.new(at, toward_street)
	h.zone = build_zone
	mint(h)
	hospitals.append(h)
	zones.invalidate()
	ambulances.append(mint(Ambulance.new(h)))
	return h


## A bin of `kind` in the street (WasteBin: "garbage", "recycling", "organics" or "fountain"), starting with `start` of its
## item (-1: its kind's usual).
func add_bin(kind: String, at: Vector2, start := -1) -> WasteBin:
	var b := WasteBin.new(kind, at, start)
	b.zone = build_zone
	mint(b)
	bins.append(b)
	zones.invalidate()
	return b


## Puts down the bins of `zone`'s round within `reach` metres of its market that aren't there yet: more supply, for whoever
## can get out to it. Returns them (the views are told: arrivals).
func open_round(zone: String, reach: float) -> Array[WasteBin]:
	var out: Array[WasteBin] = []
	var was := build_zone
	build_zone = zone
	for r in rounds:
		if r.zone != zone or float(r.walk) > reach or bins.any(func(b): return b.pos.distance_to(r.at) < ROUND_APART):
			continue
		var b := add_bin(r.kind, r.at)
		b.front = r.front
		b.far = r.walk
		b.rate = float(WasteBin.KINDS[r.kind].rate) * WasteBin.FAR_SHARE
		b.source = "map"
		arrivals.append(b)
		out.append(b)
	build_zone = was
	return out


const ROUND_APART := 3.0  # metres: a bin this near a place on a round is that place's already


## The bins of every kind side by side: the atom's own, where the map has none near (Atom.LAYOUT "bins"), along `along` from
## `at` (WasteBin.station_kinds: garbage, recycling, organics). Returns them.
func add_bin_station(at: Vector2, along := Vector2(1, 0), kinds: Array = []) -> Array[WasteBin]:
	if kinds.is_empty():
		kinds = WasteBin.station_kinds()
	var out: Array[WasteBin] = []
	for k in kinds.size():
		out.append(add_bin(kinds[k], at + along * (float(k) - (kinds.size() - 1) * 0.5) * BIN_APART))
	return out


const BIN_APART := 2.2  # metres between the bins of a station


func add_fire(at: Vector2) -> BarrelFire:
	var f := BarrelFire.new(at)
	f.zone = build_zone
	mint(f)
	fires.append(f)
	zones.invalidate()
	return f


## What `d` does, as words under their name: what the story calls them (Drone.profession), else the keeper of their stand (so
## it follows the stand up its tiers: Catalog.KEEPERS), else their kind's.
## Is `p` in a park?
func in_park(p: Vector2) -> bool:
	for poly in parks:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func profession_of(d: Drone) -> String:
	if d.profession != "":
		return d.profession
	if d.runner != null:
		return d.runner.rig().keeper
	var m := machine_of(d)
	if m != null:
		return Catalog.KEEPERS.get(m.kind, m.display_name() + " keeper")
	return {"runner": "Cart runner", "attendant": "Depot attendant", "medic": "Medic",
		"drifter": "Out of work", "passerby": "Passing through", "player": ""}.get(d.kind, d.kind.capitalize())


func machine_of(d: Drone) -> Machine:
	return _lookup.get(d.stand) if d.stand != "" else null


## The drone called `uid` (the owner of a machine, the keeper of a food bank), or null.
func drone(uid: String) -> Drone:
	return _lookup.get(uid) as Drone


## Everything solid in the street, for keeping drones out of it.
func solids() -> Array[Footprint]:
	var out: Array[Footprint] = []
	for m in machines:
		out.append(m.solid())
	for f in fires:
		out.append(f.solid())
	for h in hospitals:
		out.append(h.solid())
	return out


func total_money() -> float:
	return ledger.total(drones + visitors, bills)


# ---------------------------------------------------------------- the tick

## Is this zone running? (See Zones.)
func is_active(zone: String) -> bool:
	return zones.is_active(zone)


func tick(dt := 1.0) -> void:
	clock.advance(dt)
	zones.step_dormant(dt)
	relief.run()
	var running := zones.running()
	for z in running:
		for m in zones.machines_in(z):
			m.step(dt)
		var heads := zones.heads_in(z)
		for b in zones.bins_in(z):
			b.step(dt, heads)
	needs.wake_sleepers()
	for z in running:
		var here: Array = zones.drones_in(z).duplicate()
		shuffle(here)  # no drone always gets first pick of a thin shelf
		for d in here:
			logistics.act(d, dt)
		for d in zones.drones_in(z):
			needs.decay(d, dt)
	for system in _end_of_tick:  # (the hero's own needs and whereabouts are Hero's turn, first)
		system.step(dt)
