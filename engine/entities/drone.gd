## An NPC. Every NPC is a drone: it carries items between supplies and its own demands, and what it
## demands changes with Maslow's order (see Needs.demands): survival first, then its vocation.
##
## A vendor is a drone with its own machine (1:1). A keeper minds the food bank. A runner wheels a shopping
## cart of base materials from the food bank to the storefronts that are short, for a fee. A drifter has no
## machine and is just a customer, for now. Money is a number on the drone, not an item.
class_name Drone
extends RefCounted

const NEEDS := ["hunger", "thirst", "warmth"]
const RESERVE := 10.0  # dollars an agent keeps back for groceries before it spends on stock, repairs or building up
## How two saves of the same drone combine (see Merge): what each save added to these is added up; anything not listed is
## taken from the host's save.
const MERGE := {"wallet": "sum", "rep": "max", "delivered_total": "sum", "deliveries": "sum", "fees_earned": "sum"}
## What a runner's cart business is worth before anyone gives it a cent (its "book", like a machine's repair cost: see Equity).
const CART_VALUE := 20.0
const MAX_INSULATION := 0.9  # however many coats: the cold still gets in (a tenth as fast)

var uid := ""      # who this is, for good: unique across saves, so two saves can be combined (see World.mint)
var label := ""        # a name for the HUD
var kind := "drifter"  # drifter, vendor, keeper or runner
var look := ""         # which model to wear, if not the one for its kind (e.g. "banker")
var wallet := 0.0
var carry := Inventory.new()
var gear := Inventory.new()  # what they have on and ride: the hero's loadout (see Loadout); nobody else's yet
## Seconds a full warmth bar lasts in the open without clothes, for this one: x by day, y at night. Zero: the street's usual
## (Needs.DAY_COOLING, NIGHT_COOLING). The hero's is much shorter (Cold).
var cold_spans := Vector2.ZERO
var bars := {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
var rep := 0.0         # how much this one thinks of the player
var growth := Growth.new()  # the money the player has given them, and the level that adds up to

var zone := "district"  # which patch of the map it belongs to (see World.build_zone); only that zone ticks it, once zones are fenced
var pos := Vector2.ZERO
var heading := 0.0
var route := PackedVector2Array()  # waypoints still to walk
var route_goal := Vector2(INF, INF)
var route_nav := -1                 # the navigation version its current leg was planned under (see Walking)
var job := {}          # {for: demand class, target, item}
var stand := ""        # the uid of the machine this drone owns, or ""
var bank := ""         # the uid of the food bank this drone keeps, or ""
var cart := Inventory.new()  # a runner's shopping cart
var home := Vector2(INF, INF)  # where a runner waits between jobs
var delivered_total := 0       # units a runner has delivered
var deliveries := 0            # and in how many trips
var fees_earned := 0.0         # what its deliveries have paid in fees (the heroes' shares included)
var equity := Equity.new()     # a runner's: the heroes' shares of its cart business (of its fees: see Hauling)
var sheltered_in: Shelter = null
var arrived_at := -1.0  # when they came to live in the tent city (World.clock.time), or below zero: they were here from the start
var bed := ""          # the uid of the tent city this one has their tent in (their home in the cluster: see Lodging), or ""
var starved_ticks := 0
var speech := ""        # what they last said, and for how much longer it stays up (see Chatter)
var speech_ttl := 0.0
var speech_seq := 0     # counts up with each new line, so a view can tell
var chat_cooldown := 0.0
var event_cooldown := 0.0
var speed := 1.5       # metres a second
var face_to := Vector2(INF, INF)  # a point to face while standing still (Mr. Nobody turning to the hero)
var aloof := false     # takes no part in the town's errands: never fetches money, buys or hauls (Mr. Nobody)
var needless := false  # has no needs: bars stay full (the rich shop owner)
var care_rate := 1.0   # how fast the medical tent mends them, compared with an ordinary patient
var wake_at := -1.0    # how well they are when the tent lets them go (below zero: the tent's usual)
var aura := false      # shows a gold glow: they need the player's help (see Attention)
var care := ""       # "" fit; "down" collapsed; "carried" in the ambulance; "patient" in a hospital bed


## How much the clothes they have on keep the cold out (ItemDef.insulation, added up), at most MAX_INSULATION.
func insulation() -> float:
	var total := 0.0
	for item in gear.counts:
		total += Catalog.item(item).insulation * gear.count(item)
	return minf(total, MAX_INSULATION)


func _init(at := Vector2.ZERO, start_wallet := 0.0) -> void:
	pos = at
	wallet = start_wallet  # (World.add_drifter desyncs the bars, with the world's dice)


## The lowest of the three survival bars.
func neediest() -> float:
	return minf(bars.hunger, minf(bars.thirst, bars.warmth))


## Collapsed, being carried or in a bed: out of action until they are well again.
func make_needless() -> void:
	needless = true
	for n in NEEDS:
		bars[n] = 1.0


func unconscious() -> bool:
	return care != ""


func moving() -> bool:
	return not route.is_empty()
