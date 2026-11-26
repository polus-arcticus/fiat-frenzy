## VIEW. A piece of paper in flight, the common part of a printed bill and an investment contract: it falls
## slowly, flutters, and is slowed by the air. Each frame it ray-casts along its path. If it hits a person (or
## their stand) the subclass hands it to the model; if it hits the ground or a wall, or its time runs out,
## the subclass says what a miss means. The money (or the offer) is the model's; this node is only its flight.
class_name PaperProjectile
extends Node3D

const MASK := 1 | 4 | 8  # world, people, stands
const LIFETIME := 5.0

var world: World
var velocity := Vector3.ZERO
var on_hit: Callable  # (drone: Drone, result: Dictionary)
var gravity := 3.2
var drag := 0.9
var flutter := 4.0   # how hard the air shoves it about

## The vehicle, when this was fired from a seat in it. Then the flight is in its own frame (it falls straight down inside, as
## it would on a moving bus, and is not left streaming behind it), and what it lands on inside stays there (see
## Gun.land_aboard). Out through the open door it is in the street's frame again, with the vehicle's speed.
var frame: VehicleView = null

var _age := 0.0
var _spin := Vector3.ZERO
var _model: Node3D
var _local := Vector3.ZERO   # where it is in the bus's frame, while it is in it


## Starts the flight. `model` is what it looks like.
func _start(w: World, model: Node3D, from: Vector3, vel: Vector3, hit_callback: Callable) -> void:
	world = w
	velocity = vel
	on_hit = hit_callback
	position = from
	_spin = Vector3(randf_range(-12, 12), randf_range(-5, 5), randf_range(-12, 12))
	_model = model
	add_child(_model)


## How big it is this far into the flight (subclasses grow it from small at the muzzle).
func _scale_at(_age_s: float) -> float:
	return 1.0


## It reached `d`. Subclasses hand it to the model and tell `on_hit`.
func _deliver(_d: Drone) -> void:
	pass


## It came down, or ran out of air, at `at` on the ground plane.
func _miss(_at: Vector2) -> void:
	pass


## It came down on the floor of the vehicle `v`, at `local` in its own coordinates. (By default that is just a miss, wherever
## that floor is in the world just now: a contract that misses is void whatever it lands on.)
func _miss_aboard(v: Vehicle, local: Vector2) -> void:
	_miss(v.to_world(local))


func _ready() -> void:
	if world != null and world.hero.mode == Hero.Mode.SEATED:
		for view in get_tree().get_nodes_in_group(VehicleView.CABIN):
			if view.model() != null and view.model().aboard:
				frame = view
	if frame != null:
		_local = frame.to_local(global_position)
		velocity = frame.global_basis.inverse() * velocity  # (it leaves the muzzle at the hero's own pace: already the bus's)


func _physics_process(delta: float) -> void:
	_age += delta
	_model.scale = Vector3.ONE * _scale_at(_age)
	velocity.y -= gravity * delta
	if _age > 0.3:  # paper flutter: a little lift and random sideways shoves
		velocity += Vector3(randf_range(-1, 1), randf_range(0.0, 0.7), randf_range(-1, 1)) * flutter * delta
	velocity *= maxf(0.0, 1.0 - drag * delta)
	var from := global_position
	var to := from + velocity * delta
	var next := _local + velocity * delta
	if frame != null:
		from = frame.to_global(_local)  # (both ends with the bus where it is now: only the paper's own motion is swept)
		to = frame.to_global(next)
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_resolve(hit)
		return
	global_position = to
	rotate(_spin.normalized(), _spin.length() * delta * 0.2)
	if frame != null:
		_local = next
		var size := frame.model().spec()
		if absf(next.x) > float(size.width) * 0.5 + 0.05 or absf(next.z) > float(size.length) * 0.5 or next.y > frame.ceiling_height() + 0.1:
			velocity = frame.global_basis * velocity + frame.velocity()  # out of the open door: the street's frame, at its speed
			frame = null
		elif _age > LIFETIME:
			_miss_aboard(frame.model(), Vector2(next.x, next.z))
			queue_free()
		return
	if to.y <= 0.04 or _age > LIFETIME:
		_miss(Vector2(to.x, to.z))
		queue_free()


func _resolve(hit: Dictionary) -> void:
	var c: Object = hit.collider
	var d: Drone = null
	if c.has_meta("drone"):
		d = c.get_meta("drone")
	elif c.has_meta("drone_uid"):
		d = world.drone(c.get_meta("drone_uid"))
	if d != null:
		_deliver(d)
		queue_free()
		return
	if frame != null and c.has_meta(VehicleView.CABIN):  # fired from inside, it hit its floor or a wall: it lands in the vehicle
		var at := frame.to_local(hit.position)
		var out: Vector3 = frame.global_basis.inverse() * hit.normal
		_miss_aboard(frame.model(), frame.model().on_the_floor(Vector2(at.x, at.z) + Vector2(out.x, out.z) * 0.4))
		queue_free()
		return
	var p: Vector3 = hit.position
	var n: Vector3 = hit.normal
	_miss(Vector2(p.x, p.z) + Vector2(n.x, n.z) * 0.5)  # off a wall, it slides down to the street
	queue_free()
