## Headless check of the developer's stage jumps: from a fresh game, each stage lands where it says.
##   godot --headless --path . --script tools/check_stages.gd
extends SceneTree


func _initialize() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game)


func _run(game: Node) -> void:
	for i in 20:
		await process_frame
	var w: World = game.world
	var ok := true
	for st in DevStageController.STAGES:
		var done: bool = await game.dev_stages.go(st[0])
		var q := w.quests
		print("%-8s ok=%s active=%s rode_bus=%s jam=%s rode_on=%s gate=%s shuttle=%s controls=%s seated=%s" % [st[0], done, q.active(), q.done("rode_bus"), q.done("jam_cleared"), q.done("rode_on"), q.done("cleared_gate"), q.done("rode_shuttle"), game.player.controls_enabled, game.player.is_seated()])
		ok = ok and done
	ok = ok and w.quests.done("rode_lift") and w.player.zone == Scenario.LIFT_ZONE
	print("STAGES ", "OK" if ok else "FAILED", " zone=", w.player.zone, " upgrade=", w.quests.state.get(QuestBook.UPGRADE, ""))
	quit(0 if ok else 1)
