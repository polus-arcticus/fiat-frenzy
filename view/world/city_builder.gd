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
const GLASS := Color(0.24, 0.30, 0.38)
const LIT := Color(1.0, 0.82, 0.45)
const ASPHALT := Color(0.30, 0.30, 0.34)
const SIDEWALK := Color(0.66, 0.62, 0.55)
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
		_road(streets, _pts(r.pts), float(r.w), String(r["class"]))
	for bd in district.buildings:
		_building(bd, walls, windows, lit, roofs, streets, openings.get(int(bd.id), {}))

	var root := Node3D.new()
	root.name = "City"
	var mat := Watercolor.surface()
	var layers := {"Ground": ground, "Streets": streets, "Walls": walls, "Windows": windows, "Roofs": roofs}
	for key in layers:
		var mi := MeshInstance3D.new()
		mi.name = key
		mi.mesh = layers[key].to_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["Ground", "Streets", "Windows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	wall_shape.set_faces(walls.faces())
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


static func _building(bd: Dictionary, walls: Buf, windows: Buf, lit: Buf, roofs: Buf, floors: Buf, opening := {}) -> void:
	var pts := _pts(bd.poly)
	var h: float = bd.h
	var id: int = bd.id
	var kind: String = bd.kind
	var levels: int = bd.levels
	var plaster := _tint(PALETTE[absi(id) % PALETTE.size()], id)
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
		if h > gh:
			walls.quad(p0 + Vector3(0, gh, 0), q0 + Vector3(0, gh, 0), q0 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), out, plaster)
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
				if y1 > h - 0.3:
					break
				var warm := rng.randf() < 0.22
				var buf := lit if warm else windows
				var col := LIT if warm else _tint(GLASS, id * 31 + w * 7 + f, 0.12)
				buf.quad(c3 - along * hw + Vector3(0, y0, 0), c3 + along * hw + Vector3(0, y0, 0),
					c3 + along * hw + Vector3(0, y1, 0), c3 - along * hw + Vector3(0, y1, 0), out, col)
	var tris := Geometry2D.triangulate_polygon(pts)
	var roof_col := _tint(ROOFS[absi(id) % ROOFS.size()], id + 5)
	for k in range(0, tris.size(), 3):
		var a := pts[tris[k]]
		var bb := pts[tris[k + 1]]
		var cc := pts[tris[k + 2]]
		roofs.tri(Vector3(a.x, h, a.y), Vector3(bb.x, h, bb.y), Vector3(cc.x, h, cc.y), Vector3.UP, roof_col)
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


## A street as a ribbon along its centre line: a wide sidewalk strip with the carriageway on top.
static func _road(streets: Buf, pts: PackedVector2Array, width: float, cls: String) -> void:
	var paved := cls == "pedestrian"
	var side_w := width + (0.0 if paved else 3.4)
	var side_col := STONE if paved else SIDEWALK
	for k in pts.size() - 1:
		var p := pts[k]
		var q := pts[k + 1]
		var e := q - p
		if e.length() < 0.1:
			continue
		var dir := e.normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var ext := dir * width * 0.35  # overlap the joints so corners don't gap
		_strip(streets, p - ext, q + ext, nrm, side_w * 0.5, 0.015, side_col)
		if not paved:
			_strip(streets, p - ext, q + ext, nrm, width * 0.5, 0.03, ASPHALT)


static func _strip(streets: Buf, p: Vector2, q: Vector2, nrm: Vector2, half: float, y: float, col: Color) -> void:
	var a := p + nrm * half
	var b := p - nrm * half
	var c := q - nrm * half
	var d := q + nrm * half
	streets.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), Vector3.UP, col)
