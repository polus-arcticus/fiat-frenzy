## VIEW. Turns the district data (building footprints and street lines, in metres) into a few merged
## meshes plus collision: walls, windows, roofs and street ribbons. A second set of warm windows is
## switched on at night. Nothing here knows about the simulation.
class_name CityBuilder
extends RefCounted

const FLOOR_H := 3.3
const GROUND_H := 4.2
const PALETTE: Array[Color] = [
	Color(0.93, 0.88, 0.74), Color(0.88, 0.78, 0.62), Color(0.86, 0.66, 0.55), Color(0.72, 0.78, 0.66),
	Color(0.66, 0.72, 0.80), Color(0.78, 0.50, 0.42), Color(0.90, 0.84, 0.80), Color(0.80, 0.74, 0.60),
]
const ROOFS: Array[Color] = [Color(0.36, 0.34, 0.38), Color(0.52, 0.30, 0.25), Color(0.42, 0.40, 0.36)]
const BIKE_LANE := Color(0.62, 0.42, 0.36)   # a bike lane painted on the carriageway
const BIKE_TRACK := Color(0.70, 0.34, 0.30)  # and a track beside the kerb
const GLASS := Color(0.24, 0.30, 0.38)
const LIT := Color(1.0, 0.82, 0.45)
const ASPHALT := Color(0.30, 0.30, 0.34)
const SIDEWALK := Color(0.66, 0.62, 0.55)
const KERB_STONE := Color(0.78, 0.76, 0.72)  # the kerb's edge, a lighter line along the drop
const KERB_FACE := Color(0.56, 0.54, 0.50)
const KERB_STONE_W := 0.24
const WATER := Color(0.42, 0.60, 0.74)
const WATER_Y := 0.009        # (just above the ground: under the streets and pavements)
const QUAY := Color(0.62, 0.58, 0.52)  # the low stone wall along a bank, a bridge's parapet
const QUAY_H := 0.85          # its height: a railing's
const QUAY_W := 0.35
const QUAY_BAR := 2.4         # an unseen wall above it, this high: you can't jump into the river
const STONE := Color(0.70, 0.64, 0.56)
const GROUND := Color(0.45, 0.5, 0.38)
const INSIDE := Color(0.90, 0.86, 0.76)   # the walls inside a building with a shop in it
const FLOOR := Color(0.58, 0.52, 0.46)
const CEILING := Color(0.86, 0.84, 0.78)


## A growable triangle soup with vertex colours.
class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	## One triangle, wound so it faces along `nrm` (Godot's front faces are clockwise).
	func tri(a: Vector3, b: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
		if (b - a).cross(d - a).dot(nrm) > 0.0:
			var t := b
			b = d
			d = t
		var base := v.size()
		v.append(a)
		v.append(b)
		v.append(d)
		for k in 3:
			n.append(nrm)
			c.append(col)
			i.append(base + k)

	## A quad given its four corners in order round the perimeter.
	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, nrm: Vector3, col: Color) -> void:
		tri(a, b, d, nrm, col)
		tri(a, d, e, nrm, col)

	func to_mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		if v.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = i
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	func faces() -> PackedVector3Array:
		var f := PackedVector3Array()
		for idx in i:
			f.append(v[idx])
		return f


static func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(0, flat.size(), 2):
		out.append(Vector2(flat[k], flat[k + 1]))
	return out


static func _tint(base: Color, seed_value: int, spread := 0.05) -> Color:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var f := 1.0 + r.randf_range(-spread, spread)
	return Color(clampf(base.r * f, 0, 1), clampf(base.g * f, 0, 1), clampf(base.b * f, 0, 1))


## Builds the whole district under a new Node3D. `district` is the parsed JSON. `openings` cuts a door into
## some buildings and makes them hollow, with a floor, a ceiling and inside walls: {building id: {edge, t,
## width, height}}, where `edge` is the footprint's wall (by index), `t` the metres along it to the door's
## middle, and `width` and `height` its size.
static func build(district: Dictionary, openings := {}) -> Node3D:
	return assemble(bake(district, openings))


