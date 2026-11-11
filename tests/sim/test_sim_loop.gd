## Sim tests: the loop that turns frame time into sim steps, and its named holds.
extends TestCase


func test_frames_become_fixed_steps_at_the_chosen_speed() -> void:
	var w := World.new()
	var loop := SimLoop.new(w)
	loop.speed = 1.0
	loop.update(1.0)
	check(is_equal_approx(w.clock.time, 1.0), "a second of frames at x1 is a second of sim")
	loop.speed = 4.0
	loop.update(1.0)
	check(absf(w.clock.time - 5.0) < 0.15, "at x4 it is four more (within a step)")


func test_holds_are_named_so_they_cannot_release_each_other() -> void:
	var w := World.new()
	var loop := SimLoop.new(w)
	loop.speed = 1.0
	loop.hold("intro")
	loop.hold("sage")
	loop.hold("sage", false)
	check(loop.paused(), "releasing one hold leaves the other")
	loop.update(1.0)
	check(w.clock.time == 0.0, "so the sim stays still")
	loop.hold("intro", false)
	loop.update(1.0)
	check(not loop.paused() and is_equal_approx(w.clock.time, 1.0), "and runs when the last is released")


func test_speed_cycles_and_wraps() -> void:
	var loop := SimLoop.new(World.new())
	for i in SimLoop.SPEEDS.size():
		loop.cycle_speed()
	check(loop.speed == 2.0, "after a full circle it is back where it started")
