## Does the hero stay on the hill when put somewhere? Puts them at the highest street point near the landing the two ways the
## game does it on a hill: the cot (CollapseController, the model's position for the player) and a teleport with a flat height
## (0.1, what the ring and old callers gave): after a second of physics they should be standing on the ground there, not
## under it. Prints the heights.
##   godot --path . --script tools/probe_cot.gd -- <out dir> [key=16/10482/25324]
extends CaptureTool

var key := "16/10482/25324"


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	var d := TileSource.district(key)
	game.landing = TileLanding.new(key, d, m[0], m[1], TileSource.landform(key, d))


func _run() -> void:
	await _frames(20)
	var high: Vector2 = game.landing.start
	for r in game.landing.district.roads:
		var pts := MapSites.pts(r.pts)
		for p in pts:
			if p.distance_to(game.landing.start) < 200.0 and Ground.land(p) > Ground.land(high):
				high = p
	print("highest street point near the landing: %.1f m above the landing's ground (the landing is at %.1f)" % [Ground.land(high), Ground.land(game.landing.start)])
	game.world.player.pos = high
	game.collapse._put_body_at_the_tent()
	for i in 90:
		await physics_frame
	var y: float = game.player.global_position.y
	print("cot:      hero y %.2f, ground %.2f, on floor %s  -> %s" % [y, Ground.y(high), game.player.is_on_floor(), "standing on it" if absf(y - Ground.y(high)) < 0.6 else "WRONG"])
	game.player.teleport(Vector3(high.x + 3.0, 0.1, high.y), 0.0)
	for i in 90:
		await physics_frame
	var at := Vector2(game.player.global_position.x, game.player.global_position.z)
	y = game.player.global_position.y
	print("flat y:   hero y %.2f, ground %.2f, on floor %s  -> %s" % [y, Ground.y(at), game.player.is_on_floor(), "standing on it" if absf(y - Ground.y(at)) < 0.6 else "WRONG"])
	quit()
