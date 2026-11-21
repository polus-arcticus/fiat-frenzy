## Windowed screenshots of the barrel fires the hero lives between (see Cold): each of the street's fires down Kaiserstraße, and
## the two at the bank, from a few metres off, looking at it.
##   godot --path . --script tools/capture_fires.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var k := 0
	for f in w.fires:
		var yaw := float(game.scenario.facing.get(f, 0.0))
		var toward := Vector2(-sin(yaw), -cos(yaw))  # (facing is atan2(-toward.x, -toward.y): toward the street)
		var from: Vector2 = f.pos + toward * 7.0 + Vector2(-toward.y, toward.x) * 2.5
		_stand(from, f.pos, 1.0)
		k += 1
		await _shot("%d_fire_%s" % [k, f.zone], 40)
	quit()
