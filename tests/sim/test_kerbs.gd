## Sim tests: the kerbs (Kerbs: raised pavements made from the map's streets, cut where streets cross) and grinding them on a
## skateboard (Skating): catching a kerb line coming down from an ollie, sliding along it, the $1 a GRIND_EVERY metres it
## drops, and how it ends.
extends TestCase


# Two streets crossing at the origin (east-west and north-south, 8 m wide, 4 m of pavement each side), a pedestrian street
# off to the east, and a shop with its door cut (hollow) whose wall comes over the pavement.
func _district() -> Dictionary:
	return {"buildings": [{"id": 7, "poly": [20.0, -12.0, 30.0, -12.0, 30.0, -5.0, 20.0, -5.0]}],
		"roads": [
			{"class": "residential", "w": 8.0, "pave": [8.0, 8.0], "pts": [-60.0, 0.0, 60.0, 0.0]},
			{"class": "residential", "w": 8.0, "pave": [8.0, 8.0], "pts": [0.0, -60.0, 0.0, 60.0]},
			{"class": "pedestrian", "w": 10.0, "pts": [100.0, 0.0, 160.0, 0.0]},
		]}


func test_pavements_are_raised_and_roads_are_not() -> void:
	var k := Kerbs.of(_district())
	check(k.height_at(Vector2(-30, 6)) == Kerbs.HEIGHT and k.height_at(Vector2(-30, -6)) == Kerbs.HEIGHT, "both pavements are up a kerb")
	check(k.height_at(Vector2(-30, 0)) == 0.0 and k.height_at(Vector2(-30, 3.9)) == 0.0, "the carriageway is not")
	check(k.height_at(Vector2(130, 2)) == 0.0, "a pedestrian street is level paving")
	check(k.height_at(Vector2(-30, 40)) == 0.0, "nor is open ground away from the streets")


func test_a_junction_has_no_kerb_across_it() -> void:
	var k := Kerbs.of(_district())
	check(k.height_at(Vector2(0, 0)) == 0.0 and k.height_at(Vector2(0, 6)) == 0.0 and k.height_at(Vector2(6, 0)) == 0.0,
		"where the streets cross, each one's road cuts the other's pavement")
	check(k.height_at(Vector2(6, 6)) == Kerbs.HEIGHT, "the corner between them is still pavement")
	var across := k.edges.filter(func(e): return Geometry2D.get_closest_point_to_segment(Vector2(0, 4), e.a, e.b).distance_to(Vector2(0, 4)) < 0.5)
	check(across.is_empty(), "no kerb line runs across the junction")
	var west := k.edges.filter(func(e): return absf(e.a.y - 4.0) < 0.01 and absf(e.b.y - 4.0) < 0.01 and minf(e.a.x, e.b.x) < -30.0)
	check(west.size() == 1 and maxf(west[0].a.x, west[0].b.x) <= -3.9, "a street's kerb line stops where the other street begins")
	check(is_equal_approx((west[0].side as Vector2).y, 1.0), "and knows which side its pavement is on")


func test_a_shop_floor_stays_level() -> void:
	var open := Kerbs.of(_district())
	var hollow := Kerbs.of(_district(), {7: true})
	check(open.height_at(Vector2(25, -6)) == Kerbs.HEIGHT and hollow.height_at(Vector2(25, -6)) == 0.0,
		"the pavement stops at the wall of a building with a door, so its floor isn't raised inside")


# ---------------------------------------------------------------- grinding

func _rider() -> World:
	var w := World.new()
	w.add_player(Vector2(-40, 3.7), 100.0)
	w.player.gear.add("skateboard", 1)
	w.skating.kerbs = Kerbs.of(_district())
	w.skating.mount()
	w.skating.speed = 8.0
	w.skating.in_air = true
	return w


# Coming down over the south kerb of the east-west street (its line at y 4), going east.
func _coming_down(height := 0.4, heading := Vector2.RIGHT) -> Dictionary:
	return {"height": height, "heading": heading, "falling": true}


func test_coming_down_along_a_kerb_catches_it() -> void:
	var w := _rider()
	var out := w.skating.step(0.016, _coming_down(), false, Vector2(-40, 3.7))
	check(out.grind and w.skating.grinding and w.skating.grinds == 1, "the board locks onto the kerb")
	check(absf((out.grind_at as Vector2).y - 4.0) < 0.01 and (out.grind_heading as Vector2).is_equal_approx(Vector2.RIGHT), "on its line, going the way you were")
	var across := _rider()
	check(not across.skating.step(0.016, _coming_down(0.4, Vector2.DOWN), false, Vector2(-40, 3.7)).grind, "not going across it")
	var high := _rider()
	check(not high.skating.step(0.016, _coming_down(2.0), false, Vector2(-40, 3.7)).grind, "not from high above it")
	var far := _rider()
	check(not far.skating.step(0.016, _coming_down(), false, Vector2(-40, 2.0)).grind, "not two metres off it")
	var slow := _rider()
	slow.skating.speed = 1.0
	check(not slow.skating.step(0.016, _coming_down(), false, Vector2(-40, 3.7)).grind, "not crawling")


func test_a_grind_drops_a_dollar_every_two_metres_and_ends_where_the_kerb_does() -> void:
	var w := _rider()
	w.skating.speed = Skating.TOP_SPEED
	var printed := w.ledger.printed
	var total := w.ledger.total(w.drones, w.bills)
	w.skating.step(0.016, _coming_down(), false, Vector2(-24, 3.7))
	var steps := 0
	var out := {"grind": true}
	var pocketed := 0.0
	while out.grind and steps < 2000:
		out = w.skating.step(0.016, {}, false, Vector2.ZERO)
		if out.has("grind_at"):
			w.player.pos = out.grind_at  # (the hero rides along: what's dropped is never under them)
			pocketed += w.commerce.pick_up_cash()
		steps += 1
	check(pocketed == 0.0, "the bills are a trail behind, out of reach as they land (pocketed $%d)" % int(pocketed))
	var metres := w.skating.grind_metres
	check(not w.skating.grinding and w.skating.in_air and out.get("ended", false), "it ends by itself, back in the air")
	check(metres > 19.0 and metres < 20.5, "where the kerb line stops, at the junction (%.1f m from x -24 to -4)" % metres)
	check(is_equal_approx(w.ledger.printed - printed, float(int(metres / Skating.GRIND_EVERY))), "$1 every %.0f m: $%d" % [Skating.GRIND_EVERY, int(w.ledger.printed - printed)])
	check(is_equal_approx(w.ledger.total(w.drones, w.bills) - total, w.ledger.printed - printed), "lying on the pavement, every dollar accounted for")
	check(w.bills.all(func(b): return w.skating.kerbs.height_at(b.pos) == Kerbs.HEIGHT), "the bills are on the pavement, not in the road")
	check(w.skating.last_trick.begins_with("Grind"), "and it says how far and how much (%s)" % w.skating.last_trick)


func test_jump_pops_off_and_the_edge_slows_you() -> void:
	var w := _rider()
	w.skating.step(0.016, _coming_down(), false, Vector2(-40, 3.7))
	for i in 30:
		w.skating.step(0.016, {}, false, Vector2.ZERO)
	check(w.skating.speed < 8.0, "the kerb's edge slows the board (%.2f m/s)" % w.skating.speed)
	var out := w.skating.step(0.016, {"jump_pressed": true}, false, Vector2.ZERO)
	check(not w.skating.grinding and out.jump == Skating.OLLIE_MIN and not out.grind, "jump pops you off it, up into the air")
	w.skating.dismount()
	check(not w.skating.grinding, "and getting off the board ends any grind")
