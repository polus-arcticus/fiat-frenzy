## VIEW. A district's street furniture (StreetThings) as meshes: each kind of thing one small low-poly model, instanced wherever
## it stands (one draw for every lamp in the tile), the painted crossings and the hedges, walls and fences merged as strips.
## Lamp heads and the pools of light under them are switched on at night (group "night_lights": DayNight). In two halves, as
## the city is: `bake` (plain arrays: a worker thread may run it) and `assemble` (the nodes, on the main thread).
class_name StreetThingsBuilder
extends RefCounted

const METAL := Color(0.30, 0.31, 0.34)
const LAMP_GLOW := Color(1.0, 0.84, 0.5)
const POOL := Color(1.0, 0.78, 0.42, 0.45)
const GLASS := Color(0.62, 0.70, 0.76)
const SIGN_RED := Color(0.78, 0.16, 0.14)
const WHITE := Color(0.92, 0.91, 0.88)
const WOOD := Color(0.52, 0.36, 0.24)
const BIN := Color(0.20, 0.34, 0.24)
const HEDGE := Color(0.32, 0.48, 0.30)
const WALL := Color(0.66, 0.60, 0.52)
const FENCE := Color(0.46, 0.42, 0.38)
const STRIPE := Color(0.90, 0.89, 0.85)
const LINE_SIZE := {"hedge": Vector2(0.9, 1.1), "wall": Vector2(0.35, 1.5), "fence": Vector2(0.06, 1.3)}  # width, height
const LAMP_HEAD := Vector3(0.0, 4.4, -0.75)  # where a lamp's light is, on the model


## {meshes: kind -> Buf, places: kind -> [Transform3D], heads: [Transform3D], flat: Buf (crossings), lines: Buf, solid: Buf}.
static func bake(things: Dictionary) -> Dictionary:
	var places := {}
	var heads: Array[Transform3D] = []
	var flat := CityBuilder.Buf.new()
	for t in things.get("things", []):
		var at: Vector2 = t.at
		if t.kind == "crossing":
			_zebra(flat, at, float(t.yaw), float(t.width))
			continue
		var xf := Transform3D(Basis(Vector3.UP, float(t.yaw)), Ground.at(at))
		if not places.has(t.kind):
			places[t.kind] = []
		places[t.kind].append(xf)
		if t.kind == "lamp":
			heads.append(xf)
	var meshes := {}
	for kind in places:
		meshes[kind] = model(kind)
	var lines := CityBuilder.Buf.new()
	var solid := CityBuilder.Buf.new()
	for l in things.get("lines", []):
		_line(lines, solid, l.pts, str(l.kind))
	return {"meshes": meshes, "places": places, "heads": heads, "flat": flat, "lines": lines, "solid": solid}


## The nodes: one MultiMesh a kind, the strips, the night's lights, and a body for the hedges and walls.
static func assemble(baked: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "StreetThings"
	var mat := Watercolor.surface()
	for kind in baked.places:
		root.add_child(_many(str(kind).capitalize(), (baked.meshes[kind] as CityBuilder.Buf).to_mesh(), baked.places[kind], mat))
	for key in ["flat", "lines"]:
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize()
		mi.mesh = (baked[key] as CityBuilder.Buf).to_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key == "flat" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
	var heads: Array = baked.heads
	if not heads.is_empty():
		var glow := _many("LampLights", _head().to_mesh(), heads, Watercolor.glowing())
		glow.add_to_group("night_lights")
		glow.visible = false
		root.add_child(glow)
		var pools := _many("LightPools", _pool(), heads, _pool_material())
		pools.add_to_group("night_lights")
		pools.visible = false
		pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pools)
	var faces := (baked.solid as CityBuilder.Buf).faces()
	if not faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	return root


## How many triangles a kind's model has (the furniture is meant to stay cheap: tests hold it to that).
static func triangles(kind: String) -> int:
	return model(kind).i.size() / 3


