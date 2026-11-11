## VIEW. An investment contract in flight (see PaperProjectile): a cream sheet with a blue border, lines of
## small print, a gold ribbon and a red wax seal. Reaching a business it is handed to the model
## (Gun.hit_contract). Anywhere else it is void: it pops into paper confetti with "void" floating up, and
## nothing is left on the ground. It flies flatter and straighter than a bill.
class_name ContractProjectile
extends PaperProjectile

const PAPER := Color(0.98, 0.95, 0.85)
const BLUE := Color(0.25, 0.38, 0.72)
const RED := Color(0.78, 0.15, 0.17)
const GOLD := Color(0.92, 0.76, 0.28)

var contract: Contract


func launch(c: Contract, w: World, from: Vector3, vel: Vector3, hit_callback: Callable) -> ContractProjectile:
	contract = c
	gravity = 1.6
	drag = 0.5
	flutter = 1.5
	var model := _build()
	_start(w, model, from, vel, hit_callback)
	_spin = Vector3(0, randf_range(-3, 3), 0)
	rotation.x = -0.35
	return self


## The sheet, from boxes: border strips, small print, a ribbon and a seal.
static func _build() -> Node3D:
	var m := Node3D.new()
	Look.box(m, Vector3(0.34, 0.012, 0.46), Vector3.ZERO, PAPER)
	Look.box(m, Vector3(0.34, 0.014, 0.025), Vector3(0, 0.001, -0.2175), BLUE)
	Look.box(m, Vector3(0.34, 0.014, 0.025), Vector3(0, 0.001, 0.2175), BLUE)
	Look.box(m, Vector3(0.025, 0.014, 0.46), Vector3(-0.1575, 0.001, 0), BLUE)
	Look.box(m, Vector3(0.025, 0.014, 0.46), Vector3(0.1575, 0.001, 0), BLUE)
	for k in 5:
		Look.box(m, Vector3(0.2 if k < 4 else 0.12, 0.014, 0.012), Vector3(-0.02 if k < 4 else -0.06, 0.003, -0.15 + k * 0.045), BLUE.lightened(0.35))
	Look.box(m, Vector3(0.03, 0.016, 0.2), Vector3(-0.11, 0.004, 0.12), GOLD)
	Look.blob(m, Vector3(0.1, 0.035, 0.1), Vector3(0.07, 0.014, 0.15), RED)
	return m


func _scale_at(age: float) -> float:
	return lerpf(0.9, 2.2, clampf(age / 0.25, 0.0, 1.0))


func _deliver(d: Drone) -> void:
	var result := world.gun.hit_contract(contract, d)
	if on_hit.is_valid():
		on_hit.call(d, result)
	Effects.burst(get_parent(), global_position, [Color(0.98, 0.95, 0.85), Color(0.25, 0.38, 0.72, 0.0)], 12, 2.5, 0.05, 0.6)


func _miss(at: Vector2) -> void:
	world.gun.discard(contract)
	var root_node := get_parent()
	var p := Vector3(at.x, maxf(global_position.y, 0.3), at.y)
	Effects.burst(root_node, p, [Color(0.98, 0.95, 0.85), Color(0.25, 0.38, 0.72, 0.0)], 22, 3.0, 0.06, 0.8)
	var l := Look.label3d(root_node, "void", p + Vector3(0, 0.3, 0), 34, 60.0)
	l.modulate = Color(0.85, 0.85, 0.9)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(l.queue_free)
