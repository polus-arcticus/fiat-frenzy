## Windowed screenshots of the first market's tent city (see Lodging): a tent for each of the town's people; its screen (E); then
## with five tents put up by the hero, and the newcomers who came to live in them.
##   godot --path . --script tools/capture_tent.gd -- <output dir>
extends CaptureTool


## Stands the hero in the street in front of the tent, far enough back to see all of it.
func _look(tent: Machine, back: float) -> void:
	var mid := tent.pos + Vector2(-tent.front.y, tent.front.x) * tent.residence.wing * (tent.residence.tents - 1) * Residence.TENT_WIDTH * 0.5
	_stand(mid + tent.front * back, mid, 1.0)
	game.advance(0.3)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var tent: Machine = w.machine_of(game.scenario.cast.tent)
	game.advance(5.0)
	print("the tent city: working %s, %d tents, room for %d; living there: %s" % [tent.working, tent.residence.tents, w.lodging.room_for(tent), w.lodging.housed(tent).map(func(d): return d.label if d.label != "" else d.kind)])
	_look(tent, 9.0)
	await _shot("1_tent", 90)
	game.interaction.open(tent)
	await _shot("2_screen", 90)
	var cards: Array = game.inventory._cards.get_children().filter(func(c): return c is IdCard)
	if cards.size() > 1:
		cards[1].toggled.emit(cards[1].drone.uid)  # (as a click does: their story opens out)
	await _shot("2b_card_open", 30)
	for i in 5:
		game.inventory.add_tent_requested.emit(tent)
	await _shot("3_screen_tents_added", 90)
	game.inventory.close()
	var before := w.drones.size()
	game.advance(Lodging.ARRIVE_EVERY * 5 + 5.0)
	print("now %d tents; %d newcomers: %s" % [tent.residence.tents, w.drones.size() - before, w.drones.slice(before).map(func(d): return d.label)])
	_look(tent, 11.0)
	await _shot("4_grown", 90)
	quit()
