## Headless benchmark: how the sim's cost grows with the number of towns (each a market with its supply chain:
## 4 stands, a food bank, 2 cart runners, 6 drifters), all in one zone, one zone each, and one zone each with only one
## running.   godot --headless --path . --script tools/bench_zones.gd
extends SceneTree


func _town(w: World, zone: String, ox: float) -> void:
	w.build_zone = zone
	for i in 4:
		var kind: String = ["bakery", "hot_dog_stand", "lemonade_stand", "tent"][i]
		var v := w.add_vendor(kind, Vector2(ox + i * 5.0, 0), 30.0, true, true)
		v.label = "v"
	var fb := w.add_food_bank(Vector2(ox - 8.0, 0))
	for i in 2:
		w.add_runner(Vector2(ox - 4.0 + i, 3), 20.0)
	for i in 6:
		w.add_drifter(Vector2(ox + i * 2.0, 6), 15.0)


func _build(n: int, mode: String) -> World:
	seed(7)
	var w := World.new()
	for t in n:
		_town(w, "z%d" % t if mode != "one" else "district", t * 400.0)
	if mode == "fenced":
		w.zones.active = ["z0"] as Array[String]
	return w


func _initialize() -> void:
	print("towns  mode     people  machines   ms/tick   sold(z0)")
	for n in [1, 4, 10, 20]:
		for mode in ["one", "zones", "fenced"]:
			var w := _build(n, mode)
			for i in 50:
				w.tick(0.1)  # warm up
			var t0 := Time.get_ticks_usec()
			var ticks := 300
			for i in ticks:
				w.tick(0.1)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0 / ticks
			var sold := 0
			for m in w.machines:
				if m.zone == ("district" if mode == "one" else "z0"):
					sold += m.sold_total
			print("%5d  %-7s %6d  %8d  %8.3f   %d" % [n, mode, w.drones.size(), w.machines.size(), ms, sold])
	quit()