## The long half of `build`: every wall, window, roof and street as plain triangle arrays (no nodes, no servers), so it can
## run on a worker thread (OffThread) while the loading picture keeps moving. `assemble` makes the nodes from it.
static func bake(district: Dictionary, openings := {}, kerbs: Kerbs = null) -> Dictionary:
	if kerbs == null:
		kerbs = Kerbs.of(district, openings)
	var walls := Buf.new()
	var windows := Buf.new()
	var lit := Buf.new()
	var roofs := Buf.new()
	var ground := Buf.new()
	var streets := Buf.new()

	var b: Array = district.bounds
	var pad := 400.0
	var up := Vector3.UP
	ground.quad(Vector3(b[0] - pad, 0, b[1] - pad), Vector3(b[2] + pad, 0, b[1] - pad),
		Vector3(b[2] + pad, 0, b[3] + pad), Vector3(b[0] - pad, 0, b[3] + pad), up, GROUND)

	for r in district.roads:
		_road(streets, _pts(r.pts), float(r.w), String(r["class"]), r.get("pave", []), r.get("bike", []), str(r.get("surface", "")), int(r.get("lanes", 0)))
	for bd in district.buildings:
		for piece in Landmarks.pieces(int(bd.id), _pts(bd.poly)):  # (usually the one: its whole footprint)
			var opening: Dictionary = openings.get(int(bd.id), {})
			_building(bd, walls, windows, lit, roofs, streets, opening, piece.pts, _mapped_style(bd, piece.pts, piece.style, opening))
	var raised := Buf.new()
	_kerbs(raised, kerbs)
	var bar := Buf.new()  # (collision only)
	_water(streets, walls, bar, district.get("water", {}))
	var solid_faces := walls.faces()  # walls and roofs: a bill that arcs over a building comes down on its roof, not through it
	solid_faces.append_array(roofs.faces())
	solid_faces.append_array(raised.faces())  # and the pavements: you step up onto them, a board stops at them
	solid_faces.append_array(bar.faces())     # and the unseen wall over the quays
	return {"layers": {"Ground": ground, "Streets": streets, "Pavements": raised, "Walls": walls, "Windows": windows, "Roofs": roofs},
		"lit": lit, "solid": solid_faces, "bounds": b, "pad": pad}


