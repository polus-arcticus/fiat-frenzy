## VIEW. A tall translucent beacon the tutorial plants where it wants the player to go.
class_name MarkerView
extends Node3D

var _label: Label3D
var _mesh: MeshInstance3D


func _ready() -> void:
	name = "Marker"
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 14.0
	_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.28)
	mat.no_depth_test = false
	_mesh.material_override = mat
	_mesh.position.y = 7.0
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_label = Look.label3d(self, "", Vector3(0, 14.8, 0), 40)
	visible = false


## Far targets (past FAR, beyond what the camera can see) are shown FAR metres out along the way to them, so
## the beacon still points the right way; the label keeps the real distance.
const FAR := 400.0


func point_at(pos: Vector2, text: String, from := Vector2(INF, INF)) -> void:
	if from.is_finite() and from.distance_to(pos) > FAR:
		pos = from + (pos - from).normalized() * FAR
	position = Vector3(pos.x, 0, pos.y)
	_label.text = text
	visible = true


func hide_marker() -> void:
	visible = false
