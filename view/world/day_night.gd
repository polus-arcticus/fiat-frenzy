## VIEW. The sky and sun, driven by the model's clock: sunrise at 6am, sunset when night falls, a dim
## blue moon after. Also switches the warm lit windows on at night.
class_name DayNight
extends Node3D

const DAY_TOP := Color(0.42, 0.62, 0.86)
const DAY_HORIZON := Color(0.82, 0.86, 0.9)
const DUSK_HORIZON := Color(0.95, 0.62, 0.42)
const NIGHT_TOP := Color(0.02, 0.03, 0.09)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.18)

var sun: DirectionalLight3D
var env: Environment
var _sky_mat: ProceduralSkyMaterial
var lit_windows: Node3D


func _ready() -> void:
	name = "Sky"
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0006
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
	var top := NIGHT_TOP.lerp(DAY_TOP, daylight)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON.lerp(DUSK_HORIZON, low * 0.8), daylight)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = top.darkened(0.3)
	env.ambient_light_energy = lerpf(0.22, 0.62, daylight)
	env.fog_light_color = horizon
	if lit_windows:
		lit_windows.visible = daylight < 0.35
