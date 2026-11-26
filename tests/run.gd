## The sim test runner (the headless model: no scene, no rendering).
##   godot --headless --path . --script tests/run.gd -- [--only=<text>] [--verbose] [--update-manifest] [--shard=<i>/<n>] [--slow]
## --shard runs every n-th test starting at the i-th (tools/test.sh runs the suite as several shards at once).
##
## Runs every test_* method of every test_*.gd in tests/sim/ (the engine, npc and user spaces) and tests/story/ (the story's
## town, quests and cast), each on its own with the RNG reseeded, so any one can be run alone (--only matches "file.method",
## e.g. --only=rescue or --only=gun.invest). A passing test is one terse line with its time; a failing one shows its failed
## checks. --verbose shows every check.
##
## The slow tier: methods named test_slow_* (long simulations, and the parked machinery the game does not call yet: merge,
## dormant zones, borders) run only with --slow, and then only they do (tools/test.sh slow).
##
## tests/expected_checks.json holds how many checks each test makes. A test that dies partway (a script
## error stops a function but not the run) makes fewer, so it fails by name instead of reading as a pass.
## After adding or changing tests, run once with --update-manifest and look at the diff.
extends SceneTree

const DIRS := ["res://tests/sim/", "res://tests/story/"]
const SLOW := "test_slow_"
const MANIFEST := "res://tests/expected_checks.json"
const SEED := 7


func _init() -> void:
	var only := ""
	var verbose := false
	var update := false
	var shard := 0
	var shards := 1
	var slow := false
	for a in OS.get_cmdline_user_args():
		if a == "--slow":
			slow = true
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--verbose":
			verbose = true
		elif a == "--update-manifest":
			update = true
		elif a.begins_with("--shard="):
			var p := a.substr(8).split("/")
			shard = int(p[0])
			shards = maxi(1, int(p[1]))
	var expected := _load_manifest()
	var every := {}  # every test there is (in any shard), to tell a test that is gone from one in another shard
	var index := -1
	var counts := {}
	var failures := 0
	var ran := 0
	var total_checks := 0
	var skipped := {}  # slow tests not run this time (not "missing" from the manifest)
	var paths: Array[String] = []
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("test_") and f.ends_with(".gd"):
				paths.append(dir + f)
	paths.sort_custom(func(a: String, b: String) -> bool: return a.get_file() < b.get_file())
	for path in paths:
		var f := path.get_file()
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures += 1
			print("FAIL  %s  did not load (a script error: see above)" % f)
			continue
		var tests: Array[String] = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				tests.append(m.name)
		for t in tests:
			var id := "%s.%s" % [f.trim_prefix("test_").trim_suffix(".gd"), String(t).trim_prefix("test_")]
			every[id] = true
			index += 1
			if String(t).begins_with(SLOW) != slow:
				skipped[id] = true
				continue
			if only != "" and not id.contains(only):
				continue
			if index % shards != shard:
				continue
			seed(SEED)
			var tc: TestCase = script.new()
			var began := Time.get_ticks_msec()
			tc.call(t)
			var took := Time.get_ticks_msec() - began
			ran += 1
			total_checks += tc.checks
			counts[id] = tc.checks
			var problem := ""
			if not tc.failed.is_empty():
				problem = "%d failed" % tc.failed.size()
			elif not update and only == "" and expected.get(id, -1) != tc.checks:
				problem = "ran %d checks, expected %s" % [tc.checks, str(expected.get(id, "none: run with --update-manifest"))]
			if problem != "":
				failures += 1
			print("%s  %s  (%d checks, %d ms)%s" % ["FAIL" if problem != "" else "ok  ", id, tc.checks, took, "  " + problem if problem != "" else ""])
			if verbose or not tc.failed.is_empty():
				for line in tc.messages:
					if verbose or "[FAIL]" in line:
						print(line)
	if update and only == "" and shards == 1:
		for id in expected:  # (the tier not run this time keeps its counts)
			if skipped.has(id) and every.has(id):
				counts[id] = expected[id]
		_save_manifest(counts)
		print("manifest updated: %d tests" % counts.size())
	if only == "" and not update:
		for id in expected:
			if skipped.has(id):
				continue
			if not counts.has(id) and (shards == 1 or (shard == 0 and not every.has(id))):
				failures += 1
				print("FAIL  %s  is in the manifest but did not run" % id)
	print("\n%s (%d tests, %d checks)" % ["ALL PASSED" if failures == 0 else "%d FAILED" % failures, ran, total_checks])
	quit(failures)


func _load_manifest() -> Dictionary:
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_manifest(counts: Dictionary) -> void:
	var keys := counts.keys()
	keys.sort()
	var lines: Array[String] = []
	for k in keys:
		lines.append("\t%s: %d" % [JSON.stringify(k), counts[k]])
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
