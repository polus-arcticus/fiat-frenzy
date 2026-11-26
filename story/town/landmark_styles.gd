## The story's landmarks, drawn with more character than a flat-topped extrusion of their outline: a few real buildings of
## Frankfurt, by their OpenStreetMap id, and a monument at a fixed place. OpenStreetMap has their outlines and, for some, a height,
## but not their shape. Handed to the city's views (Landmarks.use) by the composition root; the style keys are Landmarks'.
class_name LandmarkStyles
extends RefCounted

const STYLES := {
	# The European Central Bank's towers: one outline in the data, 185 m, a sloping top. Glass-blue.
	156432555: {"height": 185.0, "walls": Color(0.50, 0.66, 0.72), "roof": "skillion", "drop": 24.0, "roof_col": Color(0.40, 0.50, 0.56)},
	# ...and its Grossmarkthalle, the old market hall: a long low hall under a shallow gable.
	300429302: {"height": 23.0, "walls": Color(0.88, 0.80, 0.62), "roof": "gable", "rise": 5.0, "roof_col": Color(0.46, 0.50, 0.50)},
	# The Paulskirche: an oval rotunda of red sandstone under a shallow dome.
	11526375: {"height": 21.0, "walls": Color(0.74, 0.46, 0.37), "roof": "dome", "rise": 7.0, "roof_col": Color(0.42, 0.55, 0.48), "lantern": true},
	# (The Hauptbahnhof has no style here: the map has it in parts, its arched halls among them, and they are drawn.)
	# The Kaiserdom: a long red sandstone church with its tall tower at the west end.
	11018815: {"height": 25.0, "walls": Color(0.70, 0.42, 0.34), "roof": "hip", "rise": 9.0, "roof_col": Color(0.40, 0.52, 0.46),
		"tower": {"size": 17.0, "height": 66.0, "spire": 28.0, "at": "west"}},
}

## Monuments at fixed places in the story's district: the Einheitsdenkmal (the data has only a point for it), and the
## Gerechtigkeitsbrunnen on the Römerberg (the map has its basin, not what stands in it).
const PROPS := [
	{"at": Vector2(885.2, -257.0), "kind": "monument", "label": "Einheitsdenkmal"},
	{"at": Vector2(955.1, -198.2), "kind": "fountain_statue", "label": "Gerechtigkeitsbrunnen"},
]


## The Römerberg. Their gables face the square, so their ridges run east to west. West side, the town hall: three stepped gables of
## pale sandstone (Alt-Limpurg, Zum Römer, Löwenstein) and their plainer neighbours. East side, the half-timbered Ostzeile.
const _EW := Vector2.RIGHT
const _SLATE := Color(0.27, 0.28, 0.34)
const _TILE := Color(0.62, 0.3, 0.24)


static func _stepped(height: float, rise: float, walls: Color) -> Dictionary:
	return {"height": height, "walls": walls, "roof": "stepped", "rise": rise, "ridge": _EW, "roof_col": _SLATE}


static func _house(height: float, rise: float, walls: Color, roof_col := _SLATE) -> Dictionary:
	return {"height": height, "walls": walls, "roof": "gable", "rise": rise, "ridge": _EW, "roof_col": roof_col, "timber": true}


## Every hand-made style: the landmarks and the Römerberg's houses.
static func all() -> Dictionary:
	var out := STYLES.duplicate()
	var stone := Color(0.9, 0.78, 0.64)
	var rose := Color(0.84, 0.6, 0.5)
	out[72449456] = _stepped(12.0, 8.0, rose)
	out[72449466] = _stepped(13.5, 9.5, stone)
	out[174469545] = _stepped(12.0, 8.0, rose.lightened(0.15))
	for id in [174469544, 174480694]:
		out[id] = _house(11.5, 5.5, stone.lightened(0.15))
		out[id].timber = false
	out[174469543] = _house(13.0, 7.0, Color(0.93, 0.87, 0.74))
	var white := Color(0.95, 0.92, 0.84)
	# The Alte Nikolaikirche: red sandstone with white trim, a steep slate roof behind a gallery of pinnacles; its bell tower.
	var red := Color(0.72, 0.4, 0.34)
	out[27769415] = {"height": 13.0, "walls": red, "roof": "gable", "rise": 11.0, "ridge": _EW, "roof_col": _SLATE, "pinnacles": true}
	out[174637354] = {"height": 33.0, "walls": red.lightened(0.18), "roof": "hip", "rise": 15.0, "roof_col": Color(0.42, 0.56, 0.5), "pinnacles": true}
	var ostzeile := {174538676: [12.5, 6.5, Color(0.93, 0.84, 0.66)], 174638386: [14.0, 6.0, white], 174538677: [12.0, 7.0, Color(0.9, 0.7, 0.6)],
		174538670: [14.0, 7.0, white], 174538672: [12.0, 5.5, Color(0.84, 0.88, 0.8)], 174538675: [12.5, 5.0, Color(0.94, 0.82, 0.62)],
		174502575: [12.0, 6.5, white], 174502571: [14.0, 6.0, Color(0.88, 0.74, 0.68)]}
	for id in ostzeile:
		var v: Array = ostzeile[id]
		out[id] = _house(v[0], v[1], v[2], _TILE if id % 2 == 0 else _SLATE)
	return out
