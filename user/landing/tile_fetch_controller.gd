## CONTROLLER. Fetches a tile's map from the Overpass API into the cache (TileSource), unless it is there already: one request,
## a generic User-Agent, nothing about the player. Add it to the tree, then await `fetch`.
class_name TileFetchController
extends Node


## Returns {ok, error}.
func fetch(key: String, dir := TileSource.CACHE) -> Dictionary:
	if TileSource.cached(key, dir):
		return {"ok": true, "error": ""}
	var http := HTTPRequest.new()
	http.timeout = TileSource.TIMEOUT + 30
	add_child(http)
	var body := "data=" + TileSource.query(key).uri_encode()
	var headers := ["User-Agent: " + TileSource.AGENT, "Content-Type: application/x-www-form-urlencoded"]
	var err := http.request(TileSource.OVERPASS, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "could not ask for the map (%s)" % error_string(err)}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	if res[0] != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {"ok": false, "error": "the map server said no (result %s, HTTP %d)" % [res[0], code]}
	if not TileSource.store(key, (res[3] as PackedByteArray).get_string_from_utf8(), dir):
		return {"ok": false, "error": "the map server's answer was not a map"}
	return {"ok": true, "error": ""}