## The quick half of `build`, on the main thread: the meshes, the night windows and the collision, under a Node3D "City".
static func assemble(baked: Dictionary) -> Node3D:
	var b: Array = baked.bounds
	var pad: float = baked.pad
	var lit: Buf = baked.lit
	var root := Node3D.new()
	root.name = "City"
	Landmarks.add_props(root)
	var mat := Watercolor.surface()
	var layers: Dictionary = baked.layers
	for key in layers:
		var mi := MeshInstance3D.new()
		mi.name = key
		mi.mesh = layers[key].to_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["Ground", "Streets", "Pavements", "Windows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
	var lit_mi := MeshInstance3D.new()
	lit_mi.name = "LitWindows"
	lit_mi.mesh = lit.to_mesh()
	lit_mi.material_override = Watercolor.glowing()
	lit_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lit_mi.visible = false
	root.add_child(lit_mi)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	var wall_shape := ConcavePolygonShape3D.new()
	wall_shape.set_faces(baked.solid)
	var wc := CollisionShape3D.new()
	wc.shape = wall_shape
	body.add_child(wc)
	root.add_child(body)
	# The ground is a slab under the whole district, a body of its own: a plane sharing a body with the walls
	# stopped holding anyone up far from the origin (the player fell through it out by Battonnstraße).
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	ground_body.collision_layer = 1
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(b[2] - b[0] + 2.0 * pad, 2.0, b[3] - b[1] + 2.0 * pad)
	slab.shape = box
	slab.position = Vector3((b[0] + b[2]) * 0.5, -1.0, (b[1] + b[3]) * 0.5)
	ground_body.add_child(slab)
	root.add_child(ground_body)
	return root


## A building's look from what the map says of it (OsmImport._looks), where a landmark's own style doesn't already: its roof's
## shape (a gable or hip, as pitched as its `rise`, or about 35 degrees across its width) and its walls' colour (mixed into the
## watercolour palette, so a "white" or "red" doesn't shout). A building with a door cut into it keeps its flat roof (it has a
## ceiling inside).
const MAPPED_COLOUR := 0.65  # how much of a mapped colour shows through the palette's
const ROOF_PITCH := 0.7      # a roof's rise over half its width, where the map gives no rise (about 35 degrees)


static func _mapped_style(bd: Dictionary, pts: PackedVector2Array, style: Dictionary, opening: Dictionary) -> Dictionary:
	if not (bd.has("roof") or bd.has("colour")) or style.has("height"):
		return style
	var st := style.duplicate()
	if bd.has("roof") and not st.has("roof") and opening.is_empty() and str(bd.get("kind", "")) != "roof":
		st["roof"] = bd.roof
		var area := absf(_area2(pts))
		var perimeter := 0.0
		for k in pts.size():
			perimeter += pts[k].distance_to(pts[(k + 1) % pts.size()])
		var half_width := area / maxf(perimeter, 0.01)  # (half the width of a long footprint)
		st["rise"] = float(bd.get("rise", clampf(half_width * ROOF_PITCH, 1.5, 7.0)))
	if bd.has("colour") and not st.has("walls"):
		var base: Color = PALETTE[absi(int(bd.id)) % PALETTE.size()]
		st["walls"] = base.lerp(bd.colour, MAPPED_COLOUR)
	return st


static func _area2(pts: PackedVector2Array) -> float:
	var s := 0.0
	for k in pts.size():
		var a := pts[k]
		var b := pts[(k + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _building(bd: Dictionary, walls: Buf, windows: Buf, lit: Buf, roofs: Buf, floors: Buf, opening: Dictionary, pts: PackedVector2Array, style: Dictionary) -> void:
	var h: float = bd.h
	var id: int = bd.id
	var kind: String = bd.kind
	var levels: int = bd.levels
	if style.has("height"):  # a landmark, drawn with more character (see Landmarks)
		h = style.height
		levels = maxi(1, roundi(h / FLOOR_H))
	var plaster := _tint(style.walls if style.has("walls") else PALETTE[absi(id) % PALETTE.size()], id, 0.02 if style.has("walls") else 0.05)
	# a sloping top (skillion): how far down it falls at each point, along the footprint's long axis
	var skew := Landmarks.skew(pts) if style.get("roof", "") == "skillion" else {}
	var top := func(p: Vector2) -> float:
		if skew.is_empty():
			return h
		return h - float(style.get("drop", 0.0)) * clampf((p - skew.c).dot(skew.axis) / (2.0 * skew.half) + 0.5, 0.0, 1.0)
	var shopfront := plaster.darkened(0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	var gh := minf(h, GROUND_H)
	var n := pts.size()
	for k in n:
		var p := pts[k]
		var q := pts[(k + 1) % n]
		var e := q - p
		var length := e.length()
		if length < 0.5:
			continue
		var dir := e / length
		var out := Vector3(e.y, 0, -e.x).normalized()
		var p0 := Vector3(p.x, 0, p.y)
		var q0 := Vector3(q.x, 0, q.y)
		var up := Vector3(0, gh, 0)
		var has_door: bool = not opening.is_empty() and int(opening.edge) == k
		if has_door:
			_door_wall(walls, p0, dir, length, out, gh, opening, shopfront)
		else:
			walls.quad(p0, q0, q0 + up, p0 + up, out, shopfront)
			if not opening.is_empty():
				walls.quad(p0, q0, q0 + up, p0 + up, -out, INSIDE)  # the same wall from inside: solid both ways
		var top_p: float = top.call(p)
		var top_q: float = top.call(q)
		if maxf(top_p, top_q) > gh:
			walls.quad(p0 + Vector3(0, gh, 0), q0 + Vector3(0, gh, 0), q0 + Vector3(0, maxf(top_q, gh), 0), p0 + Vector3(0, maxf(top_p, gh), 0), out, plaster)
		if kind == "roof" or length < 3.6 or has_door:
			continue
		var count := int((length - 1.2) / 3.2)
		for w in count:
			var t := (w + 0.5) / count * length
			var centre := p + dir * t
			var c3 := Vector3(centre.x, 0, centre.y) + out * 0.05
			var along := Vector3(dir.x, 0, dir.y)
			for f in levels:
				var y0 := 0.6 if f == 0 else f * FLOOR_H + 0.9
				var y1 := 3.0 if f == 0 else y0 + 1.6
				var hw := 1.0 if f == 0 else 0.62
				if y1 > minf(top_p, top_q) - 0.3:
					break
				var warm := rng.randf() < 0.22
				var buf := lit if warm else windows
				var col := LIT if warm else _tint(GLASS, id * 31 + w * 7 + f, 0.12)
				buf.quad(c3 - along * hw + Vector3(0, y0, 0), c3 + along * hw + Vector3(0, y0, 0),
					c3 + along * hw + Vector3(0, y1, 0), c3 - along * hw + Vector3(0, y1, 0), out, col)
	var roof_col := _tint(style.roof_col if style.has("roof_col") else ROOFS[absi(id) % ROOFS.size()], id + 5)
	Landmarks.tower(style, pts, walls, roofs, plaster, roof_col)
	if Landmarks.roof(style, pts, h, roofs, roof_col):
		return  # a hip, dome or gable roof: drawn, and it has no floor or ceiling to add
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		var a := pts[tris[k]]
		var bb := pts[tris[k + 1]]
		var cc := pts[tris[k + 2]]
		var nrm := Vector3.UP
		if not skew.is_empty():  # tilted: the roof's own normal, so it is lit as a slope
			nrm = (Vector3(bb.x - a.x, top.call(bb) - top.call(a), bb.y - a.y)).cross(Vector3(cc.x - a.x, top.call(cc) - top.call(a), cc.y - a.y)).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
		roofs.tri(Vector3(a.x, top.call(a), a.y), Vector3(bb.x, top.call(bb), bb.y), Vector3(cc.x, top.call(cc), cc.y), nrm, roof_col)
		if not opening.is_empty():  # a floor, and a ceiling at the top of the ground floor
			floors.tri(Vector3(a.x, 0.04, a.y), Vector3(bb.x, 0.04, bb.y), Vector3(cc.x, 0.04, cc.y), Vector3.UP, FLOOR)
			roofs.tri(Vector3(a.x, gh, a.y), Vector3(bb.x, gh, bb.y), Vector3(cc.x, gh, cc.y), Vector3.DOWN, CEILING)


## A wall with a doorway cut in it: a jamb each side and a lintel over the top, seen from outside and, in the
## inside colour, from within. `p0` is where the wall starts, `dir` runs along it, `out` faces the street.
static func _door_wall(walls: Buf, p0: Vector3, dir: Vector2, length: float, out: Vector3, gh: float, opening: Dictionary, shopfront: Color) -> void:
	var along := Vector3(dir.x, 0, dir.y)
	var c: float = opening.t
	var half: float = float(opening.width) * 0.5
	var door_h: float = float(opening.height)
	var a := p0 + along * (c - half)
	var b := p0 + along * (c + half)
	var q0 := p0 + along * length
	var up := Vector3(0, gh, 0)
	var lintel := Vector3(0, door_h, 0)
	for side in 2:
		var nrm := out if side == 0 else -out
		var col := shopfront if side == 0 else INSIDE
		walls.quad(p0, a, a + up, p0 + up, nrm, col)           # left jamb
		walls.quad(b, q0, q0 + up, b + up, nrm, col)           # right jamb
		walls.quad(a + lintel, b + lintel, b + up, a + up, nrm, col)  # over the door


## A street as a ribbon along its centre line: the pavement out to the buildings on each side (`pave`: how far, [left,
## right]), with the carriageway on top and a coloured strip down the edge where the street has a bike lane or track (`bike`:
## ["lane" | "track" | "", ...], left and right: the way it is tagged in OpenStreetMap).
## What a street's paved with (its `surface`), as the colour it's drawn: asphalt where the map says nothing.
const SURFACES := {"asphalt": ASPHALT, "concrete": Color(0.52, 0.52, 0.52), "paving_stones": Color(0.55, 0.51, 0.47),
	"sett": Color(0.44, 0.41, 0.39), "cobblestone": Color(0.44, 0.41, 0.39), "unhewn_cobblestone": Color(0.47, 0.43, 0.38),
	"bricks": Color(0.56, 0.38, 0.32), "gravel": Color(0.62, 0.58, 0.50), "compacted": Color(0.60, 0.55, 0.47)}
const LANE_LINE := Color(0.86, 0.85, 0.80)
const DASH := Vector2(3.0, 9.0)  # a lane line's dash, and how far apart they start


static func _road(streets: Buf, pts: PackedVector2Array, width: float, cls: String, pave := [], bike := [], surface := "", lanes := 0) -> void:
	var paved := cls == "pedestrian"
	var side_w := width + (0.0 if paved else 3.4)
	var side_col: Color = SURFACES.get(surface, STONE).lerp(STONE, 0.4) if paved else SIDEWALK
	var road_col: Color = SURFACES.get(surface, ASPHALT)
	var reach := [side_w * 0.5, side_w * 0.5]  # how far the pavement runs out on the left and the right
	if pave.size() == 2:
		reach = [maxf(float(pave[0]), side_w * 0.5), maxf(float(pave[1]), side_w * 0.5)]
	for k in pts.size() - 1:
		var p := pts[k]
		var q := pts[k + 1]
		var e := q - p
		if e.length() < 0.1:
			continue
		var dir := e.normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var ext := dir * width * 0.35  # overlap the joints so corners don't gap
		if paved:  # level paving, wall to wall (a street with kerbs has its pavements raised: Kerbs, _kerbs)
			for side in 2:
				var sgn := 1.0 if side == 1 else -1.0  # the right-hand side is along +nrm
				_band(streets, p - ext, q + ext, nrm * sgn, 0.0, float(reach[side]), 0.015, side_col)
		else:
			_strip(streets, p - ext, q + ext, nrm, width * 0.5, 0.03, road_col)
			if lanes >= 2 and road_col == ASPHALT:  # (painted lines on asphalt: a dashed one between each lane)
				for lane in range(1, lanes):
					var off := -width * 0.5 + width * float(lane) / float(lanes)
					var t := 0.0
					while t + DASH.x <= e.length():
						var a := p + dir * t + nrm * off
						_strip(streets, a, a + dir * DASH.x, nrm, 0.07, 0.034, LANE_LINE)
						t += DASH.y
		for side in mini(bike.size(), 2):
			var kind := String(bike[side])
			if kind == "":
				continue
			var sgn := 1.0 if side == 1 else -1.0
			if kind == "lane":  # inside the carriageway, along its edge
				_band(streets, p - ext, q + ext, nrm * sgn, width * 0.5 - 1.5, width * 0.5, 0.04, BIKE_LANE)
			else:               # a track: on the pavement, beside the kerb
				_band(streets, p - ext, q + ext, nrm * sgn, width * 0.5, width * 0.5 + 1.8, Kerbs.HEIGHT + 0.01, BIKE_TRACK)


## The water (OsmWater): its surface, and a low stone wall along every edge where it meets land (a quay along the bank, a
## parapet along a bridge, the same rule), with an unseen wall above it in `bar` so nobody goes over.
static func _water(surface: Buf, walls: Buf, bar: Buf, water: Dictionary) -> void:
	for poly in water.get("pieces", []):
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a: Vector2 = poly[tris[t]]
			var b: Vector2 = poly[tris[t + 1]]
			var c: Vector2 = poly[tris[t + 2]]
			surface.tri(Vector3(a.x, WATER_Y, a.y), Vector3(b.x, WATER_Y, b.y), Vector3(c.x, WATER_Y, c.y), Vector3.UP, WATER)
	for e in water.get("edges", []):
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x) * QUAY_W * 0.5
		var a0 := a - d * QUAY_W * 0.5  # (a little past each end, so the corners close)
		var b0 := b + d * QUAY_W * 0.5
		var corners := [a0 + n, b0 + n, b0 - n, a0 - n]
		for i in 4:
			var p: Vector2 = corners[i]
			var q: Vector2 = corners[(i + 1) % 4]
			var out := Vector3((p + q).x * 0.5 - (a0 + b0).x * 0.5, 0.0, (p + q).y * 0.5 - (a0 + b0).y * 0.5).normalized()
			walls.quad(Vector3(p.x, 0.0, p.y), Vector3(q.x, 0.0, q.y), Vector3(q.x, QUAY_H, q.y), Vector3(p.x, QUAY_H, p.y), out, QUAY)
		var top := [Vector3(corners[0].x, QUAY_H, corners[0].y), Vector3(corners[1].x, QUAY_H, corners[1].y), Vector3(corners[2].x, QUAY_H, corners[2].y), Vector3(corners[3].x, QUAY_H, corners[3].y)]
		walls.quad(top[0], top[1], top[2], top[3], Vector3.UP, QUAY.lightened(0.08))
		bar.quad(Vector3(a.x, QUAY_H, a.y), Vector3(b.x, QUAY_H, b.y), Vector3(b.x, QUAY_BAR, b.y), Vector3(a.x, QUAY_BAR, a.y), Vector3(n.x, 0, n.y).normalized(), QUAY)


## The raised pavements: their tops, their sides down to the road, and a lighter kerb stone along each kerb line.
static func _kerbs(buf: Buf, kerbs: Kerbs) -> void:
	var h := Kerbs.HEIGHT
	for poly in kerbs.pieces:
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a := poly[tris[t]]
			var b := poly[tris[t + 1]]
			var c := poly[tris[t + 2]]
			buf.tri(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(c.x, h, c.y), Vector3.UP, SIDEWALK)
		for i in poly.size():  # (counter-clockwise: the outside of an edge a->b is to its right)
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var e := b - a
			if e.length() < 0.01:
				continue
			var out := Vector3(e.y, 0.0, -e.x).normalized()
			buf.quad(Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(b.x, h, b.y), Vector3(a.x, h, a.y), out, KERB_FACE)
	for e in kerbs.edges:
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var n: Vector2 = e.side * KERB_STONE_W  # (on the pavement, from the drop inward)
		var y := h + 0.004
		buf.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x + n.x, y, b.y + n.y), Vector3(a.x + n.x, y, a.y + n.y), Vector3.UP, KERB_STONE)


## A band along the street from `inner` to `outer` metres to one side of its centre line.
static func _band(streets: Buf, p: Vector2, q: Vector2, side: Vector2, inner: float, outer: float, y: float, col: Color) -> void:
	var a := p + side * inner
	var b := p + side * outer
	var c := q + side * outer
	var d := q + side * inner
	streets.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), Vector3.UP, col)


static func _strip(streets: Buf, p: Vector2, q: Vector2, nrm: Vector2, half: float, y: float, col: Color) -> void:
	var a := p + nrm * half
	var b := p - nrm * half
	var c := q - nrm * half
	var d := q + nrm * half
	streets.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), Vector3.UP, col)
