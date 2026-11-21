## VIEW PART. The medic: the builder's rig (so every animation is the same), dressed as a paramedic. Its colours are painted on
## the mesh's vertices, so the medic is that mesh with the colours swapped (the hi-vis vest a paramedic's green with silver
## bands, the hard hat a white helmet, the shirt white, the jeans dark green) and a red cross on a white patch on the chest.
## The recoloured mesh is made once and shared.
class_name MedicLook
extends RefCounted

const RIG := preload("res://assets/models/builder.glb")
## The builder's colours (as painted) -> the medic's.
const SWAP := {
	"ff2c02": Color(0.12, 0.42, 0.22),   # the vest: paramedic green
	"cfe21a": Color(0.86, 0.88, 0.9),    # its reflective bands: silver
	"e28c02": Color(0.95, 0.95, 0.93),   # the hard hat: a white helmet
	"0b2872": Color(0.93, 0.93, 0.95),   # the shirt: white
	"071131": Color(0.07, 0.18, 0.12),   # the jeans: dark green trousers
	"272b31": Color(0.85, 0.15, 0.15),   # the tool belt's pouches: red first-aid pouches
}
const CROSS_RED := Color(0.85, 0.1, 0.12)

static var _mesh: ArrayMesh = null


## A medic, ready to put in a view (like Look.model).
static func model() -> Node3D:
	var n: Node3D = Look.model(RIG)
	var mi: MeshInstance3D = _find_mesh(n)
	if mi != null:
		var mat := mi.mesh.surface_get_material(0)
		mi.mesh = _recoloured(mi.mesh)
		mi.mesh.surface_set_material(0, mat)
	return n


## The red cross on its white patch, to pin on the chest (it faces -z, like Emblem).
static func cross() -> Node3D:
	var root := Node3D.new()
	root.name = "MedicCross"
	root.add_child(_plate(Vector2(0.15, 0.15), Color(0.97, 0.97, 0.97), 0.0))
	root.add_child(_plate(Vector2(0.11, 0.035), CROSS_RED, -0.003))
	root.add_child(_plate(Vector2(0.035, 0.11), CROSS_RED, -0.003))
	return root


static func _recoloured(src: Mesh) -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var arrays := src.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in cols.size():
		var k := cols[i].to_html(false)
		if SWAP.has(k):
			cols[i] = SWAP[k]
	arrays[Mesh.ARRAY_COLOR] = cols
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null


static func _plate(size: Vector2, color: Color, z: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position.z = z
	mi.rotation.y = PI  # (a quad faces +z: turned to face -z, the front)
	return mi
