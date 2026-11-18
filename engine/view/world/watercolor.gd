## Applies the watercolour look: one shared surface material for every vertex-coloured mesh
## from the Blender pipeline, and the full-screen post quad for the camera.
class_name Watercolor
extends RefCounted

const SURFACE_SHADER := preload("res://shaders/watercolor_surface.gdshader")
const POST_SHADER := preload("res://shaders/watercolor_post.gdshader")

static var _surface: ShaderMaterial
static var _glow: ShaderMaterial
static var _textures: Dictionary[String, NoiseTexture2D] = {}


static func noise(key: String, size: int, frequency: float, octaves: int = 4) -> NoiseTexture2D:
	if _textures.has(key):
		return _textures[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = key.hash()
	n.frequency = frequency
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	_textures[key] = t
	return t


static func surface() -> ShaderMaterial:
	if _surface == null:
		_surface = ShaderMaterial.new()
		_surface.shader = SURFACE_SHADER
		_surface.set_shader_parameter("pigment_noise", noise("pigment", 256, 0.02))
	return _surface


## Same look but self-lit, for lamps, embers, and anything that should read as glowing.
static func glowing() -> ShaderMaterial:
	if _glow == null:
		_glow = surface().duplicate()
		_glow.set_shader_parameter("emission_strength", 1.6)
	return _glow


static func apply(root: Node, material: Material = null) -> void:
	var mat: Material = material if material else surface()
	if root is MeshInstance3D:
		root.material_override = mat
	for c in root.get_children():
		apply(c, mat)


static func make_post_quad() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	mat.set_shader_parameter("paper_noise", noise("paper", 512, 0.006, 5))
	mat.set_shader_parameter("grain_tex", noise("grain", 256, 0.35, 2))
	# The screen texture is captured before the transparent pass, so this quad must draw first
	# among transparents; otherwise it paints over labels, particles and smoke.
	mat.render_priority = Material.RENDER_PRIORITY_MIN
	var mi := MeshInstance3D.new()
	mi.name = "WatercolorPost"
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
