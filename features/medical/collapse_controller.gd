## CONTROLLER. What passing out means for the player. The model decides when the player collapses, when the
## ambulance has them and when the medical tent has them on their feet again (see Rescue). This takes
## away control and fades the screen to black while that happens, carries the player's body to the tent
## and back out, and gives control back when they wake. It only reacts to the model's state.
class_name CollapseController
extends CanvasLayer

const FADE_OUT := 1.6
const FADE_IN := 2.2

var world: World
var player: PlayerController
var hud: Hud
var screens: ScreenStack
var gun: GunController

## While out cold the screen is not quite black: a dim, warm red-brown, like eyelids with the light coming through
## them, that breathes slowly.
const EYELIDS := Color(0.17, 0.045, 0.035, 0.93)

var _shade: ColorRect
var _t := 0.0
var _last := ""
var _gun_was_on := true
var _tween: Tween
## Skips the fades (tests that step the sim without frames).
var instant := false


func setup(w: World, p: PlayerController, h: Hud, s: ScreenStack, g: GunController) -> CollapseController:
	world = w
	player = p
	hud = h
	screens = s
	gun = g
	layer = 5  # over the world, under the HUD, so the captions still show
	_shade = ColorRect.new()
	_shade.color = EYELIDS
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.modulate.a = 0.0
	add_child(_shade)
	return self


func _process(delta: float) -> void:
	if _last == "":
		return
	_t += delta
	_shade.color.a = EYELIDS.a + 0.045 * sin(_t * 1.1)
	_shade.color.r = EYELIDS.r + 0.03 * (0.5 + 0.5 * sin(_t * 0.7))  # a flicker of light through the lids


## Called every frame by the game controller, before it copies the body's position into the model.
func update() -> void:
	var care := world.player.care
	if care == _last:
		return
	var before := _last
	_last = care
	if care == "down":
		_pass_out()
	elif care == "patient":
		_to_bed()
	elif care == "" and before != "":
		_wake_up()


## The screen goes dark and the controls stop. Close anything open first: closing a screen hands the
## controls back.
func _pass_out() -> void:
	world.rescue.last_mugged = 0.0
	screens.close_all()
	player.controls_enabled = false
	_gun_was_on = gun.enabled
	gun.set_enabled(false)
	_fade(1.0, FADE_OUT)
	hud.show_caption("You pass out...", 3.0)


## The ambulance has brought them in: their body is moved to the cot while the screen is still dark.
func _to_bed() -> void:
	_put_body_at_the_tent()
	hud.show_caption("Somebody lifts you onto a cot.", 3.0)


func _wake_up() -> void:
	_put_body_at_the_tent()
	player.controls_enabled = true
	gun.set_enabled(_gun_was_on)
	_fade(0.0, FADE_IN)
	var lost := world.rescue.last_mugged
	if lost > 0.0:
		hud.show_caption("You wake on a cot by the medical tent. Your pockets are empty: someone took your $%d. Eat and drink!" % roundi(lost), 6.0)
	else:
		hud.show_caption("You wake up by the medical tent. Eat and drink!", 4.5)


## The body goes to where the model put the player, facing the way the tent does (out to the street).
func _put_body_at_the_tent() -> void:
	world.hero.stand()
	player.stand()  # (someone who passed out on the bus is lifted out of their seat)
	player.scripted = false
	world.transit.disembark()
	var at := world.player.pos
	var yaw := 0.0
	if not world.hospitals.is_empty():
		var f := world.hospitals[0].front
		yaw = atan2(-f.x, -f.y)
	player.teleport(Vector3(at.x, 0.1, at.y), yaw)
	player.level_gaze()


func _fade(alpha: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	if instant:
		_shade.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_shade, "modulate:a", alpha, seconds)
