## Sim tests: the teleporter rings.
extends TestCase


func _pair() -> Array:
	var w := World.new()
	var ring := w.portals.add_pair(Portal.new(Vector2(0, 0), Vector2(0, 1), "a"), Portal.new(Vector2(100, 50), Vector2(1, 0), "b"))
	return [w, ring[0], ring[1]]


func test_standing_in_a_ring_is_being_in_its_doorway() -> void:
	var s := _pair()
	var w: World = s[0]
	check(w.portals.at(Vector2(0, 0)) == s[1], "in the middle of the first ring")
	check(w.portals.at(Vector2(0.9, 0.3)) == s[1], "and anywhere in the opening")
	check(w.portals.at(Vector2(2.0, 0)) == null, "beside it is not through it")
	check(w.portals.at(Vector2(0, 1.5)) == null, "nor is in front of it")
	check(w.portals.at(Vector2(100, 50)) == s[2], "the twin is a doorway too")


func test_each_ring_leads_to_the_other_and_comes_out_clear() -> void:
	var s := _pair()
	var a: Portal = s[1]
	var b: Portal = s[2]
	check(a.twin == b and b.twin == a, "the pair lead to each other")
	var out := a.twin.exit_point()
	check(out.is_equal_approx(Vector2(102.5, 50)), "you come out in front of the twin, on its facing side")
	check((s[0] as World).portals.at(out) == null, "and clear of it, so you do not go straight back")
	check(is_equal_approx(b.exit_yaw(), atan2(-1.0, 0.0)), "facing away from it")


func test_a_fast_bike_cannot_skip_the_doorway() -> void:
	var s := _pair()
	var w: World = s[0]
	var caught := false
	for k in range(-20, 21):
		var p := Vector2(0, float(k) * 0.18)  # 10.8 m/s at 60 frames a second
		if w.portals.at(p) != null:
			caught = true
	check(caught, "a step of 18 cm lands inside a doorway 1.2 m deep")
