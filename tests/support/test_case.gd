## Base for a sim test file. A file is a script that extends this and has `test_*` methods; tests/run.gd
## runs each one separately (reseeding the RNG first) and counts its checks.
class_name TestCase
extends RefCounted

var checks := 0
var messages: Array[String] = []  # every check's line, for --verbose
var failed: Array[String] = []    # the failing ones


func check(ok: bool, what: String) -> void:
	checks += 1
	messages.append("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failed.append(what)


## A free-form line a test wants to show under --verbose (probe output).
func note(text: String) -> void:
	messages.append("    " + text)
