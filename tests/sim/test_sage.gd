## Sim tests: Mr. Nobody and his stories.
extends TestCase


func _meeting() -> Array:
	var w := World.new()
	w.add_player(Vector2(0, 0), 0.0)
	var sage := w.add_sage(Vector2(10, 0))
	return [w, sage]


func test_the_stories_are_sound() -> void:
	var ids := {}
	var sorted := true
	var last_level := 0
	var short := 0
	for t in Stories.TOPICS:
		ids[t.id] = true
		sorted = sorted and t.level >= last_level
		last_level = t.level
		short += 1 if t.pages.size() < 1 else 0
		for p in t.pages:
			short += 1 if String(p).length() < 60 else 0
	check(ids.size() == Stories.TOPICS.size(), "every topic has its own id (%d topics)" % ids.size())
	check(sorted, "they run in order of the level they open at")
	check(short == 0, "every topic has pages, and every page is more than a line")
	check(not Stories.topic(Stories.FIRST).is_empty() and Stories.topic(Stories.FIRST).level == 1, "there is a first meeting, open from the start")
	check(Stories.TOPICS.any(func(t): return t.level >= 5), "and there are stories for later levels")


func test_the_stories_steer_clear_of_loaded_tropes() -> void:
	# An editorial rule, kept as a test so a rewrite can't slip one in: the stories are about scarcity, trust and
	# promises, not about what kind of people handle money.
	var banned := ["usur", "moneylender", "money-lender", "clipp", "shaving of coins", "rothschild", "\\bjews?\\b", "\\bjewish\\b", "greedy", "cheat", "parasite", "conspir"]
	var hits: Array = []
	for t in Stories.TOPICS:
		var text := (String(t.title) + " " + " ".join(t.pages)).to_lower()
		for b in banned:
			var re := RegEx.create_from_string(b)
			if re.search(text) != null:
				hits.append("%s: %s" % [t.id, b])
	check(hits.is_empty(), "no loaded tropes in any topic %s" % str(hits))


func test_he_has_no_needs_and_stays_put() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var sage: Drone = mw[1]
	check(sage.kind == "sage" and sage.label == "Stranger" and sage.needless and sage.aloof and w.sage_drone == sage, "he is a drone with no needs who is just a \"Stranger\" until he says who he is")
	w.sage.learn_name()
	check(sage.label == "Mr. Nobody" and w.sage.name_known, "and then he is Mr. Nobody")
	for i in 1500:
		w.tick(1.0)
	check(sage.bars.hunger == 1.0 and sage.care == "" and sage.pos.distance_to(Vector2(10, 0)) < 0.5, "days later he is as he was, and where he was")
	check(Lines.voice_of(sage) == "sage" and Lines.for_event(sage, Lines.NEAR).size() == 3, "he has a voice of his own for the chat bubbles")


func test_he_notices_the_gun_when_the_hero_is_near_and_on_foot() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	check(not w.sage.noticed(), "he doesn't notice a hero who has no gun")
	w.gun_owned = true
	w.player.pos = Vector2(-5, 0)
	check(not w.sage.noticed(), "or one who is far away (%.0f m)" % w.player.pos.distance_to(w.sage_drone.pos))
	w.player.pos = Vector2(5, 0)
	check(w.sage.noticed() and not w.sage.calls_out(), "but one with the gun, near, on foot: he does")
	w.bike = Bike.new(Vector2(5, 0))
	w.riding.mount()
	check(not w.sage.noticed() and w.sage.calls_out(), "on the bike he calls out instead, and waits")
	w.riding.dismount()
	w.player.care = "down"
	check(not w.sage.noticed(), "and he doesn't wake the unconscious")
	w.player.care = ""
	w.sage.tell(Stories.FIRST)
	check(w.sage.met and not w.sage.noticed() and not w.sage.calls_out(), "once they have met, he leaves them to come to him")
	check(w.sage.in_talking_range(), "and they can talk again when they are near (E)")


func test_what_he_will_tell_depends_on_the_level() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var l1 := w.sage.topics_for(1)
	check(l1.any(func(t): return t.id == "who") and l1.any(func(t): return t.id == "shell") and not l1.any(func(t): return t.id == "gold"), "at level 1 he offers who he is and the shell, not the gold")
	check(w.sage.tell("gold").is_empty() and not w.sage.told.has("gold"), "he won't tell a story that isn't open yet")
	w.player.growth.add(Growth.total_for(4))
	check(w.player.growth.level == 4 and w.sage.topics_for(w.player.growth.level).size() > l1.size(), "as the hero levels up he opens more (level %d)" % w.player.growth.level)
	check(w.sage.tell("gold").size() >= 2 and w.sage.told.has("gold"), "telling a story returns its pages and remembers it")
	var again: Dictionary = w.sage.topics_for(4).filter(func(t): return t.id == "gold")[0]
	check(again.told, "and the list marks it as told")
	check(not w.sage.met, "telling another story is not the first meeting")
	var pages := w.sage.tell(Stories.FIRST)
	check(w.sage.met and pages.size() >= 2 and not w.sage.topics_for(4).any(func(t): return t.id == Stories.FIRST), "the first meeting is the one that makes them met, and it isn't offered again")


