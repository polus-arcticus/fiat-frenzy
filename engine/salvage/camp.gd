## A homeless camp among the bike scrap: the salvage trade (Catalog.TRADES "salvage"). Its keeper puts together old skateboards
## from the scrap the runners bring (tier 0), and once enough scrap is pooled into it, it is built up into a bike camp that puts
## together old bikes (tier 1: Trades, MachineDef.build_goods). Both sell to the hero at their flat price, cheap and slow
## (ItemDef.speed). Its scrap gathers in a garbage bin beside it (WasteBin).
class_name Camp
extends RefCounted

const KEEPER_WALLET := 10.0  # (enough to pay the runners' fee on a first load of scrap)
const PILE_AT := Vector2(4.5, 0.0)  # where its pile lies, from the camp: along the street, clear of what stands beside the stall
const FIRE_AT := Vector2(-3.5, 0.0)  # and its own barrel fire, the other side (a camp in a park: its keeper lives by it)


## A camp founded in play (the hero put a camp kit down in a park: Placing): pitched with its own fire, a newcomer keeping it.
## What is new is told to the views (World.arrivals). Returns the camp.
static func found(w: World, at: Vector2, toward_street: Vector2, zone: String) -> Machine:
	var was := w.build_zone
	w.build_zone = zone
	var camp := pitch(w, at, toward_street, KEEPER_WALLET, "scrap_camp", "Camp keeper", true)
	w.build_zone = was
	var keeper := w.drone(camp.owner)
	keeper.arrived_at = w.clock.time
	w.arrivals.append(camp)
	w.arrivals.append(keeper)
	w.arrivals.append(w.fires[w.fires.size() - 1])
	w.zones.invalidate()
	w.events.append("t=%d a camp was pitched in the park: %s keeps it" % [w.clock.time, keeper.label])
	return camp


## Pitches a camp at `at`, its counter facing `toward_street`, with a pile of scrap beside it. Its keeper gets a tent in the
## zone's tent city if there is one with room; or, `with_fire`, the camp has a barrel fire of its own and its keeper lives by it
## (a camp in a park: SiteFinder.camp, Placing). Returns the camp. Any stall that works the street's scrap is pitched the same
## way (`kind`: the thrift stall too, which stitches coats from it).
static func pitch(w: World, at: Vector2, toward_street: Vector2, wallet := KEEPER_WALLET, kind := "scrap_camp", label := "Camp keeper", with_fire := false, home: Machine = null) -> Machine:
	var keeper := w.add_vendor(kind, at, wallet, true, true)  # (open, with a few things already made)
	keeper.profession = label  # (what they are called: their name is their own)
	var camp := w.machine_of(keeper)
	camp.front = toward_street
	keeper.pos = camp.post()
	var along := Vector2(-toward_street.y, toward_street.x)
	if with_fire:  # (a park camp shares the town's scrap: a pile of its own doubled what the runner hauls, and the fees he earns)
		w.add_fire(at + along * FIRE_AT.x + toward_street * FIRE_AT.y)
		return camp
	w.add_bin("garbage", at + along * PILE_AT.x + toward_street * PILE_AT.y).front = toward_street
	if home != null:  # (a newcomer to that tent city: the tent that was waiting for them)
		keeper.bed = home.uid
		return camp
	for m in w.zones.machines_in(keeper.zone):
		if m.residence != null and m.working and w.lodging.room_for(m) > 0:
			keeper.bed = m.uid
			w.lodging.set_tents(m, maxi(m.residence.tents, w.lodging.housed(m).size()))
			break
	return camp
