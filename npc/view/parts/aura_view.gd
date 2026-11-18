## VIEW. A soft gold glow round someone who needs the player's help (see Attention): a tall translucent column of
## light around them that breathes slowly, so it can be seen from down the street without hiding the person inside it.
class_name AuraView
extends MeshInstance3D

const GOLD := Color(1.0, 0.8, 0.25)

var _mat: StandardMaterial3D
var _t := randf() * TAU


func _init() -> void:
	name = "Aura"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.85
	cyl.height = 2.5
	mesh = cyl
	position.y = 1.25
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.2)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta * 2.2
	_mat.albedo_color.a = 0.16 + 0.08 * sin(_t)
