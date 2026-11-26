## Sim tests: two players' saves become one world (see Merge). Save A holds tiles 1 and 2, save B tiles 2 and 3: they share
## tile 2, where both started from the same seed and then went their own ways.
extends TestCase

const FRANKFURT := [50.1086307, 8.6687641]


static func _tile(i: int) -> String:
	var t0 := TileKey.parse(TileKey.of(FRANKFURT[0], FRANKFURT[1]))
	return TileKey.key(t0.x + i, t0.y)


## A freshly seeded world of `tiles`: a market town in each, the same way every time (this is the common ancestor).
static func build(tiles: Array) -> World:
	var w := World.new()
	for t in tiles:
		w.zones.add_tile(t)
		Cluster.build(w, t, TileKey.rect(t).get_center(), 6, true, 40.0, false)
	return w


## The first drifter seeded on tile 2 (uids are counted per zone across every kind of thing, so look it up).
static func _drifter() -> String:
	return build([_tile(2)]).zones.drones_in(_tile(2)).filter(func(d): return d.kind == "drifter")[0].uid


## A save: its tiles seeded, a hero on the first of them, `seconds` of play, and the hero investing in tile 2's bakery.
func _play(tiles: Array, seconds: int, invest: float) -> World:
	var w := build(tiles)
	w.add_player(TileKey.rect(tiles[0]).get_center(), 25.0)
	w.begin_play()
	for i in seconds:
		w.tick(1.0)
	var baker: Drone = w.drone(_tile(2) + "#0")
	w.gun.invest(baker, invest)
	w.gun.gift(w.drone(_drifter()), 30.0)  # (a drifter there gets a present, in both saves)
	for i in 60:
		w.tick(1.0)
	return w


func _saves() -> Array:
	var a := _play([_tile(1), _tile(2)], 600, 300.0)
	var b := _play([_tile(2), _tile(3)], 900, 300.0)
	return [a, b, Snapshot.new(a).capture(), Snapshot.new(b).capture()]


func test_slow_two_saves_that_share_a_tile_become_one_world_and_no_money_is_made_or_lost() -> void:
	var s := _saves()
	var a: World = s[0]
	var b: World = s[1]
	var base := build([_tile(2)])
	var w := Merge.combine(s[2], s[3], build)
	var expected := a.total_money() + b.total_money() - base.total_money()
	check(is_equal_approx(w.total_money(), expected), "the merged world holds A + B - the shared seed ($%.2f, expected $%.2f)" % [w.total_money(), expected])
	check(w.zones.tiles.size() == 3 and w.zones.tiles.has(_tile(1)) and w.zones.tiles.has(_tile(3)), "it has all three tiles")
	check(w.heroes.size() == 2 and w.player.uid == a.player.uid, "and both heroes, the host's at the controls")
	var drifter_uid := _drifter()
	var want: float = a.drone(drifter_uid).wallet + b.drone(drifter_uid).wallet - base.drone(drifter_uid).wallet
	check(is_equal_approx(w.drone(drifter_uid).wallet, want), "a drifter on the shared tile has what both saves gave them ($%.2f)" % w.drone(drifter_uid).wallet)
	var bakery: Machine = w.machine_of(w.drone(_tile(2) + "#0"))
	var sold: int = a.machine_of(a.drone(_tile(2) + "#0")).sold_total + b.machine_of(b.drone(_tile(2) + "#0")).sold_total - base.machine_of(base.drone(_tile(2) + "#0")).sold_total
	check(bakery.sold_total == sold, "its bakery's sales add up (%d)" % sold)
	check(bakery.equity.share(a.player.uid) > 0.0 and bakery.equity.share(b.player.uid) > 0.0, "both heroes own a share of it")
	check(bakery.equity.stake <= Equity.MAX_STAKE + 1e-6, "but together no more than 49%% (%.3f)" % bakery.equity.stake)
	var over := w.machines.filter(func(m): return m.output.counts.keys().any(func(i): return m.output.caps.has(i) and m.output.count(i) > m.output.caps[i]))
	check(over.is_empty(), "no shelf holds more than it has room for")
	var money := w.total_money()
	var leaks := 0
	for i in 600:
		w.tick(1.0)
		if not is_equal_approx(w.total_money(), money):
			leaks += 1
	check(leaks == 0, "and the merged world runs on without a leak (%d ticks off)" % leaks)


func test_slow_which_save_hosts_does_not_change_the_books() -> void:
	var s := _saves()
	var ab := Merge.combine(s[2], s[3], build)
	var ba := Merge.combine(s[3], s[2], build)
	check(is_equal_approx(ab.total_money(), ba.total_money()), "A into B or B into A, the same money ($%.2f)" % ab.total_money())
	check(ba.player.uid == (s[1] as World).player.uid, "only who is at the controls differs")
	var cut := func(w: World): return w.machine_of(w.drone(_tile(2) + "#0")).equity.stakes
	check(cut.call(ab).keys().size() == 2 and is_equal_approx(cut.call(ab).values().reduce(func(x, y): return x + y), cut.call(ba).values().reduce(func(x, y): return x + y)), "and the same stakes")


func test_slow_the_merged_world_saves_and_loads_like_any_other() -> void:
	var s := _saves()
	var w := Merge.combine(s[2], s[3], build)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var fresh := build(Merge.tiles_of(data))
	Snapshot.new(fresh).apply(data)
	check(is_equal_approx(fresh.total_money(), w.total_money()) and fresh.heroes.size() == 2, "it comes back whole, with both heroes")
