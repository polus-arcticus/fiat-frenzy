## How the game asks OpenStreetMap's public servers again when they are busy: exponential backoff, politely. A request that
## failed for a reason worth retrying (no connection, a timeout, 408, 429 "too many requests", or a 5xx "busy") waits FIRST
## seconds, then twice that each time, up to MOST, with a little jitter so many players don't come back in step; a server's
## own Retry-After is honoured when it says longer. After TRIES it gives up. A 4xx that isn't 408 or 429 is never retried
## (asking again won't change the answer).
class_name Backoff
extends RefCounted

const FIRST := 2.0    # seconds before the first retry
const FACTOR := 2.0
const MOST := 60.0    # the longest wait
const JITTER := 0.2   # +- this share of the wait
const TRIES := 6      # attempts in all, the first included


## Whether a failed request is worth asking again: `result` is the HTTPRequest result, `code` the HTTP status (0 if none).
static func retryable(result: int, code: int) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS:
		return result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR,
			HTTPRequest.RESULT_NO_RESPONSE, HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR]
	return code == 408 or code == 429 or code >= 500


## Seconds to wait before attempt `attempt` + 1 (after `attempt` failures, from 1). `retry_after` is the server's own word
## (0 if it said nothing); `roll` is a 0..1 for the jitter.
static func delay(attempt: int, retry_after := 0.0, roll := 0.5) -> float:
	var d := minf(FIRST * pow(FACTOR, attempt - 1), MOST)
	d *= 1.0 + JITTER * (roll * 2.0 - 1.0)
	return maxf(d, minf(retry_after, MOST * 5.0))


## The Retry-After header's seconds among `headers` (0 if none, or if it is a date: then the backoff's own wait stands).
static func retry_after(headers: PackedStringArray) -> float:
	for h in headers:
		if h.to_lower().begins_with("retry-after:"):
			var v := h.substr(12).strip_edges()
			return v.to_float() if v.is_valid_float() else 0.0
	return 0.0
