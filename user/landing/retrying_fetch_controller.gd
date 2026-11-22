## CONTROLLER. One HTTP request, asked again with exponential backoff while the server is busy (Backoff). Every request the
## game makes to OpenStreetMap goes through one of these: a tile's map (TileFetchController) and the new-game screen's map
## pictures (MapTileFetchController). Add it to the tree, then await `fetch`.
class_name RetryingFetchController
extends Node

## About to wait `seconds` before attempt `attempt` (a screen may say so).
signal waiting(seconds: float, attempt: int)

var tries := Backoff.TRIES
var timeout := 30.0


## Returns {ok, code, body (PackedByteArray), error, attempts}.
func fetch(url: String, headers: PackedStringArray, method := HTTPClient.METHOD_GET, body := "") -> Dictionary:
	var last := {"ok": false, "code": 0, "body": PackedByteArray(), "error": "", "attempts": 0}
	for attempt in range(1, tries + 1):
		last.attempts = attempt
		var http := HTTPRequest.new()
		http.timeout = timeout
		add_child(http)
		var err := http.request(url, headers, method, body)
		if err != OK:
			http.queue_free()
			last.error = "could not ask (%s)" % error_string(err)
			return last
		var res: Array = await http.request_completed
		http.queue_free()
		var result: int = res[0]
		last.code = res[1]
		last.body = res[3]
		if result == HTTPRequest.RESULT_SUCCESS and last.code == 200:
			last.ok = true
			last.error = ""
			return last
		last.error = "result %d, HTTP %d" % [result, last.code]
		if attempt == tries or not Backoff.retryable(result, last.code):
			return last
		var wait := Backoff.delay(attempt, Backoff.retry_after(res[2]), randf())
		waiting.emit(wait, attempt + 1)
		await get_tree().create_timer(wait, true, false, true).timeout
	return last
