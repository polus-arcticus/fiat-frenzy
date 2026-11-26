## Sim tests: passersby (Passersby): people crossing from gate to gate with their own cash, hunger and thirst, who stoop for
## loose money, buy from the stands near their way, and are counted as lost sales when they leave without.
extends TestCase

const FROM := Vector2(-45, 8)
const TO := Vector2(45, 8)


## A funded atom at the origin with its stands open and stocked, and nobody coming by on their own.
func _town() -> World:
	var w := World.new()
	Fixtures.grown_atom(w)
	Cluster.fund(w, "atom")
	w.begin_play()
	for m in w.machines:
		m.working = true
		m.refresh()
	return w


func _stand(w: World, kind: String) -> Machine:
	return w.machines.filter(func(m): return m.kind == kind)[0]


## One sets out past the stands, as thirsty as can be and not hungry.
func _thirsty(w: World) -> Drone:
	var d := w.passersby.arrive("atom", FROM, TO)
	d.bars.hunger = 1.0
	d.bars.thirst = 0.25
	return d


func _until_gone(w: World, d: Drone, seconds := 280) -> int:
	return Fixtures.until(w, func(): return not w.visitors.has(d), seconds)


func test_nobody_passes_where_there_are_no_gates() -> void:
	var w := _town()
	var dice := w.rng.state
	for i in 200:
		w.passersby.step(1.0)
	check(w.visitors.is_empty() and w.rng.state == dice and w.ledger.brought == 0.0, "no gates, nobody, and no dice rolled: a town measured by itself is as it was")


func test_more_come_at_rush_hour_and_never_too_many() -> void:
	check(Passersby.rate(8.5) > Passersby.rate(10.5) and Passersby.rate(10.5) > Passersby.rate(2.0) and Passersby.rate(17.2) == Passersby.RUSH, "morning, midday and evening are the rush; the night is nearly empty")
	var w := _town()
	w.passersby.gates = [{"zone": "atom", "at": FROM, "kind": "station"}, {"zone": "atom", "at": TO, "kind": "stop"}]
	var most := 0
	for i in int(Clock.DAY_SECONDS):
		w.tick(1.0)
		most = maxi(most, w.visitors.size())
	check(most > 8 and most <= Passersby.MOST, "a day of them: at most %d about at once" % most)
	var levels := {}
	for i in 200:
		var d := w.passersby.arrive("atom", FROM, TO)
		levels[d.growth.level] = true
		check_level(d)
	check(levels.size() >= 3 and _wrong == 0, "they are of different levels, each with the cash that goes with theirs (%s)" % [levels.keys()])


var _wrong := 0


func check_level(d: Drone) -> void:
	if absf(d.wallet - (Passersby.CASH + Passersby.CASH_A_LEVEL * d.growth.level)) > Passersby.CASH_GIVE + 0.13:
		_wrong += 1


func test_they_are_not_counted_as_the_towns() -> void:
	var w := _town()
	var drones := w.drones.size()
	var heads := w.zones.heads_in("atom")
	var d := _thirsty(w)
	check(w.visitors == [d] and w.drones.size() == drones and w.zones.heads_in("atom") == heads, "kept apart: no new head for the bins, nobody new in town")
	check(w.drone(d.uid) == d and w.profession_of(d) == "Passing through" and d.label != "", "but someone, with a name, who can be looked up (and given money)")


func test_a_thirsty_one_buys_a_drink_and_goes_on() -> void:
	var w := _town()
	var lemonade := _stand(w, "lemonade_stand")
	lemonade.output.add("lemonade", 12)
	lemonade.refresh()
	var d := _thirsty(w)
	var cash := d.wallet
	var sold := lemonade.sold_total
	var took := _until_gone(w, d)
	check(took > 0 and lemonade.sold_total > sold and d.wallet < cash and d.bars.thirst > 0.4, "bought on the way: $%.2f of $%.2f spent" % [cash - d.wallet, cash])
	check(w.passersby.served.drink == 1 and w.passersby.lost.drink == 0 and w.passersby.sales == 1, "a sale, and none missed")
	check(d.pos.distance_to(TO) < Passersby.ARRIVED + 0.5 and w.drone(d.uid) == null, "then on to where they were going, and gone")
	check(is_equal_approx(w.total_money(), w.ledger.printed) and is_equal_approx(w.ledger.taken, d.wallet) and is_equal_approx(w.ledger.brought, cash), "what they brought, spent and took away all adds up")


func test_a_stand_keeps_some_back_and_the_missed_sale_is_counted() -> void:
	var w := _town()
	for m in w.machines:
		m.output.take(m.item, m.output.count(m.item))
		m.input.counts.clear()  # (nothing to make more of)
		m.refresh()
	for b in w.bins:
		b.output.take(b.item, b.output.count(b.item))
		b.rate = 0.0
		b.refresh()
	var lemonade := _stand(w, "lemonade_stand")
	lemonade.output.add("lemonade", Passersby.KEEP)
	lemonade.refresh()
	var d := _thirsty(w)
	d.bars.thirst = 0.25
	var cash := d.wallet
	_until_gone(w, d)
	check(is_equal_approx(w.ledger.taken, cash), "the last %d are kept for the town's own: they spend nothing" % Passersby.KEEP)
	check(w.passersby.lost.drink == 1 and w.passersby.served.drink == 0, "so they leave thirsty: a lost sale")
	for i in int(Clock.DAY_SECONDS):
		w.tick(1.0)
	check(w.passersby.lost.drink == 0 and w.passersby.yesterday.lost.drink == 1 and w.events.any(func(e): return e.contains("Passersby yesterday")), "told at the next dawn, and counted afresh")


func test_they_stoop_for_loose_money_before_anything() -> void:
	var w := _town()
	var d := _thirsty(w)
	var cash := d.wallet
	var bill := w.gun.fire(5.0, "cash")
	w.gun.land(bill, FROM + Vector2(6, 4))
	w.drones.map(func(x): x.aloof = true)  # (the town leaves it lying, for this)
	var took := Fixtures.until(w, func(): return not w.bills.has(bill), 30)
	check(took >= 0 and d.wallet >= cash + 4.99, "they pick it up (%d s) and keep it" % took)


func test_a_save_keeps_whoever_is_passing() -> void:
	var w := _town()
	var d := _thirsty(w)
	for i in 10:
		w.tick(1.0)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var fresh := _town()
	Snapshot.new(fresh).apply(doc)
	check(fresh.visitors.size() == 1 and fresh.visitors[0].uid == d.uid and fresh.visitors[0].pos.distance_to(d.pos) < 0.01 and fresh.visitors[0].home == d.home, "where they were, going where they were going")
	check(is_equal_approx(fresh.ledger.brought, w.ledger.brought) and fresh.drone(d.uid) == fresh.visitors[0], "with their money in the books")
