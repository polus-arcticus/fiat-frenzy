## CONTROLLER. Putting a tent or a barrel fire down, as in Planet Crafter: a see-through ghost of it stands on the ground where the
## crosshair points (no further than Placing.REACH), green where it can go and red where it can't. Left click puts it down; right
## click or Esc puts it back in the bag. The gun is held while placing. The rules are Placing's: this only shows and asks.
class_name PlacementController
extends Node

const OK := Color(0.3, 0.9, 0.4, 0.45)
const NO := Color(0.95, 0.3, 0.25, 0.45)

var world: World
var player: PlayerController
var gun: GunController
var hud: Hud
var item := ""  # what is being placed, or "" when not placing

var _ghost: Node3D
var _mat: StandardMaterial3D
var _at := Vector2.ZERO
var _front := Vector2(0, 1)


func setup(w: World, p: PlayerController, g: GunController, h: Hud) -> PlacementController:
	world = w
	player = p
	gun = g
	hud = h
	name = "Placement"
	return self


func placing() -> bool:
	return item != ""


## Starts placing one `item` from the bag.
func begin(what: String) -> void:
	cancel()
	item = what
	gun.set_suppressed(true)
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost = Node3D.new()
	var mesh := MeshInstance3D.new()
	if item == "tent":
		var prism := PrismMesh.new()
		prism.size = Vector3(1.84, 1.25, 2.6)
		mesh.mesh = prism
		mesh.position.y = 0.625
	elif item == "camp_kit":  # (the camp's stall, its footprint)
		var box := BoxMesh.new()
		box.size = Vector3(2.4, 1.6, 1.8)
		mesh.mesh = box
		mesh.position.y = 0.8
	else:
		var barrel := CylinderMesh.new()
		barrel.top_radius = 0.33
		barrel.bottom_radius = 0.33
		barrel.height = 0.9
		mesh.mesh = barrel
		mesh.position.y = 0.45
	mesh.material_override = _mat
	_ghost.add_child(mesh)
	add_child(_ghost)
	_update()


## Stops placing; the item stays in the bag.
func cancel() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if item != "":
		item = ""
		gun.set_suppressed(false)
		hud.show_prompt("")


## Puts it down where the ghost stands, if it can go there. Returns {ok, text}.
func confirm() -> Dictionary:
	_update()
	var r := world.placing.place(item, _at, _front)
	hud.notify(r.text)
	if r.ok:
		cancel()
	return r


## Where the crosshair meets the ground, no further than the reach: where the ghost stands.
func target() -> Vector2:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var here := world.player.pos
	var spot := here + Vector2(dir.x, dir.z).normalized() * 3.0
	if dir.y < -0.02:
		var hit := from + dir * (-from.y / dir.y)
		spot = Vector2(hit.x, hit.z)
	var reach := Placing.REACH - 0.3
	if spot.distance_to(here) > reach:
		spot = here + (spot - here).normalized() * reach
	return spot


func _update() -> void:
	_at = target()
	var to_hero := world.player.pos - _at
	_front = to_hero.normalized() if to_hero.length() > 0.01 else Vector2(0, 1)  # (a tent opens toward the hero)
	_ghost.position = Ground.at(_at, 0.02)
	_ghost.rotation.y = atan2(-_front.x, -_front.y)
	var why := world.placing.why_not(item, _at)
	_mat.albedo_color = OK if why == "" else NO
	var thing := item.replace("_", " ")
	hud.show_prompt(("LMB  put the %s down   ·   RMB  cancel" % thing) if why == "" else ("%s   ·   RMB  cancel" % why))


func _process(_delta: float) -> void:
	if item == "":
		return
	if not player.controls_enabled or world.player.carry.count(item) < 1:  # (a screen opened, or it's gone from the bag)
		cancel()
		return
	_update()


func _input(e: InputEvent) -> void:  # (before the screen stack, which would take Esc to free the mouse)
	if item == "" or not player.controls_enabled:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		confirm()
		get_viewport().set_input_as_handled()
	elif (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT) or e.is_action_pressed("release"):
		cancel()
		get_viewport().set_input_as_handled()
