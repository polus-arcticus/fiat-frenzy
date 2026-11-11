## VIEW. A teleporter ring: a glowing hoop standing on the ground with a faintly swirling pane inside it, and
## a label saying where it goes. Walking through is the model's business (Portals); this only draws.
class_name PortalView
extends Node3D

const RADIUS := 1.3
const HEIGHT := 1.35  # the ring's middle above the ground

var portal: Portal
var _swirl: MeshInstance3D
var _t := 0.0


func setup(p: Portal) -> PortalView:
	portal = p
	name = "Portal"
	position = Vector3(p.pos.x, 0.0, p.pos.y)
	rotation.y = p.exit_yaw()  # the ring's local -Z is its front, the way you come out

	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.18
	torus.outer_radius = RADIUS
	torus.rings = 32
	torus.ring_segments = 10
	hoop.mesh = torus
	hoop.rotation.x = PI / 2.0  # a torus lies flat; stand it up
	hoop.position.y = HEIGHT
	hoop.material_override = _glow(Color(0.45, 0.8, 1.0, 1.0), 1.0)
	add_child(hoop)

	var pane := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS - 0.18
	disc.bottom_radius = RADIUS - 0.18
	disc.height = 0.02
	pane.mesh = disc
	pane.rotation.x = PI / 2.0
	pane.position.y = HEIGHT
	pane.material_override = _glow(Color(0.55, 0.45, 1.0, 0.28), 0.28)
	add_child(pane)

	_swirl = MeshInstance3D.new()  # a thin offset ring that turns inside, so it reads as alive
	var inner := TorusMesh.new()
	inner.inner_radius = 0.5
	inner.outer_radius = 0.56
	inner.rings = 24
	inner.ring_segments = 6
	_swirl.mesh = inner
	_swirl.position.y = HEIGHT
	_swirl.material_override = _glow(Color(0.8, 0.9, 1.0, 0.6), 0.6)
	add_child(_swirl)

	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position.y = HEIGHT
	add_child(light)
	Look.label3d(self, p.label, Vector3(0, HEIGHT * 2.0 + 0.5, 0), 28)
	return self


func _process(delta: float) -> void:
	_t += delta
	_swirl.rotation = Vector3(PI / 2.0 + sin(_t * 1.3) * 0.5, _t * 1.8, cos(_t * 0.9) * 0.4)
	_swirl.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 2.2))


static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
