## VIEW PART. The four little bars over a drone's head: money (green) above hunger, thirst and warmth, so who is broke
## shows from across the street: an empty money bar, and no dark notches. The dark strip above it has a notch for every
## order of magnitude of money (see Wealth: $10, $100, $1,000, $10,000) and the bar fills toward the next. It faces the
## camera, and drops down beside someone who is lying down. Reads a Drone; owns nothing.
class_name BarsRig
extends Node3D

const BAR_W := 0.62
const BAR_H := 0.07
const COLORS := {"money": Color(0.32, 0.74, 0.36), "hunger": Color(0.9, 0.58, 0.22), "thirst": Color(0.28, 0.62, 0.92), "warmth": Color(0.93, 0.32, 0.24)}
const STANDING_Y := 2.48
const LYING_Y := 1.2

const TIER := Color(0.16, 0.52, 0.28)  # the dark strip above the money bar: one notch per order of magnitude
const BORDER := Color(0.97, 0.95, 0.88, 0.96)  # a pale frame round every bar, so the dark green (and the rest) stands out from its backing

var _fills := {}  # bar name -> the quad whose width shows the level
var _tier: MeshInstance3D
var _tier_back: MeshInstance3D
var _tier_border: MeshInstance3D


func _init() -> void:
	name = "Bars"
	position = Vector3(0, STANDING_Y, 0)
	var row := 0
	for key in ["money", "hunger", "thirst", "warmth"]:
		var y := -row * (BAR_H + 0.03)
		_quad(Vector3(0, y, 0), 0.0, BORDER, -1, BAR_W + 0.08, BAR_H + 0.07)
		_quad(Vector3(0, y, 0), 0.0, Color(0.1, 0.09, 0.14, 1.0), 0, BAR_W + 0.04, BAR_H + 0.03)
		_fills[key] = _quad(Vector3(-BAR_W * 0.5, y, 0.002), BAR_W * 0.5, COLORS[key], 1, BAR_W, BAR_H)
		row += 1
	var ty := BAR_H * 0.5 + 0.045
	_tier_border = _quad(Vector3(0, ty, 0), 0.0, BORDER, -1, BAR_W + 0.08, 0.09)
	_tier_back = _quad(Vector3(0, ty, 0), 0.0, Color(0.1, 0.09, 0.14, 1.0), 0, BAR_W + 0.04, 0.05)
	_tier = _quad(Vector3(-BAR_W * 0.5, ty, 0.002), BAR_W * 0.5, TIER, 1, BAR_W, 0.035)


## A flat quad. `anchor` shifts the mesh so scaling x grows it from the left edge.
func _quad(at: Vector3, anchor: float, color: Color, priority: int, w: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.center_offset = Vector3(anchor, 0, 0)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = priority
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 18.0
	add_child(mi)
	return mi


## Fills the bars from the drone, turns to face `camera`, and hides when `shown` is false.
func refresh(drone: Drone, shown: bool, camera: Camera3D) -> void:
	if camera != null:
		global_basis = camera.global_basis
	for key in _fills:
		var level: float = Wealth.progress(drone.wallet) if key == "money" else drone.bars[key]
		_fills[key].scale.x = maxf(0.001, level)
		_fills[key].get_parent().visible = shown
	_tier.scale.x = maxf(0.001, float(Wealth.tiers(drone.wallet)) / float(Wealth.MAX_TIER))
	_tier.visible = shown
	_tier_back.visible = shown
	_tier_border.visible = shown


## Moves toward the lying-down height (k is how far to ease this frame).
func lower(lying: bool, k: float) -> void:
	position.y = lerpf(position.y, LYING_Y if lying else STANDING_Y, k)
