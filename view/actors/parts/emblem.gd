## VIEW PART. Mr. Nobody's badge: a small red shield pinned to the lapel of his jacket, with a pale border, and the
## lapel itself (a darker flap of cloth from collar to chest). Built from polygons, so it needs no model. It faces
## front (-z) and is meant to be noticed only up close. The pin is about 8 cm by 10 cm.
class_name Emblem
extends Node3D

const RED := Color(0.78, 0.1, 0.12)
const BORDER := Color(0.96, 0.92, 0.82)
const CLOTH := Color(0.13, 0.14, 0.24)

## The outline of a heater shield, about 0.34 m wide by 0.42 m high, centre at the origin.
const SHIELD := [Vector2(-0.17, 0.2), Vector2(0.17, 0.2), Vector2(0.17, 0.0), Vector2(0.12, -0.12), Vector2(0.0, -0.22), Vector2(-0.12, -0.12), Vector2(-0.17, 0.0)]
## The lapel: from the collar down to the first button and out to the shoulder, about 0.2 m wide by 0.3 m high.
const LAPEL := [Vector2(0.0, 0.15), Vector2(-0.2, 0.1), Vector2(-0.13, 0.0), Vector2(-0.17, -0.07), Vector2(-0.03, -0.15)]


func _init() -> void:
	name = "Emblem"
	_plate(LAPEL, 1.0, CLOTH, Vector2.ZERO, 0.0)
	# the pin sits on the lapel, a little above its middle
	_plate(SHIELD, 0.2, BORDER, Vector2(-0.1, 0.02), -0.003)
	_plate(SHIELD, 0.16, RED, Vector2(-0.1, 0.02), -0.006)


func _plate(outline: Array, scale_by: float, color: Color, at: Vector2, z: float) -> void:
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(p * scale_by)
	var tris := Geometry2D.triangulate_polygon(pts)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in tris:
		verts.append(Vector3(pts[i].x + at.x, pts[i].y + at.y, 0.0))
		norms.append(Vector3(0, 0, -1))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Look.tinted(color)
	mi.position.z = z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
