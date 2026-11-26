## A tent city's homes (`Machine.residence`, null on any other machine): a row of tents side by side, one person to each, kept
## warm by their barrels (its Shelter), how many tents there are (so how many people the cluster holds: see Lodging), and the
## side the row grows on. The machine it belongs to still crafts and sells (the keeper's tents and barrel fires); this is what
## makes it a home. Saved and merged with its machine, by its own MERGE table.
class_name Residence
extends RefCounted

const MERGE := {"tents": "max", "founded": "max"}
const TENT_WIDTH := 2.0  # the tents stand side by side, each this wide

var shelter: Shelter
var tents := 0       # one person to each (at most its tier's `cap`, or `tents_cap`)
var tents_cap := 0   # more room than its tier gives, if a scenario laid it out bigger (0: just the tier's)
var founded := 0     # how many founders this city has brought (Lodging.FOUNDERS: the first arrivals make the town, not just mouths)
## Where each founder sets up, by role: {role: {at, front}} (an atom lays them out on its street: Atom.seed). A role with no place
## here goes beside the city along its own street, on the side the row does not grow, a step further for each (FOUNDER_STEP).
var slots := {}
const FOUNDER_STEP := 4.0
var wing := 1.0      # the side the row goes on, along its machine's own x (+1 or -1: down the street, away from the market)


func _init(cap := 1, warm := 0.0, at := Vector2.ZERO) -> void:
	shelter = Shelter.new(cap, warm, at)
	shelter.berth_radius = 0.45  # a tent holds its sleepers inside its walls


## The middle of the `index`th tent in the row of `home` (its machine), where its person sleeps: the tents side by side down
## `wing`. (Well clear of the walls: Navigation holds a margin round every wall, and someone who woke in it couldn't get out.)
func bed_pos(home: Premises, index: int) -> Vector2:
	return home.pos + Vector2(-home.front.y, home.front.x) * index * TENT_WIDTH * wing - home.front * 0.3


## The ground the whole row takes up: one long tent, open along the front (its kind's tent shape, stretched).
func footprint(home: Premises) -> Footprint:
	var shape: Array = Catalog.footprint_of(home.kind).tent
	var k := maxi(1, tents)
	var centre := home.pos + Vector2(-home.front.y, home.front.x) * wing * (k - 1) * TENT_WIDTH * 0.5
	var f := Footprint.new(centre, home.front)
	f.tent(float(shape[0]) + (k - 1) * TENT_WIDTH * 0.5, shape[1], shape[2])
	return f
