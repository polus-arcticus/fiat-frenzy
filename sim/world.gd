## The model: the headless town. It holds the state and the systems that act on it; it knows nothing
## about nodes, input or rendering. Views read it, controllers drive it.
##
## Planet Crafter's automation with people as the drones: machines offer items from their output
## inventories and want items in their input inventories, drones have needs, and an idle drone looks for a
## supply that answers its most pressing demand, walks there and moves the item. All the rules live in the
## systems, each owning one concern:
##   Clock       time, day and night
##   Needs       how the bars drain, Maslow's demands, sleepers waking
##   Logistics   matching demands to supplies and carrying out the job
##   Walking     moving drones, along streets when there is a road graph
##   Relief      the Red Cross van's timetable
##   Gun         the player's two ways of spending money
##   Commerce    the player buying from stands and eating what they carry
##   Cash        loose money in the street, and who picks it up
##   Chatter     what people say
##   Hero        how the hero is moving about: on foot, riding, skating or seated (one at a time)
##   Riding      getting on and off the bicycle
##   Sage        Mr. Nobody: who has met whom, and what he has told
##   Portals     the teleporter rings
##   Transit     the bus: boarding, driving itself along the streets, arriving
##   Skating     the skateboard: rolling, the ollie, the kickflip (and its $25)
##   Navigation  where people can walk: a grid per zone of what is solid, and paths round it
##   Heating     the warm indoors: the shops, the sage's house, the bus
##   Zones       which patches of the map run, and the books of each
##   Quests      what the hero has been asked to do, and how far along it is
##   Attention   who needs the hero's help, as a gold glow
##   Rescue      collapsing, the ambulance, and the medical tent
##   Levels      experience (money given) and what a level does to a business
##   Ledger      where the money is
## Most of these live in features/<name>/ with their views and controllers (see the README); the engine they all stand on
## (clock, zones, navigation, walking, logistics, needs, ledger) is in sim/systems.
class_name World
extends RefCounted

var clock := Clock.new()
var ledger := Ledger.new()
var drones: Array[Drone] = []
var machines: Array[Machine] = []
## The zone that everything added from now on belongs to. A scenario sets it before building each patch.
var build_zone := "district"
var relief_trucks: Array[ReliefTruck] = []
var fires: Array[BarrelFire] = []
var food_banks: Array[FoodBank] = []
var hospitals: Array[Hospital] = []
var ambulances: Array[Ambulance] = []
var bills: Array[Bill] = []  # printed money, in flight or lying about
var roads: RoadGraph = null  # optional: with one, drones walk the streets
var bike: Bike = null        # the player's bicycle, once they have bought one
var sage_drone: Drone = null    # Mr. Nobody, if this world has him
var ecb_doorman: Drone = null   # the doorman at the European Central Bank, if this world reaches it
var bus_stop := Vector2(INF, INF)  # where the bus waits, if this world has one
var bus: Bus = null                # the bus itself (see add_bus)
var gun_owned := false       # the hero has the money gun (set by whoever hands it over)
var player: Drone = null     # the player's body: bars and a bag. Not in `drones`, so no NPC logic drives it
var events: Array[String] = []

var zones: Zones
var needs: Needs
var logistics: Logistics
var walking: Walking
var relief: Relief
var gun: Gun
var commerce: Commerce
var cash: Cash
var levels: Levels
var rescue: Rescue
var chatter: Chatter
var hero: Hero
var riding: Riding
var sage: Sage
var portals: Portals
var transit: Transit
var skating: Skating
var nav: Navigation
var heating: Heating
var quests: Quests
var attention: Attention

## The systems that take a turn at the end of every tick, in this order (each has `step(dt)`). A new feature that needs
## one adds its system here and nowhere in `tick`.
var _end_of_tick: Array = []


func _init() -> void:
	needs = Needs.new(self)
	logistics = Logistics.new(self)
	walking = Walking.new(self)
	relief = Relief.new(self)
	gun = Gun.new(self)
	commerce = Commerce.new(self)
	cash = Cash.new(self)
	levels = Levels.new(self)
	rescue = Rescue.new(self)
	chatter = Chatter.new(self)
	hero = Hero.new(self)
	riding = Riding.new(self)
	sage = Sage.new(self)
	portals = Portals.new()
	transit = Transit.new(self)
	skating = Skating.new(self)
	nav = Navigation.new(self)
	heating = Heating.new(self)
	zones = Zones.new(self)
	quests = Quests.new(self)
	attention = Attention.new(self)
	_end_of_tick = [transit, rescue, chatter, sage, quests, attention]


# ---------------------------------------------------------------- building the town

func add_drifter(at: Vector2, wallet := 0.0) -> Drone:
	var d := Drone.new(drones.size(), at, wallet)
	d.zone = build_zone
	d.heading = randf() * TAU
	drones.append(d)
	zones.invalidate()
	ledger.printed += wallet
	return d