## One thing's model, standing at the origin, its front (what faces the road) toward -Z.
static func model(kind: String) -> CityBuilder.Buf:
	var b := CityBuilder.Buf.new()
	match kind:
		"lamp":
			_box(b, Vector3(-0.07, 0, -0.07), Vector3(0.07, 4.6, 0.07), METAL)          # the pole
			_box(b, Vector3(-0.04, 4.45, -0.8), Vector3(0.04, 4.55, 0.0), METAL)        # its arm, over the road
			_box(b, Vector3(-0.2, 4.3, -0.95), Vector3(0.2, 4.45, -0.55), METAL.darkened(0.2))  # the lamp's hood
		"bus_stop", "tram_stop":
			_box(b, Vector3(-1.5, 0.15, 0.55), Vector3(1.5, 2.3, 0.6), GLASS)           # the back, glass
			_box(b, Vector3(-1.5, 0.15, -0.3), Vector3(-1.45, 2.3, 0.6), GLASS)         # a side
			_box(b, Vector3(-1.6, 2.3, -0.5), Vector3(1.6, 2.42, 0.75), METAL)          # the roof
			for x in [-1.5, 1.5]:
				_box(b, Vector3(x - 0.04, 0, 0.5), Vector3(x + 0.04, 2.3, 0.58), METAL)
			_box(b, Vector3(-1.0, 0.42, 0.25), Vector3(1.0, 0.48, 0.5), WOOD)           # a bench inside
			_box(b, Vector3(1.9, 0, -0.55), Vector3(1.96, 2.5, -0.49), METAL)          # the sign's pole
			_disc(b, Vector3(1.93, 2.55, -0.52), 0.3, Color(0.95, 0.78, 0.15) if kind == "bus_stop" else SIGN_RED)
		"stop_sign":
			_box(b, Vector3(-0.03, 0, -0.03), Vector3(0.03, 2.1, 0.03), METAL)
			_disc(b, Vector3(0, 2.3, -0.05), 0.33, SIGN_RED)
		"give_way":
			_box(b, Vector3(-0.03, 0, -0.03), Vector3(0.03, 2.0, 0.03), METAL)
			b.tri(Vector3(-0.38, 2.5, -0.05), Vector3(0.38, 2.5, -0.05), Vector3(0, 1.85, -0.05), Vector3.FORWARD, WHITE)
		"traffic_light":
			_box(b, Vector3(-0.05, 0, -0.05), Vector3(0.05, 3.0, 0.05), METAL)
			_box(b, Vector3(-0.16, 2.2, -0.2), Vector3(0.16, 3.1, 0.0), METAL.darkened(0.3))
			for k in 3:
				_disc(b, Vector3(0, 2.95 - k * 0.3, -0.21), 0.1, [SIGN_RED, Color(0.95, 0.62, 0.1), Color(0.2, 0.75, 0.35)][k])
		"bike_stand":
			for x in [-0.9, 0.0, 0.9]:  # three hoops
				_box(b, Vector3(x - 0.03, 0, -0.35), Vector3(x + 0.03, 0.8, -0.29), METAL)
				_box(b, Vector3(x - 0.03, 0, 0.29), Vector3(x + 0.03, 0.8, 0.35), METAL)
				_box(b, Vector3(x - 0.03, 0.8, -0.35), Vector3(x + 0.03, 0.86, 0.35), METAL)
		"bench":
			_box(b, Vector3(-0.9, 0.42, -0.22), Vector3(0.9, 0.48, 0.22), WOOD)
			_box(b, Vector3(-0.9, 0.5, 0.2), Vector3(0.9, 0.9, 0.25), WOOD)
			for x in [-0.8, 0.8]:
				_box(b, Vector3(x - 0.04, 0, -0.2), Vector3(x + 0.04, 0.42, 0.2), METAL)
		"bin":
			_prism(b, Vector3.ZERO, 0.28, 0.9, 6, BIN)
		"recycling":  # a row of three bins: green glass, blue paper, white glass
			for k in 3:
				var x := -1.5 + k * 1.5
				_box(b, Vector3(x - 0.65, 0, -0.55), Vector3(x + 0.65, 1.45, 0.55), [Color(0.24, 0.50, 0.30), Color(0.22, 0.36, 0.62), Color(0.86, 0.86, 0.82)][k])
				_box(b, Vector3(x - 0.6, 1.45, -0.5), Vector3(x + 0.6, 1.6, 0.5), METAL)
	return b


# A zebra crossing across the road at `at` (`yaw` the road's way, `width` its width): white stripes along the traffic.
static func _zebra(buf: CityBuilder.Buf, at: Vector2, yaw: float, width: float) -> void:
	var along := Vector2(-sin(yaw), -cos(yaw))  # (the road's direction)
	var across := Vector2(-along.y, along.x)
	var y := 0.037
	var t := -width * 0.5 + 0.4
	while t <= width * 0.5 - 0.4:
		var c := at + across * t
		var a := c - along * 1.5 - across * 0.25
		var b := c + along * 1.5 - across * 0.25
		var d := c + along * 1.5 + across * 0.25
		var e := c - along * 1.5 + across * 0.25
		buf.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(d.x, y, d.y), Vector3(e.x, y, e.y), Vector3.UP, STRIPE)
		t += 1.0


# A hedge, wall or fence along a line: a long box per segment (a fence: posts and two rails). Hedges and walls are solid.
static func _line(buf: CityBuilder.Buf, solid: CityBuilder.Buf, pts: PackedVector2Array, kind: String) -> void:
	var size: Vector2 = LINE_SIZE[kind]
	var col: Color = {"hedge": HEDGE, "wall": WALL, "fence": FENCE}[kind]
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var length := a.distance_to(b)
		if length < 0.1:
			continue
		var dir := (b - a) / length
		var n := Vector2(-dir.y, dir.x) * size.x * 0.5
		var y0 := Ground.y((a + b) * 0.5)
		if kind == "fence":
			var t := 0.0
			while t <= length:
				var p := a + dir * t
				_box(buf, Vector3(p.x - 0.04, y0, p.y - 0.04), Vector3(p.x + 0.04, y0 + size.y, p.y + 0.04), col)
				t += 2.5
			for h in [0.45, 1.1]:
				_slab(buf, a, b, Vector2(-dir.y, dir.x) * 0.02, y0 + h, y0 + h + 0.08, col)
			continue
		_slab(buf, a, b, n, y0, y0 + size.y, col)
		_slab(solid, a, b, n, y0, y0 + size.y, col)


