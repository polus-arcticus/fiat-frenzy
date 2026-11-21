## Everything the game knows about one kind of business, in one place: what it makes, what that takes, how
## fast, what it costs to get running, and the shape it takes up on the ground. Built by Catalog.
##
## inputs: units of each per craft. rate: crafts a minute. cap: output items (10 to a slot, so the bakery's 50
## is 5 slots); for a tent, the beds each of its barrels warms (see Lodging). tick: MIN_TICK of the price rule. repair: what it costs its owner to get it running (and so what
## a stake in it costs). warm: warmth a second for a drone sheltering there (tents). flat_price: it sells at the
## item's price and never changes it (the bike shop). rich: its owner has no needs.
## trade, tier: where it stands on the ladder of its trade (filled in from Catalog.TRADES, the one place that says so).
## build: what its owner pays (sunk, like a repair) to build it up from the tier below (see Trades); 0 for a tier 0.
##
## footprint: [x, z, half-width, half-depth] boxes and [x, z, radius] circles in its own frame (x across the
## front, z back; the front is -z); a tent is "tent": [half-width, z of the open end, z of the back wall].
class_name MachineDef
extends RefCounted

var id := ""
var name := ""
var item := ""
var inputs := {}
var rate := 6.0
var cap := 10
var tick := 0.1
var repair := 40.0
var warm := 0.0
var flat_price := false
var rich := false
var trade := ""
var tier := 0
var build := 0.0
var build_scrap := 0  # or the scrap pooled into it by runners that builds it up from the tier below (and then no money: Trades)
## How many crafts' worth of each input it holds (one more per level). Six, so a van visit or a runner's trip goes further; more
## where a craft takes two goods that come on two trips (lemonade: one load of each makes a cart's worth).
var stock_crafts := 6
## Other things it makes and sells besides its `item`: ware -> its recipe (the tent city's tents and barrel fires, of scrap). Each
## sells at its flat price (ItemDef.price), on a shelf of `ware_cap`; a craft makes one, the emptiest (see Machine.craft).
var wares := {}
var ware_cap := 3
var footprint := {"boxes": [[0.0, 0.0, 1.1, 0.45]]}


func _init(machine_id: String, display_name: String, made: String) -> void:
	id = machine_id
	name = display_name
	item = made
