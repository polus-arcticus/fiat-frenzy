## What the title screen tells the game it is about to start: a saved slot to load, or "" for a new game. The game reads it
## once, in its _ready, and clears it. Tests and tools that make the game themselves never set it, so they start fresh.
class_name Launch
extends RefCounted

const MAIN := "res://main.tscn"

static var slot := ""
## A new game, with the opening crash (false: straight in, gun in hand: the --skip-intro way).
static var skip_intro := false


## Takes the pending slot (and forgets it).
static func take_slot() -> String:
	var s := slot
	slot = ""
	return s


## Shows the loading cinematic over everything, builds the game behind it, and lets the cinematic play out. The screen is a
## layer on the tree's root, so it outlives the change of scene.
static func begin(tree: SceneTree, saved_slot := "") -> void:
	slot = saved_slot
	var loading := LoadingScreen.new()
	tree.root.add_child(loading)
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
