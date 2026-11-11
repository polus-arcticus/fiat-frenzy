## Sim tests: what people say.
extends TestCase


func _street() -> Array:
	var w := World.new()
	w.add_player(Vector2(0, 0))
	var d := w.add_drifter(Vector2(3, 0), 5.0)
	d.label = "Edda"
	return [w, d]


func test_every_voice_has_its_lines() -> void:
	for voice in Lines.VOICES:
		var v: Dictionary = Lines.VOICES[voice]
		check(v.near.size() == 3 and v.cash.size() == 1 and v.gift.size() == 1 and v.invest.size() == 1, "%s: three lines for when you get close, one each for cash, a gift and an investment" % voice)
	var w := World.new()
	var banker := w.add_drifter(Vector2.ZERO)
	banker.look = "banker"
	var runner := w.add_runner(Vector2.ZERO)
	var keeper := w.add_food_bank(Vector2(5, 5))
	var vendor := w.add_vendor("bakery", Vector2(9, 9))
	check(Lines.voice_of(banker) == "banker" and Lines.voice_of(runner) == "runner" and Lines.voice_of(keeper) == "keeper" and Lines.voice_of(vendor) == "vendor", "a voice goes with what someone does, and a banker sounds like one")


func test_people_speak_when_you_get_close_but_not_far_off() -> void:
	var sw := _street()
	var w: World = sw[0]
	var d: Drone = sw[1]
	var far := w.add_drifter(Vector2(40, 0), 5.0)
	for i in 60:
		w.tick(1.0)
	check(d.speech_seq > 0 and d.speech in Lines.for_event(d, Lines.NEAR), "someone near says one of their three 'close' lines: \"%s\"" % d.speech)
	check(far.speech_seq == 0, "someone 40 m away says nothing")


func test_a_close_line_is_not_repeated_straight_away() -> void:
	var sw := _street()
	var w: World = sw[0]
	var d: Drone = sw[1]
	d.chat_cooldown = 0.0
	var said := 0
	var last := d.speech_seq
	for i in int(Chatter.NEAR_COOLDOWN - 2.0):
		w.tick(1.0)
		if d.speech_seq != last:
			said += 1
			last = d.speech_seq
	check(said <= 1, "in the first %d s they speak at most once (%d)" % [int(Chatter.NEAR_COOLDOWN - 2.0), said])
	var lines: Array = []
	for k in 40:
		w.chatter.say(d, Lines.NEAR)
		lines.append(d.speech)
	var repeats := 0
	for k in range(1, lines.size()):
		repeats += 1 if lines[k] == lines[k - 1] else 0
	check(repeats == 0, "and never the same line twice running")


func test_money_gets_a_line() -> void:
	var w := World.new()
	w.add_player(Vector2(100, 100))
	var drifter := w.add_drifter(Vector2(0, 0), 0.0)
	var vendor := w.add_vendor("bakery", Vector2(20, 0), 0.0, false)
	w.gun.gift(drifter, 5.0)
	check(drifter.speech in Lines.for_event(drifter, Lines.GIFT), "being given money: \"%s\"" % drifter.speech)
	var b := w.gun.fire(2.0, "gift")
	w.gun.land(b, Vector2(0, 5))
	var other := w.add_drifter(Vector2(0, 5), 0.0)
	w.cash.collect(other, b)
	check(other.speech in Lines.for_event(other, Lines.CASH), "picking up loose money: \"%s\"" % other.speech)
	w.gun.invest(vendor, 20.0)
	check(vendor.speech in Lines.for_event(vendor, Lines.INVEST), "being invested in: \"%s\"" % vendor.speech)
	check(vendor.speech_ttl > 0.0, "and a line stays up for a few seconds")
	w.tick(Chatter.LINE_TIME + 0.5)
	check(vendor.speech_ttl == 0.0, "then goes")


func test_a_burst_of_bills_is_one_line() -> void:
	var w := World.new()
	w.add_player(Vector2(100, 100))
	var d := w.add_drifter(Vector2(0, 0), 0.0)
	for i in 20:
		w.gun.gift(d, 1.0)
		w.tick(0.1)
	check(d.speech_seq == 1, "twenty bills in two seconds make one line, not twenty (%d)" % d.speech_seq)
	w.tick(Chatter.EVENT_THROTTLE + 0.1)
	w.gun.gift(d, 1.0)
	check(d.speech_seq == 2, "and the next gift, a moment later, gets another")


func test_a_money_line_cuts_in_on_a_close_line() -> void:
	var sw := _street()
	var w: World = sw[0]
	var d: Drone = sw[1]
	w.chatter.say(d, Lines.NEAR)
	var seq := d.speech_seq
	w.gun.gift(d, 5.0)
	check(d.speech_seq == seq + 1 and d.speech in Lines.for_event(d, Lines.GIFT), "a gift interrupts what they were saying")


func test_the_unconscious_say_nothing_and_talk_does_not_disturb_the_dice() -> void:
	var sw := _street()
	var w: World = sw[0]
	var d: Drone = sw[1]
	d.care = "down"
	for i in 30:
		w.tick(1.0)
	w.gun.gift(d, 5.0)
	check(d.speech_seq == 0, "someone who has collapsed says nothing, near or not")
	var w2 := World.new()
	w2.add_player(Vector2.ZERO)
	for i in 5:
		w2.add_drifter(Vector2(2, i), 1.0)
	seed(99)
	var a := randf()
	seed(99)
	for i in 30:
		w2.chatter.step(1.0)
	var b := randf()
	check(a == b and w2.drones.any(func(x): return x.speech_seq > 0), "people talked, and the world's own random numbers were untouched")
