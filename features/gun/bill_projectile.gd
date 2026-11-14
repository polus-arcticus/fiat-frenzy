## VIEW. A printed bill in flight (see PaperProjectile). A bill that hits a person is delivered by the model
## (Gun.hit); one that hits the ground or a wall comes down in the street as loose cash (Gun.land).
class_name BillProjectile
extends PaperProjectile

const BILL := preload("res://assets/models/bill.glb")

var bill: Bill


func launch(b: Bill, w: World, from: Vector3, vel: Vector3, hit_callback: Callable) -> BillProjectile:
	bill = b
	var model := Look.model(BILL)
	model.scale = Vector3.ONE * 0.9
	_start(w, model, from, vel, hit_callback)
	return self


func _scale_at(age: float) -> float:
	return lerpf(0.9, 3.0, clampf(age / 0.3, 0.0, 1.0))  # small at the muzzle, so it doesn't fill the screen


func _deliver(d: Drone) -> void:
	var result := world.gun.hit(bill, d)
	if on_hit.is_valid():
		on_hit.call(d, result)


func _miss(at: Vector2) -> void:
	world.gun.land(bill, at)
