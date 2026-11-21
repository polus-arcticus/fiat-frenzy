## Sim tests: the money gun's upgrade tree (see GunTree). Mocked for now: the first node of each branch is today's gun, the story
## will unlock the rest one step at a time, and nodes without behaviour yet change nothing.
extends TestCase


func test_the_tree_starts_as_todays_gun() -> void:
	var w := World.new()
	var t := w.gun_tree
	check(t.bill_value() == 1.0 and t.shots_per_second() == 6.0 and t.ammo() == "paper", "$1 bills, six a second, paper")
	check(t.modes() == ["gift", "invest"], "gift and invest (%s)" % [t.modes()])
	check(GunTree.BRANCHES.all(func(b): return not GunTree.in_branch(b).is_empty() and t.owns(GunTree.in_branch(b)[0].id)), "every branch has its first step owned")


func test_unlocking_goes_one_step_at_a_time() -> void:
	var w := World.new()
	var t := w.gun_tree
	check(not t.unlock("bill_20") and t.bill_value() == 1.0, "twenties can't come before fives")
	check(t.unlock("bill_5") and t.bill_value() == 5.0, "fives can")
	check(not t.unlock("bill_5"), "and not twice")
	check(t.unlock("bill_20") and t.bill_value() == 20.0, "then twenties")
	check(t.unlock("rate_9") and t.shots_per_second() == 9.0, "and the rate of fire")
	check(not t.unlock("nonsense"), "nothing that isn't in the tree")


func test_the_gun_prints_what_the_tree_says() -> void:
	var w := World.new()
	w.add_player(Vector2.ZERO)
	w.gun_owned = true
	w.gun_tree.unlock("bill_5")
	var printed := w.ledger.printed
	var b := w.gun.fire(w.gun_tree.bill_value(), "gift")
	check(b.value == 5.0 and is_equal_approx(w.ledger.printed - printed, 5.0), "with fives unlocked, a bill printed is $5")


func test_nodes_without_behaviour_change_nothing() -> void:
	var w := World.new()
	var t := w.gun_tree
	check(t.unlock("credit") and t.owns("credit") and t.modes() == ["gift", "invest"], "a line of credit can be owned, but is not a mode yet")
	check(t.unlock("rolled") and t.ammo() == "paper", "rolled bills likewise: the gun still fires paper")


func test_the_tree_is_saved() -> void:
	var w := World.new()
	w.add_player(Vector2.ZERO)
	w.gun_tree.unlock("bill_5")
	var data = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var w2 := World.new()
	w2.add_player(Vector2.ZERO)
	Snapshot.new(w2).apply(data)
	check(w2.gun_tree.owns("bill_5") and w2.gun_tree.bill_value() == 5.0, "a save keeps what the hero has unlocked")
