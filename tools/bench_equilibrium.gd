## Bench: two saves on neighbouring tiles are merged, and the joined towns settle. Save A is a market town with no food bank (its
## stands run short of flour, water and the like, so it gets dear and hungry); save B, the tile to the east, has a food bank and
## cart runners. After the merge the hero stands in A (full detail) and B runs in summary. Prints, every hour, each tile's
## people, mean price of food and drink, stock on the shelves and money, and what has crossed the border.
##   godot --headless --path . --script tools/bench_equilibrium.gd
extends SceneTree

const FRANKFURT := [50.1086307, 8.6687641]
const HOURS := 6


func _tile(i: int) -> String:
	var t0 := TileKey.parse(TileKey.of(FRANKFURT[0], FRANKFURT[1]))
	return TileKey.key(t0.x + i, t0.y)


func build(tiles: Array) -> World:
	var w := World.new()
	for t in tiles:
		w.zones.add_tile(t)
		Fixtures.market_town(w, t, TileKey.rect(t).get_center(), 6, t == _tile(1), 60.0)  # only B's tile has a food bank
		w.add_welfare_office(TileKey.rect(t).get_center() + Vector2(-14.0, -10.0))  # each save had its own town's purse
	return w


func _save(tile: String, seconds: int) -> Dictionary:
	var w := build([tile])
	w.add_player(TileKey.rect(tile).get_center() + Vector2(0, 20), 25.0)
	w.begin_play()
	for i in seconds:
		w.tick(1.0)
	return Snapshot.new(w).capture()


func _row(w: World, hour: int, tile: String, name: String) -> String:
	var prices := []
	var stock := 0
	for m in w.zones.machines_in(tile):
		if m.working and Catalog.class_of(m.item) in ["food", "drink"]:
			prices.append(m.price)
			stock += m.stock()
	var mean: float = prices.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, prices.size())
	var people := w.zones.drones_in(tile)
	var down := people.filter(func(d): return d.unconscious()).size()
	var money: float = w.zones.books().get(tile, 0.0)
	return "%4d  %-4s %6d %5d  %8.2f %6d  %9.2f" % [hour, name, people.size(), down, mean, stock, money]


func _initialize() -> void:
	var a := _save(_tile(0), 1200)  # A has played 20 minutes on its own
	var b := _save(_tile(1), 1200)
	var w := Merge.combine(a, b, build)
	w.zones.active = [w.player.zone] as Array[String]
	var money := w.total_money()
	print("merged: tiles %s, %d people, $%.2f in the world" % [w.zones.tiles.keys(), w.drones.size(), money])
	print("hour  tile people  down  mean $  stock      money   (crossed: people, carts)")
	var last_cross := 0
	var last_carts := 0
	var leaks := 0
	for hour in HOURS + 1:
		print(_row(w, hour, _tile(0), "A"))
		print(_row(w, hour, _tile(1), "B") + "   (+%d people, +%d carts)" % [w.borders.crossings - last_cross, w.borders.carts - last_carts])
		last_cross = w.borders.crossings
		last_carts = w.borders.carts
		if hour == HOURS:
			break
		for s in 3600:
			w.tick(1.0)
			if not is_equal_approx(w.total_money(), w.ledger.printed):  # (pass go adds money each dawn: it is printed, not leaked)
				leaks += 1
	print("ticks where the money in the world was not what was printed: %d (issued by pass go: $%.2f)" % [leaks, w.ledger.issued])
	for pair in [["A", _tile(0)], ["B", _tile(1)]]:
		print("at the end, in %s:" % pair[0])
		var by := {}
		for d in w.zones.drones_in(pair[1]):
			var e: Array = by.get(d.kind, [0, 0.0, []])
			by[d.kind] = [e[0] + 1, e[1] + d.wallet, e[2] + ["h%.1f t%.1f %s" % [d.bars.hunger, d.bars.thirst, d.care]]]
		for k in by:
			print("   %-8s x%d  wallets $%.2f  %s" % [k, by[k][0], by[k][1], by[k][2]])
		for m in w.zones.machines_in(pair[1]):
			print("   %-15s stock %2d price %5.2f working %s inputs %s" % [m.kind, m.stock(), m.price, m.working, m.input.counts])
		for fb in w.zones.food_banks_in(pair[1]):
			print("   food bank       %s" % fb.output.counts)
	quit()
