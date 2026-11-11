## CONTROLLER. The money gun in the player's hands. Hold fire to print bills: each is a real Bill in the
## model, and a paper projectile in the world. A bill that hits someone is delivered by its mode, and one
## that misses lands in the street for anyone to pick up (the player by walking over it, NPCs by fetching
## it). Two modes, changed with the scroll wheel:
##   GIFT    hold to spray $1 bills: money for nothing, earns rep
##   INVEST  hold to charge, release to spit an investment contract (the longer the charge, the bigger):
##           it buys a share of the business it hits, and is void anywhere else. It is never left on the ground.
##
## Hits are reported in bursts, so a stream of bills on one person reads as one line, not dozens.
class_name GunController
extends Node3D

signal applied(text: String)

const LAYER_WORLD := 1
const LAYER_NPC := 4
const LAYER_MACHINE := 8
const RANGE := 30.0
const MODES := ["gift", "invest"]
const MUZZLE_SPEED := 17.0
## Invest mode: a full charge takes this long, and a contract is worth from CONTRACT_MIN (at MIN_CHARGE) up to
## CONTRACT_MAX (a full charge), in whole $5. A trigger released before MIN_CHARGE just jams.
const CHARGE_TIME := 1.4
const MIN_CHARGE := 0.2
const CONTRACT_MIN := 25.0
const CONTRACT_MAX := 250.0

var mode := "gift"
var world: World
var camera: Camera3D
var bill_value := 1.0
var shots_per_second := 6.0
## How far the contract is charged, 0..1 (invest mode only).
var charge := 0.0
## Off until the player has the gun in their hands (the intro drops it at their feet).
var enabled := true
## Put away without being switched off (riding a bike): invisible, and it won't fire.
var suppressed := false
## Where floating text and flying bills are added; the game controller sets this.
var fx_root: Node

var rig: GunRig
var _cool := 0.0
var _report := {}  # Drone -> {gift, invest, voided, stake}: what hit them since the last report
var _report_in := 0.0


func setup(w: World, cam: Camera3D) -> GunController:
	world = w
	camera = cam
	name = "MoneyGun"
	rig = GunRig.new().setup()
	add_child(rig)
	return self


func toggle_mode() -> void:
	cycle_mode(1)


## What a contract is worth at charge `f` (0..1).
func contract_value(f: float) -> float:
	return snappedf(lerpf(CONTRACT_MIN, CONTRACT_MAX, clampf(f, 0.0, 1.0)), 5.0)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = enabled and not suppressed


func set_suppressed(on: bool) -> void:
	suppressed = on
	visible = enabled and not suppressed


## Steps through the modes (the scroll wheel): +1 next, -1 previous.
func cycle_mode(step: int) -> void:
	if not enabled:
		return
	mode = MODES[posmod(MODES.find(mode) + step, MODES.size())]
	charge = 0.0
	rig.charge = 0.0
	rig.set_mode(mode)


## Who the crosshair is on: {drone, point}, with drone null if it's on nothing the gun can pay.
func aim() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_basis.z * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_NPC | LAYER_MACHINE)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"drone": null, "point": to}
	var d: Drone = null
	var c: Object = hit.collider
	if c.has_meta("drone"):
		d = c.get_meta("drone")
	elif c.has_meta("drone_id"):
		d = world.drones[c.get_meta("drone_id")]
	return {"drone": d, "point": hit.position}


func _process(delta: float) -> void:
	step(enabled and not suppressed and Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, delta)
	_report_in -= delta
	if _report_in <= 0.0:
		_report_in = 0.4
		flush()