# A long box from a to b, `n` its half-width across, from y0 to y1: its sides and top.
static func _slab(buf: CityBuilder.Buf, a: Vector2, b: Vector2, n: Vector2, y0: float, y1: float, col: Color) -> void:
	var c := [a + n, b + n, b - n, a - n]
	var mid := (a + b) * 0.5
	for i in 4:
		var p: Vector2 = c[i]
		var q: Vector2 = c[(i + 1) % 4]
		var out := Vector3((p + q).x * 0.5 - mid.x, 0, (p + q).y * 0.5 - mid.y).normalized()
		buf.quad(Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y1, q.y), Vector3(p.x, y1, p.y), out, col)
	buf.quad(Vector3(c[0].x, y1, c[0].y), Vector3(c[1].x, y1, c[1].y), Vector3(c[2].x, y1, c[2].y), Vector3(c[3].x, y1, c[3].y), Vector3.UP, col.lightened(0.08))


# An axis-aligned box from `lo` to `hi`: five faces (not its bottom).
static func _box(buf: CityBuilder.Buf, lo: Vector3, hi: Vector3, col: Color) -> void:
	var p := [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(hi.x, 0, hi.z), Vector3(lo.x, 0, hi.z)]
	var normals := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i in 4:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		buf.quad(a + Vector3(0, lo.y, 0), b + Vector3(0, lo.y, 0), b + Vector3(0, hi.y, 0), a + Vector3(0, hi.y, 0), normals[i], col)
	buf.quad(p[0] + Vector3(0, hi.y, 0), p[1] + Vector3(0, hi.y, 0), p[2] + Vector3(0, hi.y, 0), p[3] + Vector3(0, hi.y, 0), Vector3.UP, col.lightened(0.06))


# A flat round plate (an octagon) facing -Z, centred at `c`.
static func _disc(buf: CityBuilder.Buf, c: Vector3, r: float, col: Color) -> void:
	for k in 8:
		var a := c + Vector3(cos(k * TAU / 8.0 + PI / 8.0), sin(k * TAU / 8.0 + PI / 8.0), 0) * r
		var b := c + Vector3(cos((k + 1) * TAU / 8.0 + PI / 8.0), sin((k + 1) * TAU / 8.0 + PI / 8.0), 0) * r
		buf.tri(c, a, b, Vector3.FORWARD, col)


# An upright n-sided prism (a bin): its sides and top.
static func _prism(buf: CityBuilder.Buf, base: Vector3, r: float, h: float, n: int, col: Color) -> void:
	for k in n:
		var a := base + Vector3(cos(k * TAU / n), 0, sin(k * TAU / n)) * r
		var b := base + Vector3(cos((k + 1) * TAU / n), 0, sin((k + 1) * TAU / n)) * r
		var out := ((a + b) * 0.5 - base).normalized()
		buf.quad(a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), out, col)
		buf.tri(base + Vector3(0, h, 0), a + Vector3(0, h, 0), b + Vector3(0, h, 0), Vector3.UP, col.lightened(0.1))


# A lamp's glowing glass (the night's), where the hood is.
static func _head() -> CityBuilder.Buf:
	var b := CityBuilder.Buf.new()
	var c := LAMP_HEAD
	b.quad(c + Vector3(-0.17, -0.02, -0.18), c + Vector3(0.17, -0.02, -0.18), c + Vector3(0.17, -0.02, 0.18), c + Vector3(-0.17, -0.02, 0.18), Vector3.DOWN, LAMP_GLOW)
	return b


# The pool of light on the ground under a lamp: bright under it, fading to nothing at its rim (a colour a corner, so it's
# built here, not as a Buf's one colour a triangle).
static func _pool() -> ArrayMesh:
	var c := Vector3(LAMP_HEAD.x, 0.05, LAMP_HEAD.z)
	var v := PackedVector3Array([c])
	var col := PackedColorArray([POOL])
	var idx := PackedInt32Array()
	var n := 14
	for k in n:
		v.append(c + Vector3(cos(k * TAU / n), 0, sin(k * TAU / n)) * 4.2)
		col.append(Color(POOL, 0.0))
		idx.append_array([0, 1 + (k + 1) % n, 1 + k])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _pool_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _many(name: String, mesh: Mesh, places: Array, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = places.size()
	for k in places.size():
		mm.set_instance_transform(k, places[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi
