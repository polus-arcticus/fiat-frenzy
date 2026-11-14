## Sim tests: the shape of the code. Features live in features/<name>/ with their model, view and controller together;
## the model files (no _view / _controller / _rig / _model / _screen in the name) stay headless.
extends TestCase

const PRESENTATION := ["_view.gd", "_controller.gd", "_rig.gd", "_model.gd", "_screen.gd", "_body.gd", "_projectile.gd", "crosshair.gd"]
## What a model must never touch: scene nodes, input, the tree, or the view layer.
const FORBIDDEN := ["extends Node", "extends Control", "Input.", "get_tree()", "add_child(", "Camera3D", "MeshInstance3D", "StandardMaterial3D"]


func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d)))
	return out


func _is_presentation(path: String) -> bool:
	for suffix in PRESENTATION:
		if path.ends_with(suffix):
			return true
	return false


func test_models_stay_headless_wherever_they_live() -> void:
	var scanned := 0
	var offenders := []
	for dir in ["res://sim", "res://features"]:
		for path in _files(dir):
			if _is_presentation(path):
				continue
			scanned += 1
			var text := FileAccess.get_file_as_string(path)
			for bad in FORBIDDEN:
				if text.contains(bad):
					offenders.append("%s uses %s" % [path, bad])
	check(scanned > 40, "scanned the model files (%d)" % scanned)
	check(offenders.is_empty(), "no model touches nodes, input or the tree %s" % str(offenders))


func test_a_feature_folder_holds_its_whole_slice() -> void:
	for feature in ["bike", "skating", "portal", "transit", "sage", "medical", "relief", "hero", "inspector", "gun", "story"]:
		var names := DirAccess.get_files_at("res://features/%s" % feature)
		var has_view := false
		var has_model := false
		for n in names:
			has_view = has_view or (n.ends_with("_view.gd") or n.ends_with("_body.gd"))
			has_model = has_model or (n.ends_with(".gd") and not _is_presentation(n))
		check(has_model and has_view, "features/%s has a model and a view side by side" % feature)


func test_the_old_layer_folders_hold_no_feature_files() -> void:
	for stray in ["res://sim/entities/bike.gd", "res://sim/systems/riding.gd", "res://control/player/bike_controller.gd", "res://sim/systems/portals.gd", "res://sim/systems/transit.gd", "res://sim/systems/relief.gd", "res://sim/entities/food_bank.gd", "res://control/player/player_controller.gd", "res://sim/systems/gun.gd", "res://sim/entities/bill.gd", "res://control/player/gun_controller.gd", "res://control/player/aim.gd", "res://sim/systems/quests.gd", "res://sim/systems/tutorial.gd", "res://control/story/quest_controller.gd"]:
		check(not FileAccess.file_exists(stray), "%s has moved into its feature" % stray)
