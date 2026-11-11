## Scene suite section: Passing out, the ambulance, waking up.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var screen: InventoryScreen = game.inventory
	# passing out: the hero blacks out, an ambulance takes them to the tent, they wake with control back
	game.collapse.instant = true
	var hospital: Hospital = w.hospitals[0]
	var gun_was_on: bool = game.gun.enabled
	var shade: ColorRect = game.collapse._shade
	check(w.hospitals.size() == 1 and w.ambulances.size() == 1 and hospital.pos.distance_to(game.scenario.start) < 70.0, "there is a medical tent and an ambulance near the market")
	w.player.bars.hunger = 0.0
	game.advance(1.0)
	check(w.player.care != "" and not game.player.controls_enabled and not game.gun.enabled, "when a bar runs out the hero collapses: controls and the gun stop")
	check(shade.modulate.a > 0.9, "and the screen goes black (%.2f)" % shade.modulate.a)
	var in_bed := false
	for i in 400:
		game.advance(1.0)
		in_bed = in_bed or w.player.care == "patient"
		if in_bed and w.player.care == "":
			break
	check(in_bed, "the ambulance brought them to a bed")
	check(w.player.care == "" and game.player.controls_enabled and game.gun.enabled == gun_was_on, "they wake up with their controls and gun back")
	check(game.player.ground_pos().distance_to(hospital.pos) < 8.0 and game.player.ground_pos().distance_to(w.player.pos) < 1.0, "their body is by the medical tent (%.1f m)" % game.player.ground_pos().distance_to(hospital.pos))
	check(shade.modulate.a < 0.1, "and the screen is clear again")

