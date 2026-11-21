## The shared base of the windowed screenshot tools (tools/capture_*.gd): it opens the game (the intro skipped), takes the output
## folder from the first argument, and gives the steps every capture uses. A capture extends this and writes `_run()`:
##   extends CaptureTool
##   func _run() -> void:
##       await _frames(20)
##       _stand(Vector2(0, 10), Vector2.ZERO)
##       await _shot("1_something")
##       quit()
## (Older captures still carry their own copies of these; they move onto it as they are touched.)
class_name CaptureTool
extends SceneTree

var out_dir := "/tmp/ff3d_capture"
var window := Vector2i(1300, 750)
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = window
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	_configure()
	root.add_child(game)
	_run()


## Anything to set on the game before it is built (its landing, say). Override it.
func _configure() -> void:
	pass


## What the capture does. Override it.
func _run() -> void:
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Saves the window as `<name>.png`, after `settle` real frames (things that animate into place need a second or two).
func _shot(name: String, settle := 3) -> void:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


## Puts the hero at `at`, looking at `look_at` (`eye` metres up).
func _stand(at: Vector2, look_at: Vector2, eye := 1.6) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))
