## Loads the real game scene headlessly and drives it, one section at a time (tests/scene/s*.gd, in order, on the
## same game): the city, the gun, the screens, the bike shop, Mr. Nobody, the quest, the map, passing out.
##   godot --headless --path . --script tests/smoke_scene.gd
extends SceneTree

const SECTIONS := [
	"s01_town", "s02_gun_gift", "s03_bars", "s04_inventory", "s05_bills", "s06_invest_contract", "s07_keys",
	"s08_bike_shop", "s09_sage", "s11_quest", "s12_map", "s13_chatter", "s14_collapse", "s15_days", "s16_walking", "s17_view", "s18_skate",
]

var failures := 0
var checks := 0
## The number of checks a clean run makes; fewer means a script error stopped a test early. Raise it when
## tests are added.
const EXPECTED_CHECKS := 180


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true  # the intro has its own test (smoke_intro.gd)
	root.add_child(game)
	await process_frame
	await process_frame
	print("scene up in %d ms" % (Time.get_ticks_msec() - t0))
	check(game.get("world") != null, "the game scene loaded its controller script")
	if game.get("world") == null:
		print("\n1 FAILED: nothing else can run")
		quit(1)
		return

	for name in SECTIONS:
		print("-- %s" % name)
		var section: SceneSection = load("res://tests/scene/%s.gd" % name).new().setup(game, self, check)
		await section.run()


	if checks < EXPECTED_CHECKS:
		print("only %d of %d checks ran" % [checks, EXPECTED_CHECKS])
		failures += 1
	print("\n%s (%d checks)" % ["ALL PASSED" if failures == 0 else "%d FAILED" % failures, checks])
	quit(failures)
