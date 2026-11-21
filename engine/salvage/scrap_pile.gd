## Scrap lying in the street: bike frames, wheels, sheet metal. It gathers slowly where the town's scrap ends up (RATE a minute,
## up to CAP: a placeholder for how scrap appears, which is to be designed), costs nothing, and the cart runners gather it and
## pool it into whatever wants scrap (a homeless camp's input, a tent city being built up: see Hauling).
class_name ScrapPile
extends RefCounted

const RATE := 1.0  # scrap a minute
const CAP := 30

var uid := ""  # see World.mint
var zone := "district"
var pos := Vector2.ZERO
var front := Vector2(0, 1)  # (where a runner stands to gather from it: see Logistics.stand_point)
var output := Inventory.new()
var _progress := 0.0


func _init(at := Vector2.ZERO, start := 10) -> void:
	pos = at
	output.caps["scrap"] = CAP
	output.add("scrap", start)
	refresh()


func offers(item: String) -> bool:
	return item == "scrap" and output.count("scrap") >= 1


func price_of(_item: String) -> float:
	return 0.0  # (it is free: the runner's fee is what the gathering is paid)


func refresh() -> void:
	output.offer = {"scrap": output.count("scrap")}


func step(dt: float) -> void:
	_progress += RATE * dt / 60.0
	while _progress >= 1.0:
		_progress -= 1.0
		output.add("scrap", 1)
	refresh()
