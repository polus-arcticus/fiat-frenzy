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


## Shows the loading cinematic over everything, builds the game behind it, and lets the cinematic play out. The screen is a
## layer on the tree's root, so it outlives the change of scene.
## A new game lands on `new_landing` (a Landing spec; {} is the story). A tile whose map isn't in the cache is fetched first
## (TileFetchController), under the cinematic; if that fails nothing starts, and the reason is returned ("" when all is well).
static func begin(tree: SceneTree, saved_slot := "", new_landing := {}) -> String:
	slot = saved_slot
	landing = new_landing
	var loading := LoadingScreen.new()
	tree.root.add_child(loading)
	if new_landing.get("kind", "story") == "tile" and not TileSource.cached(new_landing.key):
		loading.holding = true
		loading.caption = "FETCHING THE MAP OF %s..." % new_landing.key
		var fetcher := TileFetchController.new()
		tree.root.add_child(fetcher)
		var got: Dictionary = await fetcher.fetch(new_landing.key)
		fetcher.queue_free()
		if not got.ok:
			loading.queue_free()
			landing = {}
			return "The map of %s couldn't be fetched: %s." % [new_landing.key, got.error]
		loading.caption = LoadingScreen.PRINTING
	loading.holding = false
	ResourceLoader.load_threaded_request(MAIN)
	var started := Time.get_ticks_msec()
	while true:  # (at least until the skater has left the ground: the picture needs its moment)
		await tree.process_frame
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(MAIN, progress)
		loading.progress = progress[0] if not progress.is_empty() else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED and Time.get_ticks_msec() - started > 2100:
			break
	loading.holding = true  # freeze on the best frame: the build below blocks
	await tree.process_frame
	await tree.process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN)
	tree.change_scene_to_packed(packed)
	await tree.process_frame
	await tree.process_frame
	loading.release()
	return ""