## Moves the gun on by `delta` with the trigger `held` or not. Gift mode sprays bills while held. Invest mode
## charges while held and, on release, spits a contract (or jams if the charge was too short).
func step(held: bool, delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	rig.set_mode(mode)  # keeps the rig in step if the mode was set directly
	if mode == "invest":
		if held:
			charge = minf(1.0, charge + delta / CHARGE_TIME)
		elif charge > 0.0:
			release()
		rig.charge = charge
	else:
		charge = 0.0
		rig.charge = 0.0
		if held and _cool <= 0.0:
			_cool = 1.0 / shots_per_second
			shoot()


## The trigger is let go: spit a contract of what has been charged, or jam. Returns the contract, or null.
func release() -> Contract:
	var f := charge
	charge = 0.0
	rig.charge = 0.0
	if f < MIN_CHARGE:
		rig.play_jam()
		return null
	return shoot_contract(contract_value(f))


## Prints one bill and sends it toward whatever the crosshair is on.
func shoot() -> Bill:
	var a := aim()
	rig.play_fire()
	var from := rig.muzzle.global_position
	var target: Vector3 = a.point
	var dir := (target - from).normalized()
	dir = dir.rotated(camera.global_basis.y, randf_range(-0.03, 0.03)).rotated(camera.global_basis.x, randf_range(-0.02, 0.04))
	var bill := world.gun.fire(bill_value, mode)
	var p := BillProjectile.new().launch(bill, world, from + dir * 0.5, dir * MUZZLE_SPEED * randf_range(0.92, 1.05), _on_hit)
	_fx().add_child(p)
	return bill


## Spits a contract worth `value` toward whatever the crosshair is on.
func shoot_contract(value: float) -> Contract:
	var a := aim()
	rig.play_fire()
	var from := rig.muzzle.global_position
	var dir: Vector3 = (a.point - from).normalized()
	dir = dir.rotated(camera.global_basis.y, randf_range(-0.01, 0.01)).rotated(camera.global_basis.x, randf_range(-0.005, 0.015))
	var c := world.gun.fire_contract(value)
	var p := ContractProjectile.new().launch(c, world, from + dir * 0.5, dir * MUZZLE_SPEED * 1.15, _on_hit)
	_fx().add_child(p)
	return c


## A bill or contract reached someone: note it for the next report.
func _on_hit(d: Drone, result: Dictionary) -> void:
	var r: Dictionary = _report.get(d, {"gift": 0.0, "invest": 0.0, "voided": 0.0, "stake": 0.0})
	match result.result:
		"gift":
			r.gift += result.amount
		"invest":
			r.invest += result.amount
			r.stake = result.stake
			r.voided += result.get("voided", 0.0)
		"void":
			r.voided += result.get("voided", 0.0)
			r.stake = result.stake
	_report[d] = r


## Says what the last burst did, once per person.
func flush() -> void:
	for d in _report:
		var r: Dictionary = _report[d]
		var parts: Array[String] = []
		if r.gift > 0.0:
			parts.append("gift $%d" % roundi(r.gift))
		if r.invest > 0.0:
			parts.append("invested $%d: you own %d%%" % [roundi(r.invest), roundi(r.stake * 100.0)])
		if r.voided > 0.0:
			if r.invest > 0.0:
				parts.append("$%d over the 49%% cap was void" % roundi(r.voided))
			elif r.stake < 0.0:
				parts.append("nothing to invest in")
			else:
				parts.append("you already own the 49% maximum")
		var text := ", ".join(parts)
		_float_text(d, text, r.invest > 0.0 or r.voided > 0.0)
		applied.emit("%s: %s" % [d.label if d.label != "" else d.kind, text])
	_report.clear()


## Hands someone a gift or an investment of `amount` straight away, with no flying bills. For scripted
## use (tests and the capture tool); returns a line describing what happened.
func apply(d: Drone, amount: float) -> String:
	var text := ""
	if mode == "gift":
		world.gun.gift(d, amount)
		text = "gift $%d" % roundi(amount)
	else:
		var r: Dictionary = world.gun.invest_ex(d, amount)
		if r.stake < 0.0:
			text = "nothing to invest in"
		elif r.accepted <= 0.0:
			text = "you already own the 49% maximum"
		else:
			text = "invested $%d: you own %d%%" % [roundi(r.accepted), roundi(r.stake * 100.0)]
	_float_text(d, text, mode == "invest")
	applied.emit("%s: %s" % [d.label if d.label != "" else d.kind, text])
	return text


func _fx() -> Node:
	return fx_root if fx_root != null else get_tree().root


func _float_text(d: Drone, text: String, investing: bool) -> void:
	var l := Look.label3d(_fx(), text, Vector3(d.pos.x, 2.4, d.pos.y), 44, 120.0)
	l.modulate = Color(0.55, 0.9, 0.6) if investing else Color(0.95, 0.88, 0.4)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", 3.6, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(l.queue_free)
