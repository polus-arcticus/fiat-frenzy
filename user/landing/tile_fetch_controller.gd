## CONTROLLER. Fetches a layer of a tile's map from the Overpass API into the cache (TileSource), unless it is there already:
## one request (asked again with backoff while the server is busy: RetryingFetchController), a generic User-Agent, nothing
## about the player. Add it to the tree, then await `fetch`.
class_name TileFetchController
extends Node

signal waiting(seconds: float, attempt: int)


## `layer` "osm" (its streets and buildings) or "land" (its water and green): TileSource. Returns {ok, error}.
func fetch(key: String, dir := TileSource.CACHE, layer := "osm") -> Dictionary:
	if TileSource.cached(key, dir, layer):
		return {"ok": true, "error": ""}
	var http := RetryingFetchController.new()
	http.timeout = TileSource.TIMEOUT + 30
	http.waiting.connect(func(s, a): waiting.emit(s, a))
	add_child(http)
	var headers := PackedStringArray(["User-Agent: " + TileSource.AGENT, "Content-Type: application/x-www-form-urlencoded"])
	var body := "data=" + TileSource.query(key, layer).uri_encode()
	var got: Dictionary = await http.fetch(TileSource.OVERPASS, headers, HTTPClient.METHOD_POST, body)
	http.queue_free()
	if not got.ok:
		return {"ok": false, "error": "the map server said no after %d tries (%s)" % [got.attempts, got.error]}
	if not TileSource.store(key, (got.body as PackedByteArray).get_string_from_utf8(), dir, layer):
		return {"ok": false, "error": "the map server's answer was not a map"}
	return {"ok": true, "error": ""}


## The tile's relief (Terrain): each Terrarium PNG it needs that is not in the cache, from Mapzen's public elevation bucket on
## AWS (https://s3.amazonaws.com/elevation-tiles-prod/terrarium/14/x/y.png: a GET with the generic User-Agent, nothing about
## the player but which patch of ground, as with the map). One to four requests, shared with every tile they cover. Returns
## {ok, error}; a game goes on without it (flat), so the caller may ignore a failure.
func fetch_relief(key: String, dir := TileSource.CACHE) -> Dictionary:
	for t in TileSource.relief_missing(key, dir):
		var http := RetryingFetchController.new()
		http.timeout = 30.0
		http.waiting.connect(func(s, a): waiting.emit(s, a))
		add_child(http)
		var headers := PackedStringArray(["User-Agent: " + TileSource.AGENT])
		var got: Dictionary = await http.fetch(Terrain.url(t), headers)
		http.queue_free()
		if not got.ok:
			return {"ok": false, "error": "the elevation server said no after %d tries (%s)" % [got.attempts, got.error]}
		if not TileSource.store_relief(t, got.body, dir):
			return {"ok": false, "error": "the elevation server's answer was not a picture"}
	return {"ok": true, "error": ""}
