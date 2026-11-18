## VIEW. The sky and sun, driven by the model's clock: sunrise at 6am, sunset when night falls, a dim
## blue moon after. The sky is painted (assets/shaders/sky.gdshader: soft washes, toon clouds, a sun with a halo, stars at night),
## warm at dawn and dusk and clear blue at noon. Also switches the warm lit windows on at night.
class_name DayNight
extends Node3D

const DAY_TOP := Color(0.42, 0.62, 0.86)
const DAY_HORIZON := Color(0.82, 0.86, 0.9)
const DUSK_HORIZON := Color(1.0, 0.7, 0.48)
const DUSK_TOP := Color(0.55, 0.56, 0.86)
const NIGHT_TOP := Color(0.02, 0.03, 0.09)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.18)

var sun: DirectionalLight3D
var env: Environment
var _sky_mat: ShaderMaterial
var lit_windows: Node3D


func _ready() -> void:
	name = "Sky"
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://assets/shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0006
	env.fog_sky_affect = 0.0  # the fog hazes the far buildings, not the sky itself (or the sky would be one flat colour)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## `frac` is Clock.fraction(): 0 at 6am, Clock.NIGHT_FROM at sunset.
func update(frac: float) -> void:
	var day_t := clampf(frac / Clock.NIGHT_FROM, 0.0, 1.0)
	var elevation := deg_to_rad(26.0) + sin(PI * day_t) * deg_to_rad(40.0)  # never so low the banded shading blotches
	var is_day := frac < Clock.NIGHT_FROM
	var daylight := clampf(sin(PI * day_t) * 2.5, 0.0, 1.0) if is_day else 0.0
	var low := 1.0 - clampf(sin(PI * day_t) * 2.2, 0.0, 1.0)  # near the horizon
	sun.rotation = Vector3(-(elevation if is_day else deg_to_rad(35.0)), deg_to_rad(-50.0 + day_t * 100.0), 0)
	sun.light_energy = lerpf(0.1, 1.15, daylight)
	sun.light_color = Color(0.7, 0.78, 1.0).lerp(Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.7, 0.45), low), daylight)
	# dawn and dusk: a lavender top over a peach horizon; noon: clear blue washing out to pale at the horizon; night: deep blue
	var lit := clampf(daylight * 2.4, 0.0, 1.0)  # twilight is already bright: the sky does not wait for full day to turn from night
	var top := NIGHT_TOP.lerp(DAY_TOP.lerp(DUSK_TOP, low * 0.85), lit)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON.lerp(DUSK_HORIZON, low * 0.9), lit)
	var dawn_dusk := low * clampf(daylight * 4.0, 0.0, 1.0)  # the glow: strongest with the sun low, and gone at night
	_sky_mat.set_shader_parameter("top_color", top)
	_sky_mat.set_shader_parameter("horizon_color", horizon)
	_sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.35))
	_sky_mat.set_shader_parameter("glow", clampf(dawn_dusk, 0.0, 1.0))
	_sky_mat.set_shader_parameter("glow_color", Color(1.0, 0.66, 0.42))
	_sky_mat.set_shader_parameter("night", 1.0 - clampf(daylight * 2.5, 0.0, 1.0))
	_sky_mat.set_shader_parameter("cloud_lit", Color(0.2, 0.23, 0.42).lerp(Color(1.0, 0.98, 0.95).lerp(Color(1.0, 0.85, 0.7), low * 0.8), clampf(daylight * 1.5, 0.0, 1.0)))
	_sky_mat.set_shader_parameter("cloud_shade", Color(0.07, 0.08, 0.17).lerp(Color(0.66, 0.72, 0.86).lerp(Color(0.78, 0.6, 0.72), low * 0.7), clampf(daylight * 1.5, 0.0, 1.0)))
	_sky_mat.set_shader_parameter("cloud_cover", (0.5 + 0.08 * sin(frac * 9.0)) * lerpf(0.55, 1.0, lit))  # fewer at night
	_sky_mat.set_shader_parameter("drift", frac * 6.0)
	env.ambient_light_energy = lerpf(0.22, 0.62, daylight)
	env.fog_light_color = horizon
	if lit_windows:
		lit_windows.visible = daylight < 0.35
