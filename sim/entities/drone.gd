## An NPC. Every NPC is a drone: it carries items between supplies and its own demands, and what it
## demands changes with Maslow's order (see Needs.demands): survival first, then its vocation.
##
## A vendor is a drone with its own machine (1:1). A keeper minds the food bank. A runner wheels a shopping
## cart of base materials from the food bank to the storefronts that are short, for a fee. A drifter has no
## machine and is just a customer, for now. Money is a number on the drone, not an item.
class_name Drone
extends RefCounted

const NEEDS := ["hunger", "thirst", "warmth"]

var id := 0
var label := ""        # a name for the HUD
var kind := "drifter"  # drifter, vendor, keeper or runner
var look := ""         # which model to wear, if not the one for its kind (e.g. "banker")
var wallet := 0.0
var carry := Inventory.new()
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
var station := -1      # index of the machine this drone owns, or -1
var depot := -1        # index of the food bank this drone keeps, or -1
var cart := Inventory.new()  # a runner's shopping cart
var home := Vector2(INF, INF)  # where a runner waits between jobs
var delivered_total := 0       # units a runner has delivered
var fees_earned := 0.0         # what its deliveries have paid it over cost
var sheltered_in: Shelter = null
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


func _init(drone_id: int, at: Vector2, start_wallet := 0.0) -> void:
	id = drone_id
	pos = at
	wallet = start_wallet
	for n in NEEDS:  # desync the crowd so they don't all go shopping at once
		bars[n] = randf_range(0.6, 1.0)


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