## A vendor owns one machine, where they stand. `working` false means it starts broken.
func add_vendor(machine_kind: String, at: Vector2, wallet := 0.0, working := true, stocked := true) -> Drone:
	var d := add_drifter(at, wallet)
	d.kind = "vendor"
	var m := Machine.new(machine_kind, d.id, at, working, stocked)
	m.zone = d.zone
	m.growth = d.growth  # the business and its owner level together
	d.station = machines.size()
	machines.append(m)
	zones.invalidate()
	if Catalog.machine(machine_kind).rich:
		d.make_needless()  # an owner who has no needs and stays at the counter
	return d


## The food bank, and its keeper standing behind the counter. Returns the keeper.
func add_food_bank(at: Vector2, keeper_wallet := 8.0) -> Drone:
	var keeper := add_drifter(at, keeper_wallet)
	keeper.kind = "keeper"
	keeper.label = "Food bank keeper"
	keeper.depot = food_banks.size()
	var fb := FoodBank.new(at, keeper.id)
	fb.zone = build_zone
	food_banks.append(fb)
	zones.invalidate()
	keeper.pos = fb.post()
	return keeper


## Mr. Nobody, standing at `at`: an unremarkable stranger who has no needs, takes no part in the town's errands
## (he never goes for loose money) and stays where he is put.
func add_sage(at: Vector2) -> Drone:
	var d := add_drifter(at, 0.0)
	d.kind = "sage"
	d.look = "sage"
	d.label = "Stranger"  # until he introduces himself (Sage.learn_name)
	d.make_needless()
	d.aloof = true  # he does not bend down for loose money, which is how you can tell he is strange
	sage_drone = d
	return d


## The doorman at the European Central Bank: like Mr. Nobody he has no needs and stays at his post. The letter
## quest ends with him.
func add_doorman(at: Vector2) -> Drone:
	var d := add_drifter(at, 0.0)
	d.kind = "clerk"
	d.look = "clerk"
	d.label = "ECB doorman"
	d.make_needless()
	d.aloof = true
	ecb_doorman = d
	return d


## A cart runner: waits at `at`, and wheels base materials from the food bank to storefronts for a fee.
func add_runner(at: Vector2, wallet := 15.0) -> Drone:
	var d := add_drifter(at, wallet)
	d.kind = "runner"
	d.home = at
	d.speed = Walking.RUNNER_SPEED
	return d


func food_bank_of(d: Drone) -> FoodBank:
	return food_banks[d.depot] if d.depot >= 0 else null


## The player's body: survival bars and a bag. They start with a little cash and some bread and water; after
## that their money is what they pick up and what their stakes earn.
func add_player(at: Vector2, cash := 25.0) -> Drone:
	player = Drone.new(-1, at, 0.0)
	player.zone = build_zone
	player.kind = "player"
	player.label = "You"
	player.care_rate = 5.0  # the tent fusses over the hero: a short sleep, and they wake properly well
	player.wake_at = 0.95
	for n in Drone.NEEDS:
		player.bars[n] = 1.0
	ledger.player_cash += cash
	ledger.printed += cash
	for item in Commerce.START_KIT:
		player.carry.add(item, Commerce.START_KIT[item])
	return player


## The bus, waiting at its stop. `facing` is the angle of the way it points (as Walking measures it).
func add_bus(at: Vector2, facing: float) -> Bus:
	bus = Bus.new(at, facing)
	bus.zone = build_zone
	bus_stop = at
	return bus


func add_relief_truck(at: Vector2) -> ReliefTruck:
	var t := ReliefTruck.new(at)
	t.zone = build_zone
	relief_trucks.append(t)
	return t


## The medical tent, with an ambulance parked outside it. `toward_street` is the unit vector from the
## tent out to the street.
func add_hospital(at: Vector2, toward_street: Vector2) -> Hospital:
	var h := Hospital.new(at, toward_street)
	h.zone = build_zone
	hospitals.append(h)
	zones.invalidate()
	ambulances.append(Ambulance.new(h))
	return h


func add_fire(at: Vector2) -> BarrelFire:
	var f := BarrelFire.new(at)
	f.zone = build_zone
	fires.append(f)
	zones.invalidate()
	return f


func machine_of(d: Drone) -> Machine:
	return machines[d.station] if d.station >= 0 else null


## Everything solid in the street, for keeping drones out of it.
func solids() -> Array[Footprint]:
	var out: Array[Footprint] = []
	for m in machines:
		out.append(m.solid())
	for fb in food_banks:
		out.append(fb.solid())
	for f in fires:
		out.append(f.solid())
	for h in hospitals:
		out.append(h.solid())
	return out


func total_money() -> float:
	return ledger.total(drones, bills)


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
		for fb in zones.food_banks_in(z):
			fb.step(dt)
	needs.wake_sleepers()
	for z in running:
		var here: Array = zones.drones_in(z).duplicate()
		here.shuffle()  # no drone always gets first pick of a thin shelf
		for d in here:
			logistics.act(d, dt)
		for d in zones.drones_in(z):
			needs.decay(d, dt)
	if player != null:
		needs.decay(player, dt)
	for system in _end_of_tick:
		system.step(dt)
