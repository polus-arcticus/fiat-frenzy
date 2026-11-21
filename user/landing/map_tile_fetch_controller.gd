## CONTROLLER. Fetches the new-game screen's map pictures (MapTiles) from tile.openstreetmap.org into the cache: only the ones
## the screen asks for, two at a time (the tile servers' own limit), each once (a failure isn't asked again this run), with a
## generic User-Agent and nothing about the player. `online` false (tests, tools) fetches nothing.
class_name MapTileFetchController
extends Node

signal arrived(z: int, x: int, y: int)

const AT_ONCE := 2

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
	var http := HTTPRequest.new()
	http.timeout = 20
	add_child(http)
	var ok := false
	if http.request(MapTiles.url(t.x, t.y, t.z), ["User-Agent: " + MapTiles.AGENT]) == OK:
		var res: Array = await http.request_completed
		ok = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200 and MapTiles.store(t.x, t.y, t.z, res[3], dir)
	http.queue_free()
	_busy.erase(t)
	if ok:
		arrived.emit(t.x, t.y, t.z)
	else:
		_failed[t] = true
	_pump()
