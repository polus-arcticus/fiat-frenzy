## Sim tests: queues at the stands. Customers line up out from the counter and are served one at a time.
extends TestCase


func _market(customers: int) -> Dictionary:
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0), 5.0)
	var m := w.machine_of(baker)
	m.front = Vector2(0, 1)
	m.output.add("bread", 20)
	var people: Array[Drone] = []
	for i in customers:
		var d := w.add_drifter(Vector2(0.0, 12.0 + i * 0.5), 20.0)
		d.bars.hunger = 0.1  # famished
		people.append(d)
	return {"w": w, "m": m, "people": people}


func test_hungry_customers_line_up_out_from_the_counter() -> void:
	var s := _market(4)
	var w: World = s.w
	var m: Machine = s.m
	for i in 400:
		w.tick(0.1)
		if m.line.size() >= 3:
			break
	check(m.line.size() >= 3, "several customers are in the line at once (%d)" % m.line.size())
	var settled := true
	for i in m.line.size():
		var at := Queueing.spot(m, i)
		settled = settled and m.line[i].pos.distance_to(at) < 3.0
	check(settled, "each is on its way to, or at, its place along the line")
	var xs := {}
	for d in m.line:
		xs[snappedf(d.pos.distance_to(m.pos), 0.5)] = true
	check(xs.size() >= 2, "they stand at different distances from the counter, not all in a clump")


func test_only_the_front_of_the_line_is_served_at_a_time() -> void:
	var s := _market(3)
	var w: World = s.w
	var m: Machine = s.m
	var sold_at_tick: Array[int] = []
	var last := 0
	for i in 1200:
		w.tick(0.1)
		if m.sold_total != last:
			sold_at_tick.append(i)
			last = m.sold_total
	check(sold_at_tick.size() >= 3, "all three are eventually served (%d sales)" % sold_at_tick.size())
	var spaced := true
	for i in range(1, sold_at_tick.size()):
		spaced = spaced and (sold_at_tick[i] - sold_at_tick[i - 1]) * 0.1 >= Queueing.SERVICE - 0.15
	check(spaced, "no two sales closer together than the vendor's service time %s" % str(sold_at_tick))
	check(m.line.is_empty(), "and the line is empty at the end")


func test_someone_who_stops_wanting_it_leaves_the_line() -> void:
	var s := _market(2)
	var w: World = s.w
	var m: Machine = s.m
	for i in 300:
		w.tick(0.1)
		if m.line.size() >= 2:
			break
	var gone: Drone = m.line[0]
	gone.job = {}
	check(w.logistics.queues.length(m) == m.line.size() and not m.line.has(gone), "a drone with another job is dropped from the line")
	var out_cold: Drone = m.line[0] if not m.line.is_empty() else null
	if out_cold != null:
		out_cold.care = "down"
		check(w.logistics.queues.length(m) == 0 or m.line[0] != out_cold, "a collapsed customer is dropped too, and the next moves up to the front")


func test_a_shorter_line_is_worth_walking_to() -> void:
	var w := World.new()
	var a := w.machine_of(w.add_vendor("bakery", Vector2(0, 0), 5.0))
	var b := w.machine_of(w.add_vendor("bakery", Vector2(8, 0), 5.0))
	a.output.add("bread", 20)
	b.output.add("bread", 20)
	a.price = b.price
	for i in 6:
		var q := w.add_drifter(Vector2(0, 3), 20.0)
		q.job = {"for": "food", "target": a, "item": "bread"}
		a.line.append(q)
	var shopper := w.add_drifter(Vector2(1, 3), 20.0)
	shopper.bars.hunger = 0.1
	var pick := w.logistics.supply.best_supply(shopper, "food")
	check(pick == b, "a shopper picks the stand with nobody waiting, over the one with six in front")


func test_a_queue_survives_a_save() -> void:
	var s := _market(3)
	var w: World = s.w
	var m: Machine = s.m
	for i in 300:
		w.tick(0.1)
		if m.line.size() >= 2:
			break
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var copy := World.new()
	var baker2 := copy.add_vendor("bakery", Vector2(0, 0), 5.0)
	for i in 3:
		copy.add_drifter(Vector2.ZERO, 0.0)
	Snapshot.new(copy).apply(data)
	var m2 := copy.machine_of(baker2)
	check(m2.line.size() == m.line.size() and (m.line.is_empty() or m2.line[0].id == m.line[0].id), "the same people are in the line, in the same order (%d)" % m2.line.size())


func test_someone_in_a_long_line_leaves_when_another_need_gets_desperate() -> void:
	var s := _market(4)
	var w: World = s.w
	var m: Machine = s.m
	var water := w.machine_of(w.add_vendor("lemonade_stand", Vector2(20, 0), 5.0))
	water.front = Vector2(0, 1)
	water.working = true
	water.output.add(water.item, 20)
	for i in 600:
		w.tick(0.1)
		if m.line.size() >= 3:
			break
	check(m.line.size() >= 3, "a line has formed (%d)" % m.line.size())
	var front: Drone = m.line[0]
	var waiting: Drone = m.line[2]
	front.bars.thirst = 0.05
	waiting.bars.thirst = 0.05
	waiting.bars.hunger = 0.2
	w.tick(0.1)
	check(m.line.has(front), "the one at the front stays: they are about to be served")
	check(not m.line.has(waiting), "the one further back, parched, gives up their place")
	check(waiting.job.is_empty() or waiting.job.target == water, "and goes for a drink instead")
	w.tick(0.1)
	check(waiting.job.get("target") == water, "(they are on their way to the lemonade stand)")
	waiting.bars.thirst = 1.0
	waiting.bars.hunger = 0.1
	waiting.job = {}
	for i in 300:
		w.tick(0.1)
		if m.line.has(waiting):
			break
	check(m.line.has(waiting) and m.line.back() == waiting, "hungry again, they join the food line at the back, like anyone arriving")
