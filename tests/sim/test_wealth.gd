## Sim tests: the money scale: a notch per order of magnitude, and how far through the current one.
extends TestCase


func test_a_notch_for_every_order_of_magnitude() -> void:
	check(Wealth.tiers(0.0) == 0 and Wealth.tiers(9.99) == 0, "under $10: no notches")
	check(Wealth.tiers(10.0) == 1 and Wealth.tiers(99.99) == 1, "$10 is the first notch")
	check(Wealth.tiers(100.0) == 2 and Wealth.tiers(999.0) == 2, "$100 the second")
	check(Wealth.tiers(1000.0) == 3 and Wealth.tiers(9999.0) == 3, "$1,000 the third")
	check(Wealth.tiers(10000.0) == 4 and Wealth.tiers(5000000.0) == Wealth.MAX_TIER, "$10,000 the fourth, and the scale stops there")


func test_the_bar_fills_toward_the_next_order_and_starts_again() -> void:
	check(Wealth.progress(0.0) == 0.0 and Wealth.progress(0.5) == 0.0, "broke is empty")
	check(is_equal_approx(Wealth.progress(1.0), 0.0) and is_equal_approx(Wealth.progress(5.5), 0.5), "from $1 it fills toward the first notch")
	check(is_equal_approx(Wealth.progress(55.0), 0.5), "$55 is half way from $10 to $100")
	check(Wealth.progress(9.99) > 0.99 and Wealth.progress(10.0) < 0.001, "reaching $10 gets the notch and the bar starts again from empty")
	check(Wealth.progress(99.99) > 0.99 and Wealth.progress(100.0) < 0.001, "and again at $100")
	check(Wealth.progress(20000.0) == 1.0, "at the top of the scale the bar stays full")
	var last := -1.0
	var rising := true
	for dollars in [0.0, 1.0, 3.0, 9.0, 10.0, 40.0, 99.0, 100.0, 400.0, 999.0, 1000.0, 5000.0]:
		var level := float(Wealth.tiers(dollars)) + Wealth.progress(dollars)
		rising = rising and level >= last
		last = level
	check(rising, "(more money never reads as less)")
