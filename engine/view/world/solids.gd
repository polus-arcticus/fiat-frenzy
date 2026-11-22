## VIEW. Convex solids for the low-poly look: the five Platonic solids and two Archimedean ones (the cuboctahedron and the
## icosidodecahedron), each from its vertices (the textbook coordinates, scaled to a radius of 1). Faces are found as the
## planes every other vertex lies behind, so each comes out flat, whole and facing out: a tree's crown (DressingBuilder).
class_name Solids
extends RefCounted

const PHI := 1.6180339887
const NAMES := ["tetrahedron", "cube", "octahedron", "dodecahedron", "icosahedron", "cuboctahedron", "icosidodecahedron"]

static var _faces := {}  # name -> [[Vector3, ...] one per face, in order round it], made once


## The solid's vertices, at radius 1.
static func vertices(name: String) -> PackedVector3Array:
	var v: Array[Vector3] = []
	match name:
		"tetrahedron":
			v = [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
		"cube":
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						v.append(Vector3(x, y, z))
		"octahedron":
			for s in [-1, 1]:
				v.append_array([Vector3(s, 0, 0), Vector3(0, s, 0), Vector3(0, 0, s)])
		"icosahedron":
			v = _cyclic(_signs(Vector3(0, 1, PHI)))
		"dodecahedron":
			v = _signs(Vector3(1, 1, 1))
			v.append_array(_cyclic(_signs(Vector3(0, 1.0 / PHI, PHI))))
		"cuboctahedron":
			v = _cyclic(_signs(Vector3(1, 1, 0)))
		"icosidodecahedron":
			v = _cyclic(_signs(Vector3(0, 0, PHI)))
			v.append_array(_cyclic(_signs(Vector3(0.5, PHI * 0.5, PHI * PHI * 0.5))))
	var out := PackedVector3Array()
	var seen := {}
	for p in v:
		var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
		if not seen.has(key):
			seen[key] = true
			out.append(p.normalized())
	return out


## The faces of the solid, each its corners in order round it (counter-clockwise seen from outside).
static func faces(name: String) -> Array:
	if not _faces.has(name):
		_faces[name] = _hull(vertices(name))
	return _faces[name]


## Adds the solid to `buf`, centred at `at`, `radius` across to its corners, every face flat and `color` (a touch darker
## the further it faces down, for the shape to read).
static func add(buf: CityBuilder.Buf, name: String, at: Vector3, radius: float, color: Color) -> void:
	for f in faces(name):
		var n: Vector3 = (f[1] - f[0]).cross(f[2] - f[0]).normalized()
		if n.dot(f[0]) < 0.0:
			n = -n  # (out from the middle: the solid is centred on it)
		var shade := color.darkened(0.18 * clampf(-n.y, 0.0, 1.0))
		for k in range(1, f.size() - 1):
			buf.tri(at + f[0] * radius, at + f[k] * radius, at + f[k + 1] * radius, n, shade)


# Every face of the convex hull of `pts`: a plane through three of them with all the rest behind it, its corners the points
# on it, sorted round its middle.
static func _hull(pts: PackedVector3Array) -> Array:
	var planes: Array = []
	var out: Array = []
	var n := pts.size()
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var normal := (pts[j] - pts[i]).cross(pts[k] - pts[i])
				if normal.length() < 1e-6:
					continue
				normal = normal.normalized()
				var d := normal.dot(pts[i])
				if d < 0.0:
					normal = -normal
					d = -d
				if planes.any(func(p): return p.n.distance_to(normal) < 1e-4):
					continue
				var on: Array[Vector3] = []
				var outside := false
				for p in pts:
					var s := normal.dot(p) - d
					if s > 1e-4:
						outside = true
						break
					if absf(s) <= 1e-4:
						on.append(p)
				if outside:
					continue
				planes.append({"n": normal})
				out.append(_round(on, normal))
	return out


# The points of a face in order round its middle, counter-clockwise seen from outside (along -normal).
static func _round(on: Array[Vector3], normal: Vector3) -> Array:
	var mid := Vector3.ZERO
	for p in on:
		mid += p
	mid /= on.size()
	var u := (on[0] - mid).normalized()
	var w := normal.cross(u)
	var sorted := on.duplicate()
	sorted.sort_custom(func(a, b): return atan2((a - mid).dot(w), (a - mid).dot(u)) < atan2((b - mid).dot(w), (b - mid).dot(u)))
	return sorted


# A point with every choice of sign on its non-zero coordinates.
static func _signs(p: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in ([-1, 1] if p.x != 0.0 else [1]):
		for sy in ([-1, 1] if p.y != 0.0 else [1]):
			for sz in ([-1, 1] if p.z != 0.0 else [1]):
				out.append(Vector3(p.x * sx, p.y * sy, p.z * sz))
	return out


# The three cyclic turns of each point's coordinates (x, y, z), (y, z, x), (z, x, y).
static func _cyclic(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in pts:
		out.append_array([p, Vector3(p.y, p.z, p.x), Vector3(p.z, p.x, p.y)])
	return out
