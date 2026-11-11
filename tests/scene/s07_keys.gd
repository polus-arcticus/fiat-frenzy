## Scene suite section: Keys (Tab, Esc, the wheel) and investing.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	var w: World = game.world
	var baker: Drone = game.scenario.cast.bakery
	var screen: InventoryScreen = game.inventory
	# keys: Tab opens your own inventory (Q is for talking), Esc is one universal back, the wheel is the gun mode
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	var q_key := InputEventKey.new()
	q_key.physical_keycode = KEY_Q
	q_key.pressed = true
	var esc := InputEventAction.new()
	esc.action = "release"
	esc.pressed = true
	var mode_before: String = game.gun.mode
	game._unhandled_input(q_key)
	check(game.gun.mode == mode_before and not screen.visible, "Q neither changes the gun mode nor opens the bag")
	game.interaction._unhandled_input(tab)
	check(screen.visible and screen.machine == null and not screen._right.visible, "Tab opens just your own inventory: the stand's panel is hidden")
	check(not game.player.controls_enabled and game.screens.depth() == 1, "and it registers with the screen stack")
	w.player.carry.add("bread", 2)
	screen.refresh()
	var eat_slot: SlotView = null
	for c in screen._bag.get_children():
		if c.tooltip_text == "Right-click to use":
			eat_slot = c
			break
	var hungry_before: float = w.player.bars.hunger
	w.player.bars.hunger = 0.3
	eat_slot._gui_input(right_click)
	check(w.player.carry.count("bread") == 1 and is_equal_approx(w.player.bars.hunger, 0.8), "the bag works on its own: right-click eats")
	game.interaction._unhandled_input(tab)
	check(not screen.visible and game.player.controls_enabled and game.screens.depth() == 0, "Tab toggles it closed again")
	game.interaction._unhandled_input(q_key)
	game.screens._unhandled_input(esc)
	check(not screen.visible and game.player.controls_enabled and game.screens.depth() == 0, "Esc closes an open screen")
	var freed := [0]
	game.screens.mouse_freed.connect(func(): freed[0] += 1)
	check(freed[0] == 0, "and did not free the mouse")
	game.screens._unhandled_input(esc)
	check(freed[0] == 1 and not screen.visible, "with nothing open, Esc frees the mouse instead")
	w.player.carry.take("bread", 99)
	w.player.bars.hunger = hungry_before

	# invest mode
	game.gun.toggle_mode()
	var text: String = game.gun.apply(baker, 40.0)
	print("    ", text)
	check(game.gun.mode == "invest" and w.machine_of(baker).equity.stake > 0.0, "invest mode buys a stake in the baker")
	var maxed: String = game.gun.apply(baker, 1000.0)
	check(is_equal_approx(w.machine_of(baker).equity.stake, Equity.MAX_STAKE) and maxed.begins_with("invested"), "a huge investment only buys up to the 49%% cap: \"%s\"" % maxed)
	check(game.gun.apply(baker, 10.0) == "you already own the 49% maximum", "and after that the gun refuses, and says why")
	game.hud.show_target(baker, w)
	check(game.hud.card.info.text.contains("49% maximum") and game.hud.card.title.text.contains("level %d" % baker.growth.level) and baker.growth.level == 3, "the target card shows the level (the investment took the baker to level 3) and that you own the maximum")
	game.gun.apply(game.scenario.cast.hot_dog, 40.0)
	var drifter: Drone = w.drones[4]
	check(game.gun.apply(drifter, 10.0) == "nothing to invest in", "and there is nothing to invest in on a drifter")

