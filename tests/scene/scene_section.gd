## Base class for one section of the scene suite. `run()` is a coroutine: it may await frames. Sections run in order
## on one shared game (the economy and the hero's position carry over), so each starts from where the last ended.
class_name SceneSection
extends RefCounted

var game: Node
var tree: SceneTree
var _report: Callable


func setup(g: Node, t: SceneTree, report: Callable) -> SceneSection:
	game = g
	tree = t
	_report = report
	return self


func check(ok: bool, what: String) -> void:
	_report.call(ok, what)


func run() -> void:
	pass