func test_he_walks_over_and_goes_home_again() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var sage: Drone = mw[1]
	w.gun_owned = true
	w.player.pos = Vector2(-2, 0)
	for i in 3:
		w.tick(1.0)
	check(w.sage.approaching and not w.sage.arrived, "he notices and starts to walk over")
	check(sage.speech != "" and sage.speech_ttl > 0.0, "and says something as he goes: \"%s\"" % sage.speech)
	for i in 40:
		w.tick(1.0)
	check(w.sage.arrived and not w.sage.approaching, "he arrives")
	check(sage.pos.distance_to(w.player.pos) <= Sage.GREET_RANGE and sage.pos.distance_to(w.player.pos) > 1.5, "near enough to talk, not on top of the hero (%.1f m)" % sage.pos.distance_to(w.player.pos))
	w.sage.begin_talking()
	for i in 20:
		w.tick(1.0)
	check(w.sage.talking and sage.pos.distance_to(w.player.pos) <= Sage.GREET_RANGE, "while they talk he stays put")
	w.sage.tell(Stories.FIRST)
	w.sage.end_talking()
	w.player.pos = Vector2(-40, 0)
	for i in 60:
		w.tick(1.0)
	check(sage.pos.distance_to(w.sage.home) < 0.6, "afterwards he walks back to his door")


func test_he_gives_up_on_a_hero_who_runs_off_and_calls_out_to_a_rider() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var sage: Drone = mw[1]
	w.gun_owned = true
	w.player.pos = Vector2(0, 0)
	w.tick(1.0)
	check(w.sage.approaching, "he starts out")
	w.player.pos = Vector2(-60, 0)
	for i in 3:
		w.tick(1.0)
	check(not w.sage.approaching and not w.sage.arrived, "but gives up if the hero is gone")
	w.bike = Bike.new(Vector2(4, 0))
	w.player.pos = Vector2(4, 0)
	w.riding.mount()
	for i in 20:
		w.tick(1.0)
	var calls := sage.speech_seq
	check(sage.speech.contains("contraption") and not w.sage.approaching, "to a rider he calls out instead of walking over: \"%s\"" % sage.speech)
	for i in 5:
		w.tick(1.0)
	check(sage.speech_seq == calls, "and not every second")


func test_he_does_not_go_for_loose_money() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var sage: Drone = mw[1]
	w.player.pos = Vector2(500, 500)
	var b := w.gun.fire(5.0, "gift")
	w.gun.land(b, Vector2(6, 0))
	var drifter := w.add_drifter(Vector2(11, 0), 0.0)
	for i in 30:
		w.tick(1.0)
	check(sage.pos.distance_to(Vector2(10, 0)) < 0.2 and sage.wallet == 0.0, "five dollars lie six metres from him and he doesn't move: that is the strange thing about him")
	check(not w.bills.has(b) and drifter.wallet == 5.0, "the drifter next to him has it (and anyone else would)")


func test_he_invites_the_hero_into_his_house_and_talks_there() -> void:
	var mw := _meeting()
	var w: World = mw[0]
	var sage: Drone = mw[1]
	# a house to the east of him: a door at (10, 0) going in toward +x, his place 5 m inside
	var square := PackedVector2Array([Vector2(10, -6), Vector2(22, -6), Vector2(22, 6), Vector2(10, 6)])
	sage.pos = Vector2(8, 0)
	w.sage.home = Vector2(8, 0)
	w.sage.set_house(square, Vector2(15, 0))
	w.gun_owned = true
	w.player.pos = Vector2(-2, 0)
	for i in 3:
		w.tick(1.0)
	check(w.sage.approaching and sage.speech.contains("Come in"), "he notices and asks the hero in: \"%s\"" % sage.speech)
	for i in 20:
		w.tick(1.0)
	check(Geometry2D.is_point_in_polygon(sage.pos, square) and sage.pos.distance_to(Vector2(15, 0)) < 0.5, "he goes inside to his place")
	check(w.sage.approaching and not w.sage.arrived, "and waits there while the hero stays out in the street")
	for i in 20:
		w.tick(1.0)
	check(sage.speech_seq >= 2, "inviting again from time to time")
	w.player.pos = Vector2(11.5, 0)
	w.tick(1.0)
	check(w.sage.arrived and not w.sage.approaching, "once the hero has stepped in, the talk begins")
	w.sage.begin_talking()
	w.sage.tell(Stories.FIRST)
	w.sage.end_talking()
	w.player.pos = Vector2(-40, 0)
	for i in 30:
		w.tick(1.0)
	check(sage.pos.distance_to(Vector2(8, 0)) < 0.6, "afterwards he goes back out to his door")
