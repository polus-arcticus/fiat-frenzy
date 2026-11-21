## Where saves live: one JSON file per slot in `user://saves/` (on Linux ~/.local/share/godot/app_userdata/Fiat Frenzy/saves).
## A file is {"version", "saved_at", "summary", "hero": {...where they stand...}, "world": Snapshot.capture()}, so the load
## screen can list saves without reading the whole world. Writes go to a temporary file that is then renamed over the old
## one (with the old one kept as `.bak`), so a crash mid-save never costs the player their game. Steam Cloud needs no code:
## its Auto-Cloud setting just points at this folder.
class_name SaveStore
extends RefCounted

const DIR := "user://saves"
const AUTOSAVE := "autosave"
const FORMAT := 2  # 2: everything named by uid (older saves are not read)
## Checkpoints the game writes by itself the first time the story reaches them (see GameController), in the order of the story.
## Each can be loaded again from the pause menu and the title's Load Game, to try a part of the game again.
const CHAPTERS := {
	"chapter-letter": "Chapter 1: A letter for the bank",
	"chapter-bank": "Chapter 2: The bank's gate",
}


## The path of a slot's file.
static func path(slot: String, dir := DIR) -> String:
	return dir.path_join(slot + ".json")


## Writes a save. `hero` is whatever the controller needs to put the player back (position, which way they face).
## `landing` is what the game began from (Landing.spec): a load builds that again before laying the save over it.
static func write(slot: String, world: World, hero: Dictionary, dir := DIR, landing := {"kind": "story"}) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var doc := {
		"format": FORMAT,
		"saved_at": Time.get_unix_time_from_system(),
		"summary": summary(world),
		"landing": landing,
		"hero": hero,
		"world": Snapshot.new(world).capture(),
	}
	var final := path(slot, dir)
	var tmp := final + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	if FileAccess.file_exists(final):
		DirAccess.rename_absolute(final, final + ".bak")
	return DirAccess.rename_absolute(tmp, final) == OK


## The whole document, or {} if the slot is missing or damaged (the backup is tried before giving up).
static func read(slot: String, dir := DIR) -> Dictionary:
	for candidate in [path(slot, dir), path(slot, dir) + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and parsed.has("world") and int(parsed.get("format", 0)) == FORMAT:
			return parsed
	return {}


## The slots that can be loaded, newest first: [{slot, saved_at, summary}].
static func list(dir := DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			var slot := f.trim_suffix(".json")
			var doc := read(slot, dir)
			if not doc.is_empty():
				out.append({"slot": slot, "saved_at": float(doc.saved_at), "summary": doc.summary})
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out


static func delete(slot: String, dir := DIR) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path(slot, dir) + suffix):
			DirAccess.remove_absolute(path(slot, dir) + suffix)


## One line for the load screen: how far the game is.
static func summary(world: World) -> Dictionary:
	return {
		"day": world.clock.day() + 1,
		"cash": snappedf(world.ledger.player_cash, 0.01),
		"stake_income": snappedf(world.ledger.stake_income, 0.01),
	}
