## Rides the skateboard on a hill (Skating's grade) and prints what happens: standing on the steepest slope near the landing
## with no input (it rolls away downhill, speed and height every quarter second), pointed uphill from rest (it rolls back),
## and W held on the flat (one push of the foot, not one every half second). A side-on screenshot of the downhill roll.
## The tile's map and relief must be cached (tools/fetch_relief.gd).
##   godot --path . --script tools/capture_slope.gd -- <out dir> [key=16/10482/25324]
extends CaptureTool

var key := "16/10482/25324"
var cam: Camera3D


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	var d := TileSource.district(key)
	game.landing = TileLanding.new(key, d, m[0], m[1], TileSource.landform(key, d))


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _frames(20)
	var land := Ground.landform
	var start: Vector2 = game.landing.start
	# the steepest stretch of street within 200 m of the landing (a road, so not inside a building), and the way down it
	var best := start
	var steepest := 0.0
	var downhill := Vector2.DOWN
	for r in game.landing.district.roads:
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			var p := pts[k]
			var q := pts[k + 1]
			if p.distance_to(start) > 200.0 or p.distance_to(q) < 20.0:
				continue
			var grade := (land.height_at(q) - land.height_at(p)) / p.distance_to(q)
			if absf(grade) > steepest:
				steepest = absf(grade)
				best = p if grade < 0.0 else q  # (the top end)
				downhill = (q - p).normalized() * (1.0 if grade < 0.0 else -1.0)
	print("steepest street near the landing: grade %.2f, from %s heading %s" % [steepest, best, downhill])
	game.world.player.make_needless()
	game.world.player.gear.add("skateboard", 1)
	cam = Camera3D.new()
	game.add_child(cam)
	cam.current = true
	# 1: down it, no input
	game.player.teleport(Ground.at(best, 0.3), atan2(-downhill.x, -downhill.y))
	game.skate_controller.toggle()
	game.player.skate_bumped.connect(func(sp): print("  bumped at %.2f m/s; real velocity %s" % [sp, game.player.get_real_velocity()]))
	print("mounted %s, grade %.2f, controls %s" % [game.world.skating.mounted, game.skate_controller._grade(), game.player.controls_enabled])
	await _physics(6)
	var t0: Vector2 = game.player.ground_pos()
	for i in 24:
		await _physics(15)
		var s: Skating = game.world.skating
		print("downhill  t=%.2f  speed %5.2f m/s  moved %5.1f m  y %.2f  on floor %s  bails %d" % [(i + 1) * 0.25, s.speed, game.player.ground_pos().distance_to(t0), game.player.global_position.y, game.player.is_on_floor(), s.bails])
		if i == 8:
			_side_view(downhill)
			await _shot("1_rolling_down", 1)
	# 2: pointed up it, from rest
	game.world.skating.bailing = false
	game.world.skating.speed = 0.0
	var at: Vector2 = game.player.ground_pos()
	game.player.teleport(Ground.at(at, 0.3), atan2(downhill.x, downhill.y))
	await _physics(6)
	for i in 8:
		await _physics(15)
		print("uphill    t=%.2f  speed %5.2f m/s  (negative: rolling back)" % [(i + 1) * 0.25, game.world.skating.speed])
	# 3: W held, on the flat
	game.world.skating.speed = 0.0
	var flat := Vector2.ZERO
	var low := INF
	for dx in range(-150, 151, 10):
		for dy in range(-150, 151, 10):
			var p := start + Vector2(dx, dy)
			var g := absf(land.height_at(p + Vector2(8, 0)) - land.height_at(p)) + absf(land.height_at(p + Vector2(0, 8)) - land.height_at(p))
			if g < low:
				low = g
				flat = p
	game.player.teleport(Ground.at(flat, 0.3), 0.0)
	await _physics(6)
	var k0: int = game.world.skating.kicks
	Input.action_press("move_forward")
	await _physics(180)
	Input.action_release("move_forward")
	print("W held for 3 s on the flattest ground (grade %.2f): %d push(es) of the foot, %.1f m/s" % [low / 8.0, game.world.skating.kicks - k0, game.world.skating.speed])
	quit()


func _side_view(across: Vector2) -> void:
	var p: Vector3 = game.player.global_position
	var side := across.orthogonal() * 5.0
	cam.global_position = p + Vector3(side.x, 1.8, side.y)
	cam.look_at(p + Vector3(0, 0.9, 0))
