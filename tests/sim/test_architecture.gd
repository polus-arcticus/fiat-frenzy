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
## none of their systems, every system that takes a turn is the engine's or the people's, and an atom runs on it. (That a town
## keeps itself going for days on an engine-only world is founders.* and tile_landing.it_keeps_itself_going.)
func test_the_engine_runs_without_the_hero_or_the_story() -> void:
	var w := World.new(false)
	for field in ["gun", "commerce", "hero", "riding", "transit", "skating", "sage", "quests", "attention"]:
		check(w.get(field) == null, "an engine-only world has no %s" % field)
	var theirs := w._end_of_tick.filter(func(s): return not (s.get_script().resource_path.begins_with("res://engine/") or s.get_script().resource_path.begins_with("res://npc/")))
	check(theirs.is_empty(), "and every system that takes a turn is the engine's or the people's (%s)" % [theirs.map(func(s): return s.get_script().resource_path)])
	Fixtures.grown_atom(w)
	w.begin_play()
	Cluster.fund(w, "atom")
	for i in 120:
		w.tick(1.0)
	check(Fixtures.sold(w, "atom") > 0 and is_equal_approx(w.total_money(), w.ledger.printed), "an atom trades on it, the money accounted for (%d sold in two minutes)" % Fixtures.sold(w, "atom"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	check(not data.systems.has("gun") and data.systems.has("trades"), "and it saves only what it has")


func test_every_script_is_in_one_of_the_four_spaces() -> void:
	check(_all().size() > 140, "the spaces hold the scripts (%d)" % _all().size())


## The three concerns, across the spaces: building the world from the map (the map's model and the city's views), the economy
## (people, machines, money and the goods between them), and the story. The world building names no part of the economy and the
## economy no part of the world building: they meet only in the composition roots and in what places things on the map (the
## landings and the tile's atom). Shared ground both may name: the road graph, footprints, tiles, navigation, walking, zones,
## the clock and names; and for views, Ground (the height of the street's surface, that every view stands its things on).
const WORLD_DIRS := ["res://engine/map/", "res://engine/view/world/"]
const ECONOMY_DIRS := ["res://engine/entities/", "res://engine/deposit/", "res://engine/salvage/", "res://engine/lodging/", "res://engine/relief/", "res://npc/agents/", "res://npc/medical/"]
const ECONOMY_CORE := ["Equity", "Catalog", "Cluster", "Atom", "Stacks", "Shelter", "Growth", "MachineDef", "ItemDef", "Inventory", "Pricing", "Wealth", "Levels", "Trades", "Heating", "Ledger", "TileSummary"]
const SHARED := ["Ground"]
## Where they still meet, to be undone (docs/review.md): each "file uses Class".
const CONCERN_DEBT := [
	"engine/map/site_finder.gd uses Cluster",  # (its street site is laid out by the atom's LAYOUT: the atom should be handed the site)
	"engine/map/site_finder.gd uses Atom",
]


func _classes_in(dirs: Array) -> Dictionary:
	var named := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var out := {}
	for path in _all():
		if dirs.any(func(d): return path.begins_with(d)):
			var m := named.search(FileAccess.get_file_as_string(path))
			if m != null:
				out[m.get_string(1)] = true
	return out


func _uses(paths: Array, classes: Dictionary) -> Array:
	var word := RegEx.create_from_string("\\b[A-Z][A-Za-z0-9]+\\b")
	var out := []
	for path in paths:
		var seen := {}
		for w in word.search_all(_code(path)):
			var cls := w.get_string()
			if classes.has(cls) and not seen.has(cls):
				seen[cls] = true
				out.append("%s uses %s" % [path.trim_prefix("res://"), cls])
	return out


func _report(found: Array, debt: Array, what: String) -> void:
	var fresh := found.filter(func(f): return not debt.has(f))
	var paid := debt.filter(func(f): return not found.has(f))
	for f in fresh:
		note("      new: " + f)
	for f in paid:
		note("      no longer: " + f + " (take it off the list)")
	check(fresh.is_empty(), "%s: nothing new (%d new, %d still owed)" % [what, fresh.size(), debt.size() - paid.size()])
	check(paid.is_empty(), "%s: the list of debts is up to date (%d paid off)" % [what, paid.size()])


func test_world_building_and_the_economy_keep_apart() -> void:
	var economy := _classes_in(ECONOMY_DIRS)
	for c in ECONOMY_CORE:
		economy[c] = true
	var world := _classes_in(WORLD_DIRS)
	for c in SHARED:
		world.erase(c)
	var in_dirs := func(dirs: Array) -> Array: return Array(_all()).filter(func(p): return dirs.any(func(d): return p.begins_with(d)))
	var found := _uses(in_dirs.call(WORLD_DIRS), economy) + _uses(in_dirs.call(ECONOMY_DIRS), world)
	_report(found, CONCERN_DEBT, "world building and the economy")


## Below the story, nothing reaches into the story's state on the world (its quests, its sage, its cast, the gold glow) by field:
## the class rule above can't see `world.quests`. The roots may.
const STORY_FIELDS_DEBT := [
	"user/control/hud_presenter.gd",  # (reads world.quests.objective(): the Objectives stack should be handed in)
]


func test_nothing_below_the_story_reads_the_storys_state() -> void:
	var field := RegEx.create_from_string("\\.(quests|sage|cast|attention)\\b")
	var found := []
	for path in _all():
		if path.begins_with("res://story/") or path in ROOTS:
			continue
		if field.search(_code(path)) != null:
			found.append(path.trim_prefix("res://"))
	_report(found, STORY_FIELDS_DEBT, "the story's state")


## Below the story, no place of the story's map by name or number: no OpenStreetMap ids, no Frankfurt names. (The new game's
## map picker may name the city it opens on.)
const STORY_NAMES := "EZB|Frankfurt|Battonn|Kaiserstra|Sonnemann|Hauptbahnhof|Paulskirche|Kaiserdom"
const STORY_LITERALS_DEBT := []


func test_nothing_below_the_story_names_the_storys_places() -> void:
	var id := RegEx.create_from_string("(?<![\\w.])\\d{7,10}(?![\\w.])")
	var place := RegEx.create_from_string(STORY_NAMES)
	var comment := RegEx.create_from_string("(?m)(^\\s*#.*$|\\s\\s#\\s.*$)")
	var found := []
	for path in _all():
		if path.begins_with("res://story/") or path == "res://user/landing/landing_screen.gd":
			continue
		var text := comment.sub(FileAccess.get_file_as_string(path), "", true)
		if id.search(text) != null:
			found.append("%s has an OSM id" % path.trim_prefix("res://"))
		if place.search(text) != null:
			found.append("%s names a story place" % path.trim_prefix("res://"))
	_report(found, STORY_LITERALS_DEBT, "the story's places")


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
