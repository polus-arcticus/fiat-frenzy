## What the title screen tells the game it is about to start: a saved slot to load, or "" for a new game. The game reads it
## once, in its _ready, and clears it. Tests and tools that make the game themselves never set it, so they start fresh.
class_name Launch
extends RefCounted

const MAIN := "res://main.tscn"

static var slot := ""
## A new game, with the opening crash (false: straight in, gun in hand: the --skip-intro way).
static var skip_intro := false


## Where a new game lands (Landing.spec): {} or {kind: "story"} for Frankfurt, {kind: "tile", key, lat, lon} for a tile (its map
## already in the cache: TileSource).
static var landing := {}

## The loading picture while a game is being built from here (the game counts its steps on it: GameController.STEPS); null
## otherwise, and then the game builds all at once.
static var loading: LoadingScreen


## Takes the pending landing (and forgets it).
static func take_landing() -> Dictionary:
	var l := landing
	landing = {}
	return l


## Takes the pending slot (and forgets it).
static func take_slot() -> String:
	var s := slot
	slot = ""
	return s


## Shows the loading cinematic over everything, builds the game behind it step by step, and lets the cinematic play out. The
## screen is a layer on the tree's root, so it outlives the change of scene.
## A new game lands on `new_landing` (a Landing spec; {} is the story). A tile whose map isn't in the cache is fetched first
## (TileFetchController, with backoff), under the cinematic; if that fails nothing starts, and the reason is returned ("" when
## all is well).
static func begin(tree: SceneTree, saved_slot := "", new_landing := {}) -> String:
	slot = saved_slot
	landing = new_landing
	var screen := LoadingScreen.new()
	tree.root.add_child(screen)
	if new_landing.get("kind", "story") == "tile" and not TileSource.ready(new_landing.key):
		screen.holding = true
		var fetcher := TileFetchController.new()
		fetcher.waiting.connect(func(s: float, _a: int): screen.caption = "THE MAP SERVER IS BUSY: ASKING AGAIN IN %d S..." % ceili(s))
		tree.root.add_child(fetcher)
		for layer in TileSource.BEFORE_LANDING:  # (one after another: the server is asked one thing at a time)
			screen.caption = ("FETCHING THE STREETS OF %s..." if layer == "osm" else "FETCHING THE WATER AND PARKS OF %s...") % new_landing.key
			var got: Dictionary = await fetcher.fetch(new_landing.key, TileSource.CACHE, layer)
			if not got.ok:
				fetcher.queue_free()
				screen.queue_free()
				landing = {}
				return "The map of %s couldn't be fetched: %s." % [new_landing.key, got.error]
		fetcher.queue_free()
		screen.caption = LoadingScreen.PRINTING
	screen.holding = false
	ResourceLoader.load_threaded_request(MAIN)
	var started := Time.get_ticks_msec()
	while true:  # (at least until the skater has left the ground: the picture needs its moment)
		await tree.process_frame
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(MAIN, progress)
		screen.progress = progress[0] if not progress.is_empty() else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED and Time.get_ticks_msec() - started > 2100:
			break
	screen.holding = true  # hold the best frame while the game is built, counting its steps
	loading = screen
	await tree.process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN)
	tree.change_scene_to_packed(packed)
	while tree.current_scene == null or tree.current_scene.get("is_built") != true:
		await tree.process_frame
	loading = null
	screen.release()
	return ""
