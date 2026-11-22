## CONTROLLER. Fetches the new-game screen's map pictures (MapTiles) from tile.openstreetmap.org into the cache: only the ones
## the screen asks for, two at a time (the tile servers' own limit), each once, with a generic User-Agent and nothing about
## the player. A busy server is asked again with backoff (RetryingFetchController, fewer tries than a tile's map: a picture is
## only a picture), holding its place in the two meanwhile, so a struggling server sees fewer requests, not more. A picture
## that still fails isn't asked for again this run. `online` false (tests, tools) fetches nothing.
class_name MapTileFetchController
extends Node

signal arrived(z: int, x: int, y: int)

const AT_ONCE := 2
const TRIES := 4

var online := true
var dir := MapTiles.CACHE
var _queue: Array[Vector3i] = []
var _busy := {}    # Vector3i -> true, being fetched
var _failed := {}  # Vector3i -> true


## What the screen wants now, most wanted first. It replaces whatever was waiting (the view has moved on); what is being
## fetched carries on.
func want(tiles: Array[Vector3i]) -> void:
	_queue = tiles.filter(func(t): return not _busy.has(t) and not _failed.has(t) and not MapTiles.cached(t.x, t.y, t.z, dir))
	_pump()


func waiting() -> int:
	return _queue.size() + _busy.size()


func _pump() -> void:
	while online and _busy.size() < AT_ONCE and not _queue.is_empty():
		_fetch(_queue.pop_front())


func _fetch(t: Vector3i) -> void:
	_busy[t] = true
	var http := RetryingFetchController.new()
	http.tries = TRIES
	http.timeout = 20.0
	add_child(http)
	var got: Dictionary = await http.fetch(MapTiles.url(t.x, t.y, t.z), PackedStringArray(["User-Agent: " + MapTiles.AGENT]))
	http.queue_free()
	var ok: bool = got.ok and MapTiles.store(t.x, t.y, t.z, got.body, dir)
	_busy.erase(t)
	if ok:
		arrived.emit(t.x, t.y, t.z)
	else:
		_failed[t] = true
	_pump()
