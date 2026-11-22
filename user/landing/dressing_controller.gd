## CONTROLLER. A tile's dressing (its parks, pitches, woods and trees: OsmDressing, already in the district: TileSource's "land"
## layer), baked behind the game once the hero has landed: the geometry on a worker thread (DressingBuilder.bake via
## OffThread), then laid into the city. It's only looked at: the parks the sim uses (camps) are the district's, not this.
class_name DressingController
extends Node

signal dressed(node: Node3D)

var key := ""
var district := {}
var into: Node3D
var node: Node3D  # the dressing, once it is in


func setup(tile_key: String, map: Dictionary, parent: Node3D) -> DressingController:
	key = tile_key
	district = map
	into = parent
	return self


func _ready() -> void:
	_bring_in()


func _bring_in() -> void:
	var green: Dictionary = district.get("green", {})
	if green.is_empty():
		return
	var tile := key
	var baked: Dictionary = await OffThread.run(self, func(): return DressingBuilder.bake(green, tile))
	if not is_inside_tree() or into == null or not is_instance_valid(into):
		return
	node = DressingBuilder.assemble(baked)
	into.add_child(node)
	dressed.emit(node)
