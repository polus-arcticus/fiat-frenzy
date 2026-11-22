## VIEW. Turns a tile's dressing (OsmDressing: the green, woods, trees) into meshes laid on the ground under the streets. In two
## halves, so the long one can run off the main thread:
## - `bake`: the geometry, as plain arrays (no nodes, no servers: safe on a worker thread);
## - `assemble`: the nodes and meshes from that (quick; on the main thread).
## Nothing here is solid or known to the sim. (The water is: CityBuilder draws it, from OsmWater.)
class_name DressingBuilder
extends RefCounted

const COLORS := {"green": Color(0.52, 0.66, 0.40), "pitch": Color(0.44, 0.62, 0.42), "wood": Color(0.34, 0.50, 0.31)}
const HEIGHT := {"green": 0.005, "pitch": 0.007, "wood": 0.006}  # (under the water, the streets and the pavements)
const TRUNK := Color(0.42, 0.32, 0.24)
const CROWN := Color(0.31, 0.52, 0.31)


## The geometry of `dress`: {ground: CityBuilder.Buf, tree: CityBuilder.Buf, trees: [Transform3D]}.
static func bake(dress: Dictionary, tile_key := "") -> Dictionary:
	var ground := CityBuilder.Buf.new()
	for a in dress.get("areas", []):
		var poly: PackedVector2Array = a.poly
		var tris := Geometry2D.triangulate_polygon(poly)
		var y: float = HEIGHT[a.kind]
		var col: Color = COLORS[a.kind]
		for k in range(0, tris.size(), 3):
			var p := poly[tris[k]]
			var q := poly[tris[k + 1]]
			var r := poly[tris[k + 2]]
			ground.tri(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(r.x, y, r.y), Vector3.UP, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile_key + "/trees")
	var trees := {}  # crown -> [Transform3D]: each tree a crown of its own, the same for everyone in the tile
	for p in dress.get("trees", PackedVector2Array()):
		var crown: String = Solids.NAMES[rng.randi() % Solids.NAMES.size()]
		var s := rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		if not trees.has(crown):
			trees[crown] = []
		trees[crown].append(Transform3D(basis, Ground.at(p)))  # (on a pavement, on top of it)
	var meshes := {}
	for crown in trees:
		meshes[crown] = _tree(crown)
	return {"ground": ground, "tree": meshes, "trees": trees}


## The nodes for a baked dressing, under one Node3D named "Dressing".
static func assemble(baked: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	var mat := Watercolor.surface()
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = (baked.ground as CityBuilder.Buf).to_mesh()
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	var trees := Node3D.new()
	trees.name = "Trees"
	root.add_child(trees)
	for crown in baked.trees:
		var places: Array = baked.trees[crown]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = (baked.tree[crown] as CityBuilder.Buf).to_mesh()
		mm.instance_count = places.size()
		for k in places.size():
			mm.set_instance_transform(k, places[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = crown.capitalize()
		mmi.multimesh = mm
		mmi.material_override = mat
		trees.add_child(mmi)
	return root


## How many trees a baked dressing has, of every crown.
static func tree_count(baked: Dictionary) -> int:
	var n := 0
	for crown in baked.trees:
		n += (baked.trees[crown] as Array).size()
	return n


## A crown's size (to its corners) for each solid, so they read as about the same bulk.
const CROWN_RADIUS := {"tetrahedron": 2.2, "cube": 1.7, "octahedron": 1.9, "dodecahedron": 1.75, "icosahedron": 1.8,
	"cuboctahedron": 1.8, "icosidodecahedron": 1.75}
const CROWN_AT := 3.5  # the crown's middle, above the ground


# One tree, at the origin: a square trunk and a crown that is one of the Solids.
static func _tree(crown: String) -> CityBuilder.Buf:
	var b := CityBuilder.Buf.new()
	var t := 0.16
	var h := CROWN_AT - 0.6  # (up into the crown)
	for side in 4:
		var a := Vector2(t, t).rotated(side * PI * 0.5)
		var c := Vector2(t, t).rotated((side + 1) * PI * 0.5)
		var out := Vector3((a + c).x, 0, (a + c).y).normalized()
		b.quad(Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(c.x, h, c.y), Vector3(a.x, h, a.y), out, TRUNK)
	Solids.add(b, crown, Vector3(0, CROWN_AT, 0), float(CROWN_RADIUS[crown]), CROWN)
	return b
