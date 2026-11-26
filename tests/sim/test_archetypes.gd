## Sim tests: the look of a civic building made from its footprint (Archetypes), and which building it is given to (Landmarks).
extends TestCase

const NAVE := [Vector2(0, 0), Vector2(30, 0), Vector2(30, 12), Vector2(0, 12)]
const SQUARE := [Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)]


func test_a_long_church_has_its_tower_at_the_west_end() -> void:
	var st := Archetypes.style("church", PackedVector2Array(NAVE))
	check(st.roof == "gable" and st.has("tower"), "a long nave has a gable and a tower")
	check(Vector2(st.tower.dir).x < 0.0, "the tower is at the west end")
	var turned := Archetypes.style("church", PackedVector2Array([Vector2(30, 12), Vector2(0, 12), Vector2(0, 0), Vector2(30, 0)]))
	check(turned.tower.dir == st.tower.dir, "whichever way round its outline is wound")
	check(st.tower.height > st.height, "the tower stands over the nave (%.0f m over %.0f m)" % [st.tower.height, st.height])


func test_a_small_chapel_has_no_tower() -> void:
	var st := Archetypes.style("church", PackedVector2Array(SQUARE))
	check(not st.has("tower") and st.roof == "hip", "a small square chapel is a hip roof and no tower")


func test_the_same_outline_gives_the_same_style() -> void:
	for kind in ["church", "station", "fire", "townhall", "police", "hospital"]:
		check(Archetypes.style(kind, PackedVector2Array(NAVE)) == Archetypes.style(kind, PackedVector2Array(NAVE)) and not Archetypes.style(kind, PackedVector2Array(NAVE)).is_empty(), "a %s" % kind)
	check(Archetypes.style("apartments", PackedVector2Array(NAVE)).is_empty(), "and a house has none")


func test_a_big_station_is_cut_like_the_hauptbahnhof() -> void:
	var hall := PackedVector2Array([Vector2(0, 0), Vector2(120, 0), Vector2(120, 40), Vector2(0, 40)])
	var pieces := Landmarks.pieces(1, hall, "station")
	check(pieces.size() == 2 and pieces.any(func(p): return p.style.get("roof", "") == "vaults"), "a long station is a reception building and its arched halls")
	check(Landmarks.pieces(1, PackedVector2Array(NAVE), "station").size() == 1, "a small one is a single hall")


func test_a_hand_made_style_wins() -> void:
	Landmarks.use(LandmarkStyles.STYLES, LandmarkStyles.PROPS)  # (as the composition root hands in the story's)
	var ecb := Landmarks.pieces(156432555, PackedVector2Array(NAVE), "church")
	check(ecb.size() == 1 and ecb[0].style.height == 185.0, "the ECB's own style, whatever the map calls it")
	check(Landmarks.pieces(1, PackedVector2Array(NAVE))[0].style.is_empty(), "no civic kind and no style: built as before")
	Landmarks.use({})
	check(Landmarks.pieces(156432555, PackedVector2Array(NAVE))[0].style.is_empty(), "and without the story's styles handed in, the engine has none of its own")
	Landmarks.use(LandmarkStyles.STYLES, LandmarkStyles.PROPS)
