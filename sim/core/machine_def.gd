## Everything the game knows about one kind of business, in one place: what it makes, what that takes, how
## fast, what it costs to get running, and the shape it takes up on the ground. Built by Catalog.
##
## inputs: units of each per craft. rate: crafts a minute. cap: output items (10 to a slot, so the bakery's 50
## is 5 slots). tick: MIN_TICK of the price rule. repair: what it costs its owner to get it running (and so what
## a stake in it costs). warm: warmth a second for a drone sheltering there (tents). flat_price: it sells at the
## item's price and never changes it (the bike shop). rich: its owner has no needs.
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
var footprint := {"boxes": [[0.0, 0.0, 1.1, 0.45]]}


func _init(machine_id: String, display_name: String, made: String) -> void:
	id = machine_id
	name = display_name
	item = made
