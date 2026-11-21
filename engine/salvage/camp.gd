## A homeless camp among the bike scrap: the salvage trade (Catalog.TRADES "salvage"). Its keeper puts together old skateboards
## from the scrap the runners bring (tier 0), and once enough scrap is pooled into it, it is built up into a bike camp that puts
## together old bikes (tier 1: Trades, MachineDef.build_scrap). Both sell to the hero at their flat price, cheap and slow
## (ItemDef.speed). The scrap lies in a pile beside it (ScrapPile).
class_name Camp
extends RefCounted

const KEEPER_WALLET := 10.0  # (enough to pay the runners' fee on a first load of scrap)
const PILE_AT := Vector2(4.5, 0.0)  # where its pile lies, from the camp: along the street, clear of what stands beside the stall


## Pitches a camp at `at`, its counter facing `toward_street`, with a pile of scrap beside it; its keeper gets a tent in the zone's
## tent city if there is one with room. Returns the camp. Any stall that works the street's scrap is pitched the same way (`kind`:
## the thrift stall too, which stitches coats from it).
static func pitch(w: World, at: Vector2, toward_street: Vector2, wallet := KEEPER_WALLET, kind := "scrap_camp", label := "Camp keeper") -> Machine:
	var keeper := w.add_vendor(kind, at, wallet, true, true)  # (open, with a few things already made)
	keeper.label = label
	var camp := w.machine_of(keeper)
	camp.front = toward_street
	keeper.pos = camp.post()
	var along := Vector2(-toward_street.y, toward_street.x)
	w.add_scrap_pile(at + along * PILE_AT.x + toward_street * PILE_AT.y)
	for m in w.zones.machines_in(keeper.zone):
		if m.shelter != null and m.working and w.lodging.room_for(m) > 0:
			keeper.bed = m.uid
			w.lodging.set_tents(m, maxi(m.tents, w.lodging.housed(m).size()))
			break
	return camp
