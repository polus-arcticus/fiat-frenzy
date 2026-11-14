## Sim tests: the inspector's words. It says who someone is, what they are doing and why, and when they have no job, what
## they want and why nothing answers.
extends TestCase


func _text(w: World, d: Drone, still := 0.0) -> String:
	return "\n".join(Inspector.lines(w, d, still))


func test_it_names_the_drone_and_says_how_they_are() -> void:
	var w := World.new()
	var d := w.add_drifter(Vector2(5, 6), 42.0)
	d.label = "Banker"
	d.look = "banker"
	var s := _text(w, d)
	check(s.contains("Banker") and s.contains("looks like a banker") and s.contains("$42.00"), "name, look and wallet")
	check(s.contains("fit and free") and s.contains("JOB: none") and s.contains("ROUTE: none"), "and that they are free, with no job and no route")


func test_flags_that_stop_errands_are_named() -> void:
	var w := World.new()
	var a := w.add_drifter(Vector2(0, 0), 0.0)
	a.aloof = true
	a.needless = true
	check(_text(w, a).contains("ALOOF") and _text(w, a).contains("NEEDLESS"), "aloof and needless say so")
	var b := w.add_drifter(Vector2(3, 0), 0.0)
	w.rescue.go_down(b)
	check(_text(w, b).contains("CARE: down"), "a collapsed one says so")


func test_a_job_shows_its_target_and_the_walk() -> void:
	var w := World.new()
	var stand := w.add_vendor("hot_dog_stand", Vector2(20, 0), 50.0)
	var m := w.machine_of(stand)
	var d := w.add_drifter(Vector2(0, 0), 20.0)
	d.job = {"for": "food", "target": m, "item": m.item, "stand": Vector2(18, 0)}
	d.route = PackedVector2Array([Vector2(10, 0), Vector2(18, 0)])
	var s := _text(w, d)
	check(s.contains("JOB: food") and s.contains("18.0 m away"), "the job and how far the stand is")
	check(s.contains("ROUTE: 2 waypoints") and s.contains("last (18.0, 0.0)"), "and the route")


func test_an_idle_hungry_drone_is_told_why_nothing_answers() -> void:
	var w := World.new()
	var broken := w.add_vendor("hot_dog_stand", Vector2(20, 0), 0.0)
	w.machine_of(broken).working = false
	var d := w.add_drifter(Vector2(0, 0), 30.0)
	d.bars.hunger = 0.1
	var s := _text(w, d)
	check(s.contains("wants: food") and s.contains("0 stand(s) have it"), "wants food, and no stand has any")
	check(s.contains("nowhere"), "so the planner sends them nowhere")


func test_being_stuck_on_a_job_is_called_out() -> void:
	var w := World.new()
	var d := w.add_drifter(Vector2(0, 0), 0.0)
	d.job = {"for": "cash", "target": null, "stand": Vector2(9, 9)}
	check(not _text(w, d, 2.0).contains("NOT MOVED"), "a moment's pause is nothing")
	check(_text(w, d, 20.0).contains("NOT MOVED for 20 s while on a job"), "twenty seconds in place on a job is flagged")
