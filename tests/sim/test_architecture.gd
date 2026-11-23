## Sim tests: the shape of the code. It is in four spaces, each a top folder holding its features (docs/review.md):
##   engine/  the simulation             (uses nothing above it)
##   npc/     what agents decide and do   (uses engine)
##   user/    the hero and the screens    (uses engine, npc)
##   story/   quests and the scripted cast (uses anything)
## Presentation lives in a space's view/ or control/ folders, or in a file named for it (_view, _controller, ...); everything
## else is model, and stays headless and rolls only the world's dice.
extends TestCase

const SPACES := ["engine", "npc", "user", "story"]  # in order: each may use the ones before it
## The composition roots, which wire every space together: the world (every space's systems into one model) and the game
## controller (the app: the hero's controls and screens, and the story's controllers and views). The only files allowed to name
## them all.
const ROOTS := ["res://engine/world.gd", "res://user/control/game_controller.gd"]
const PRESENTATION := ["_view.gd", "_controller.gd", "_rig.gd", "_model.gd", "_screen.gd", "_body.gd", "_projectile.gd", "crosshair.gd"]
const PRESENTATION_DIRS := ["/view/", "/control/"]
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
	for dir in PRESENTATION_DIRS:
		if path.contains(dir):
			return true
	return false


## Every script in the four spaces.
func _all() -> PackedStringArray:
	var out := PackedStringArray()
	for space in SPACES:
		out.append_array(_files("res://" + space))
	return out


## A script's code with its strings and comments taken out (so a name in a comment or a string is not a use of it).
func _code(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	text = RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"").sub(text, "\"\"", true)
	return RegEx.create_from_string("#[^\\n]*").sub(text, "", true)


func test_models_stay_headless_wherever_they_live() -> void:
	var scanned := 0
	var offenders := []
	for path in _all():
		if _is_presentation(path):
			continue
		scanned += 1
		var text := FileAccess.get_file_as_string(path)
		for bad in FORBIDDEN:
			if text.contains(bad):
				offenders.append("%s uses %s" % [path, bad])
	check(scanned > 40, "scanned the model files (%d)" % scanned)
	check(offenders.is_empty(), "no model touches nodes, input or the tree %s" % str(offenders))


func test_the_model_rolls_only_its_own_dice() -> void:
	var bare := RegEx.create_from_string("(?<![\\w.])(randf|randi|randf_range|randi_range)\\(|\\.shuffle\\(\\)")
	var offenders := []
	for path in _all():
		if _is_presentation(path):
			continue
		var m := bare.search(FileAccess.get_file_as_string(path))
		if m != null:
			offenders.append("%s: %s" % [path, m.get_string()])
	check(offenders.is_empty(), "no model calls the global dice; it uses World.rng (or World.random() while seeding) %s" % str(offenders))


func test_a_tile_seeds_the_same_way_whatever_was_built_before_it() -> void:
	var one := World.new()
	one.build_zone = "16/34312/22237"
	var a := one.add_drifter(Vector2.ZERO, 5.0)
	var two := World.new()
	two.build_zone = "elsewhere"
	two.add_drifter(Vector2.ZERO, 5.0)
	two.build_zone = "16/34312/22237"
	var b := two.add_drifter(Vector2.ZERO, 5.0)
	check(a.uid == b.uid and a.uid == "16/34312/22237#0", "the first drifter of a tile has the same name in both worlds (%s)" % a.uid)
	check(a.bars == b.bars and a.heading == b.heading, "and rolled the same bars and heading")
	one.begin_play()
	var c := one.add_drifter(Vector2.ZERO)
	check(c.uid.begins_with(one.author + "/"), "after building, newcomers are named after the save's author (%s)" % c.uid)


## The engine on its own (World.new(false)): what a headless run on a map of anywhere needs, with no hero and no story. It has
## none of their systems, every system that takes a turn is the engine's or the people's, and the standard cluster runs on it.
func test_the_engine_runs_without_the_hero_or_the_story() -> void:
	var w := World.new(false)
	for field in ["gun", "commerce", "hero", "riding", "transit", "skating", "sage", "quests", "attention"]:
		check(w.get(field) == null, "an engine-only world has no %s" % field)
	var theirs := w._end_of_tick.filter(func(s): return not (s.get_script().resource_path.begins_with("res://engine/") or s.get_script().resource_path.begins_with("res://npc/")))
	check(theirs.is_empty(), "and every system that takes a turn is the engine's or the people's (%s)" % [theirs.map(func(s): return s.get_script().resource_path)])
	Cluster.found(w, "block", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "block")
	for i in int(Clock.DAY_SECONDS) * 2:
		w.tick(1.0)
	check(Fixtures.sold(w, "block") > 100 and not w.events.any(func(e): return "collapsed" in e), "the standard cluster runs two days on it, trading, nobody collapsing (%d sold)" % Fixtures.sold(w, "block"))
	check(is_equal_approx(w.total_money(), w.ledger.printed), "with the money accounted for")
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	check(not data.systems.has("gun") and data.systems.has("trades"), "and it saves only what it has")


func test_every_script_is_in_one_of_the_four_spaces() -> void:
	for old in ["res://sim", "res://features", "res://control", "res://view"]:
		check(not DirAccess.dir_exists_absolute(old), "%s is gone: its scripts are in engine/, npc/, user/ or story/" % old)
	check(_all().size() > 140, "and the spaces hold the scripts (%d)" % _all().size())


## The rule of the spaces: a script names no class from a space after its own (story may name anything). The composition root
## is the one exception. A planted upward reference makes this fail (see docs/review.md).
func test_no_space_reaches_up() -> void:
	var space_of := {}  # class name -> the index of its space
	var word := RegEx.create_from_string("\\b[A-Z][A-Za-z0-9]+\\b")
	var named := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in _all():
		var m := named.search(FileAccess.get_file_as_string(path))
		if m != null:
			space_of[m.get_string(1)] = SPACES.find(path.trim_prefix("res://").get_slice("/", 0))
	var offenders := []
	for path in _all():
		if path in ROOTS:
			continue
		var mine := SPACES.find(path.trim_prefix("res://").get_slice("/", 0))
		var seen := {}
		for w in word.search_all(_code(path)):
			var cls := w.get_string()
			if space_of.has(cls) and space_of[cls] > mine and not seen.has(cls):
				seen[cls] = true
				offenders.append("%s uses %s (%s)" % [path.trim_prefix("res://"), cls, SPACES[space_of[cls]]])
	note("    %d upward references" % offenders.size())
	for o in offenders:
		note("      " + o)
	check(offenders.is_empty(), "no script reaches up into a later space (%d do)" % offenders.size())


func test_the_end_of_tick_systems_each_take_their_turn_in_order() -> void:
	var w := World.new()
	check(w._end_of_tick.size() == 10, "ten systems take a turn after the drones (%d: the deposit has no turn of its own, it pays when bottles are handed in)" % w._end_of_tick.size())
	check(w._end_of_tick.all(func(s): return s.has_method("step")), "each one has a step")
	check(w._end_of_tick[0] is Hero and w._end_of_tick[1] is Transit and w._end_of_tick[w._end_of_tick.size() - 1] is Attention, "the hero first (their needs, where they are), then the bus; the gold glow last")
	w.add_player(Vector2(5, 5), 10.0)
	w.tick(1.0)
	check(w.clock.time > 0.0, "and a tick still runs them all without a fault")
