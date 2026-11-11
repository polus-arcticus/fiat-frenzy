## The sim test runner (the headless model: no scene, no rendering, under a second).
##   godot --headless --path . --script tests/run.gd -- [--only=<text>] [--verbose] [--update-manifest]
##
## Runs every test_* method of every tests/sim/test_*.gd, each on its own with the RNG reseeded, so any one
## can be run alone (--only matches "file.method", e.g. --only=rescue or --only=gun.invest). A passing
## test is one terse line; a failing one shows its failed checks. --verbose shows every check.
##
## tests/expected_checks.json holds how many checks each test makes. A test that dies partway (a script
## error stops a function but not the run) makes fewer, so it fails by name instead of reading as a pass.
## After adding or changing tests, run once with --update-manifest and look at the diff.
extends SceneTree

const SIM_DIR := "res://tests/sim/"
const MANIFEST := "res://tests/expected_checks.json"
const SEED := 7


func _init() -> void:
	var only := ""
	var verbose := false
	var update := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--verbose":
			verbose = true
		elif a == "--update-manifest":
			update = true
	var expected := _load_manifest()
	var counts := {}
	var failures := 0
	var ran := 0
	var total_checks := 0
	var files := DirAccess.get_files_at(SIM_DIR)
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load(SIM_DIR + f)
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
			if only != "" and not id.contains(only):
				continue
			seed(SEED)
			var tc: TestCase = script.new()
			tc.call(t)
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
			print("%s  %s  (%d checks)%s" % ["FAIL" if problem != "" else "ok  ", id, tc.checks, "  " + problem if problem != "" else ""])
			if verbose or not tc.failed.is_empty():
				for line in tc.messages:
					if verbose or "[FAIL]" in line:
						print(line)
	if update and only == "":
		_save_manifest(counts)
		print("manifest updated: %d tests" % counts.size())
	if only == "" and not update:
		for id in expected:
			if not counts.has(id):
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
