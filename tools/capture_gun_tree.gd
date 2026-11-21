## Windowed screenshot of the money gun's upgrade tree (U, see GunTree), with $5 bills unlocked to show a step lit beyond the start.
##   godot --path . --script tools/capture_gun_tree.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	w.gun_tree.unlock("bill_5")
	game.gun_tree_screen.open(w)
	await _shot("1_gun_tree", 20)
	quit()
