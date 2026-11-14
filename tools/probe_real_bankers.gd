## Probe on the REAL game scene (not a hand-built world): plays the intro, then funds every stand and gifts the bankers, and
## reports where the three bankers are and what each is doing, every sim minute.
##   godot --headless --path . --script tools/probe_real_bankers.gd
extends SceneTree


func _initialize() -> void:
	Engine.time_scale = 4.0
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(8.5).timeout
	Engine.time_scale = 1.0
	var w: World = game.world
	var bankers: Array = w.drones.filter(func(d): return d.label == "Banker")
	print("bankers: ", bankers.size(), " zones: ", bankers.map(func(d): return d.zone), " build_zone ", w.build_zone)
	for b in bankers:
		print("  %d at %s care '%s' aloof %s needless %s sheltered %s kind %s speed %s" % [b.id, b.pos.round(), b.care, b.aloof, b.needless, b.sheltered_in != null, b.kind, b.speed])
	w.gun_owned = true
	for d in w.drones:
		if d.station >= 0:
			w.gun.invest_ex(d, 300.0)
	for k in 12:
		for b in bankers:
			w.gun.gift(b, 20.0)
	var waited := 0.0
	while waited < 900.0 and w.machines.filter(func(m): return m.kind in ["hot_dog_stand", "bakery", "lemonade_stand"] and m.working).size() < 3:
		game.advance(15.0)
		waited += 15.0
		for b in bankers:
			b.bars.hunger = maxf(b.bars.hunger, 0.9)
			b.bars.thirst = maxf(b.bars.thirst, 0.9)
	print("stands open after %.0f s: %s" % [waited, w.machines.map(func(m): return "%s:%s/%d" % [m.kind, m.working, m.output.count(m.item)])])
	for b in bankers:
		b.bars.hunger = 0.4
		b.bars.thirst = 0.3
	for step in 40:
		game.advance(15.0)
		var line := "%s |" % w.clock.text()
		for b in bankers:
			var plan: Dictionary = w.logistics.plan(b) if b.job.is_empty() else {}
			line += " %d %s h%.2f t%.2f job %s%s%s |" % [b.id, b.pos.round(), b.bars.hunger, b.bars.thirst, b.job.get("for", "-"), (" PLAN:" + str(plan.get("for"))) if not plan.is_empty() else "", (" care:" + b.care) if b.care != "" else ""]
		print(line)
	quit()
