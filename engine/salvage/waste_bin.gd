## The town's base inputs, salvaged from its bins: what it throws away is what it runs on. Three bins, as a German street has
## them, and a fountain:
##   garbage    scrap         (as the scrap piles always were: bike frames, sheet metal: tents, camps, coats are made of it)
##   recycling  recyclables   (bottles: worth a deposit at the bottle depot, the town's one source of new money)
##   organics   leftovers     (the food stalls' one input: bread, hot dogs, lemonade are made of it)
##   fountain   water         (the lemonade stand's: runners fill up; nobody drinks from it)
## Each gathers its item slowly (`rate` a minute, up to `cap`), costs nothing, and the cart runners salvage it and pool it into
## whatever wants it (Hauling). The recycling fills with what the people round it drink: its rate is a head's, times the zone's
## residents (`heads`). Every kind's numbers are in KINDS, the one place they are set.
class_name WasteBin
extends RefCounted

## kind -> {item, rate (a minute; a resident's, `per_head`), cap, start}. A tile's bins of one kind share its rate
## (SiteFinder.bins), so a town has as much of each as an atom's one bin would give.
const KINDS := {
	"garbage": {"item": "scrap", "rate": 1.0, "cap": 30, "start": 10},
	# (the town's income: what its residents spend at the stalls comes back through the depot as deposits, about $7 a resident
	# a day, so about 7 bottles each at Deposit.DEPOSIT. A fixed trickle didn't do: too little left an atom's fund full and its
	# people broke, and what kept an atom going left a block of 13 collapsing daily, its fund piling up. Cut further, people
	# starve however hard they collect: at 60% of this rate an atom had 148 collapses in 60 days. It opens with enough for
	# everyone short at the start: a broke medic lost the first day's race for 15.)
	"recycling": {"item": "recyclables", "rate": 0.83, "per_head": true, "cap": 50, "start": 30},
	# (as much as the food bank gave of what leftovers stand for, flour 3.6 + sugar 3.0 + protein 0.8, and of bottled water)
	"organics": {"item": "leftovers", "rate": 7.4, "cap": 60, "start": 20},
	"fountain": {"item": "water", "rate": 3.0, "cap": 30, "start": 10},
}

var uid := ""  # see World.mint
var zone := "district"
var kind := "garbage"
var item := "scrap"
var pos := Vector2.ZERO
var front := Vector2(0, 1)  # (where a runner stands to gather from it: see Logistics.stand_point)
var output := Inventory.new()
var rate := 1.0    # its item a minute here, or a resident's (KINDS per_head) (a tile's bins of a kind share the one bin's)
var source := ""   # where it is on the map: "map" (a real bin there) or "" (laid out by the atom, the map has none near)
var _progress := 0.0


func _init(bin_kind := "garbage", at := Vector2.ZERO, start := -1) -> void:
	kind = bin_kind
	var k: Dictionary = KINDS[kind]
	item = k.item
	rate = k.rate
	pos = at
	output.caps[item] = k.cap
	output.add(item, k.start if start < 0 else start)
	refresh()


## Does it fill with what the people round it throw away (its rate a resident's)?
func per_head() -> bool:
	return KINDS[kind].get("per_head", false)


## Its item a minute just now, with `heads` residents round it.
func per_minute(heads := 1) -> float:
	return rate * (heads if per_head() else 1)


func offers(what: String) -> bool:
	return what == item and output.count(item) >= 1


func price_of(_what: String) -> float:
	return 0.0  # (it is free: the runner's fee is what the salvaging is paid)


func refresh() -> void:
	output.offer = {item: output.count(item)}


## `heads`: the zone's residents (Zones.heads_in), for a kind that fills with what they throw away.
func step(dt: float, heads := 1) -> void:
	_progress += rate * (heads if per_head() else 1) * dt / 60.0
	while _progress >= 1.0:
		_progress -= 1.0
		output.add(item, 1)
	refresh()
