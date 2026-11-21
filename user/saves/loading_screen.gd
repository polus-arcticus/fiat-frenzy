## VIEW. The loading screen is a little cinematic, in the manner of a game's own trailer rather than a progress bar: a skater
## rolls down the street at sunset, pops a kickflip, and sprays money at a crowd of silhouettes who throw their hands up.
## It is drawn by hand (flat shapes, a screenprint palette, no assets), so it plays while the game builds behind it.
##
## The one thing that blocks is the build itself, so the cinematic holds its best frame (the board edge-on at the top of the
## flip) while the city is made, and plays out the landing and the shower of bills as soon as the game is up (`release`).
## A layer of its own on top of everything, parented to the tree's root so it survives the change of scene.
class_name LoadingScreen
extends CanvasLayer

signal finished

const HOLD_AT := 2.05      # the instant it freezes on while the game builds: the board edge-on, the bills in the air
const FLIP_START := 1.45
const FLIP_TIME := 1.0
const SPRAY_START := 1.55
const BILLS := 56
const OUT_AT := 4.1        # when, after release, the picture is gone
const TIPS := [
	"Hold left mouse to print money. Try it on the locals.",
	"Money that misses lands in the street. Anyone can pick it up.",
	"Scroll the wheel to switch from gifting to investing.",
	"A stake in a business pays you forever.",
	"Nights are cold. A barrel fire warms whoever stands near it.",
	"Press B on a skateboard. Press jump twice for a kickflip. It pays $25.",
	"Anyone with a gold glow needs your help.",
]
const SKY_TOP := Color("#2b1d4a")
const SKY_MID := Color("#d8456b")
const SKY_LOW := Color("#ffb24a")
const INK := Color("#120d1f")
const BILL := Color("#58c26a")
const BILL_DARK := Color("#2f7d3f")
const CREAM := Color("#fff2cf")

const PRINTING := "PRINTING THE DISTRICT..."

var progress := 0.0   # 0..1, set by whoever is loading
var caption := PRINTING  # what it says it is doing
var holding := false  # waiting for the build: freeze on the best frame

var _t := 0.0
var _released := -1.0 # the time of release, or -1
var _canvas: Control
var _tip := TIPS[0]
var _rng := RandomNumberGenerator.new()
var _bills: Array[Dictionary] = []
var _people: Array[Dictionary] = []
var _towers: Array[Dictionary] = []


func _init() -> void:
	layer = 100
	_rng.seed = 5
	_tip = TIPS[randi() % TIPS.size()]
	for i in BILLS:
		_bills.append({"at": SPRAY_START + i * 0.034, "vx": _rng.randf_range(520.0, 980.0), "vy": _rng.randf_range(-380.0, -60.0),
			"spin": _rng.randf_range(-9.0, 9.0), "phase": _rng.randf() * TAU, "drift": _rng.randf_range(-40.0, 40.0)})
	for i in 5:
		_people.append({"x": 0.62 + i * 0.075, "h": _rng.randf_range(150.0, 190.0), "late": i * 0.07, "hat": i % 3})
	var x := -40.0
	while x < 1700.0:
		var w := _rng.randf_range(70.0, 150.0)
		_towers.append({"x": x, "w": w, "h": _rng.randf_range(120.0, 330.0), "tone": _rng.randf_range(0.0, 1.0), "seed": _rng.randi()})
		x += w + _rng.randf_range(-10.0, 18.0)


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing clicks through to the menu underneath
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)


func _process(delta: float) -> void:
	if holding and _t >= HOLD_AT:
		_t = HOLD_AT
	else:
		_t += delta
	if _released >= 0.0 and _t - _released > OUT_AT:
		finished.emit()
		queue_free()
		return
	if _released >= 0.0:  # the picture clears away to show the game
		_canvas.modulate.a = clampf((OUT_AT - (_t - _released)) / 0.6, 0.0, 1.0)
	_canvas.queue_redraw()


## The game is up: let the cinematic play out and go.
func release() -> void:
	holding = false
	if _released < 0.0:
		_released = _t


# ---------------------------------------------------------------- drawing
# Everything is laid out for a 1600 x 900 picture and scaled to the window.

func _draw_all() -> void:
	var s := Vector2(_canvas.size)
	var k := s.y / 900.0
	var offset := Vector2((s.x - 1600.0 * k) * 0.5, 0.0)
	_canvas.draw_set_transform(offset, 0.0, Vector2(k, k))
	var shake := 0.0
	if holding and _t >= HOLD_AT:
		shake = 1.5
	if shake > 0.0:
		_canvas.draw_set_transform(offset + Vector2(sin(Time.get_ticks_msec() * 0.05), cos(Time.get_ticks_msec() * 0.07)) * shake, 0.0, Vector2(k, k))
	_sky(s.x / k, offset.x / -k)
	_skyline()
	_street()
	var base := _skater_state(_t)
	_crowd(base)
	_bills_in_flight(base)
	_skater(base)
	_foreground_bills()
	_letterbox(s, k, offset)
	_title()
	_bar()
	_fade()


func _sky(w: float, margin: float) -> void:
	var x0 := -margin - 10.0
	var width := w + 20.0
	var bands := 24
	for i in bands:
		var f := float(i) / bands
		var c := SKY_TOP.lerp(SKY_MID, clampf(f * 1.7, 0.0, 1.0)) if f < 0.58 else SKY_MID.lerp(SKY_LOW, (f - 0.58) / 0.42)
		_canvas.draw_rect(Rect2(x0, f * 640.0, width, 640.0 / bands + 1.0), c)
	# the sun, with the screenprint rings round it
	var sun := Vector2(800.0 + sin(_t * 0.3) * 6.0, 520.0)
	for r in [260.0, 215.0, 170.0]:
		_canvas.draw_circle(sun, r, Color(1.0, 0.85, 0.5, 0.10))
	_canvas.draw_circle(sun, 128.0, Color("#ffe08a"))
	for i in 7:  # the slats that cut across the sun
		_canvas.draw_rect(Rect2(sun.x - 140.0, sun.y - 10.0 + i * 20.0, 280.0, 3.0 + i * 1.6), SKY_LOW.lerp(SKY_MID, 0.35))
	# halftone dots in the upper sky
	for row in 9:
		for col in 40:
			var p := Vector2(x0 + col * 44.0 + (row % 2) * 22.0, 20.0 + row * 34.0)
			_canvas.draw_circle(p, maxf(0.0, 4.5 - row * 0.5), Color(1, 1, 1, 0.07))


func _skyline() -> void:
	var scroll := fmod(_t * 14.0, 1.0)  # the far city drifts a hair, as the camera tracks the skater
	for t in _towers:
		var x: float = t.x - scroll * 0.0 - _t * 10.0 + 40.0
		var h: float = t.h
		var col := INK.lerp(Color("#3a2150"), t.tone * 0.55)
		_canvas.draw_rect(Rect2(x, 640.0 - h, t.w, h + 10.0), col)
		var wr := RandomNumberGenerator.new()
		wr.seed = t.seed
		var rows := int(h / 22.0)
		for r in rows:
			for c in int(t.w / 18.0):
				if wr.randf() < 0.28:
					_canvas.draw_rect(Rect2(x + 6.0 + c * 18.0, 640.0 - h + 10.0 + r * 22.0, 8.0, 10.0), Color("#ffd470", 0.85))
	# the two towers everyone knows: the Commerzbank's triangle and the bank's twin slabs
	_canvas.draw_colored_polygon(PackedVector2Array([Vector2(1180, 640), Vector2(1245, 250), Vector2(1310, 640)]), Color("#1a1030"))
	_canvas.draw_rect(Rect2(1050, 640 - 470, 38, 470), Color("#1a1030"))
	_canvas.draw_rect(Rect2(1092, 640 - 430, 38, 430), Color("#1a1030"))
	_canvas.draw_rect(Rect2(1050, 640 - 330, 80, 8), Color("#ffd470"))


func _street() -> void:
	_canvas.draw_rect(Rect2(-400, 640, 2400, 300), INK)
	_canvas.draw_rect(Rect2(-400, 640, 2400, 10), Color("#6b3f78"))
	# the kerb stripes rushing by, so the skater visibly rolls
	var step := 120.0
	var shift := fposmod(_t * 520.0, step)
	for i in 20:
		var x := i * step - shift
		_canvas.draw_rect(Rect2(x, 780.0, 70.0, 6.0), Color("#fff2cf", 0.5))
	for i in 12:  # puddle shine
		var x2 := fposmod(i * 190.0 - _t * 150.0, 1900.0) - 150.0
		_canvas.draw_rect(Rect2(x2, 700.0 + (i % 3) * 16.0, 80.0, 3.0), Color("#ff9d5c", 0.25))


## Where the skater is, how high, and how far round the flip, at this moment.
func _skater_state(t: float) -> Dictionary:
	var ground := 716.0
	var x: float
	var lift := 0.0
	var air := 0.0  # 0..1 through the jump
	if t < 1.3:
		x = lerpf(-160.0, 560.0, _ease_out(t / 1.3))
	else:
		var u := clampf((t - 1.3) / 1.45, 0.0, 1.0)  # the jump takes 1.45 s
		x = 560.0 + u * 400.0
		lift = 4.0 * u * (1.0 - u) * 230.0
		air = u
	if t > 2.75:
		x = 960.0 + (t - 2.75) * 380.0  # rolls on out, past the crowd's feet
	var flip := clampf((t - FLIP_START) / FLIP_TIME, 0.0, 1.0)
	return {"x": x, "y": ground - lift, "lift": lift, "air": air, "flip": flip * TAU, "bob": sin(t * 17.0) * (1.0 - minf(air * 4.0, 1.0)) * 3.0}


func _ease_out(f: float) -> float:
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 2.4)


func _skater(b: Dictionary) -> void:
	var p := Vector2(b.x, b.y + b.bob)
	var air: float = b.air
	var lean := lerpf(0.0, -0.12, minf(air * 3.0, 1.0)) + (0.1 if air > 0.85 else 0.0)
	var crouch := 1.0 - minf(air * 3.5, 1.0) * 0.7
	# the shadow on the street, shrinking as they rise
	var shade := clampf(1.0 - float(b.lift) / 300.0, 0.3, 1.0)
	_canvas.draw_set_transform(Vector2(b.x, 740.0), 0.0, Vector2(shade, shade * 0.22))
	_canvas.draw_circle(Vector2.ZERO, 90.0, Color(0, 0, 0, 0.45))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the board: its flip is a turn about its long axis, so it squashes edge-on and shows the other face
	var f: float = b.flip
	var thick := cos(f)
	var board_c := p + Vector2(0, 8)
	var half := 84.0
	var deck_h := 14.0 * absf(thick) + 5.0
	var face := Color("#ffcf3a") if thick >= 0.0 else Color("#ff4f81")
	_canvas.draw_rect(Rect2(board_c.x - half, board_c.y - deck_h * 0.5, half * 2.0, deck_h), face)
	_canvas.draw_rect(Rect2(board_c.x - half, board_c.y - deck_h * 0.5, half * 2.0, deck_h), INK, false, 3.0)
	for end in [-1.0, 1.0]:  # the kicktails
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(board_c.x + end * half, board_c.y - deck_h * 0.5),
			Vector2(board_c.x + end * (half + 22.0), board_c.y - deck_h * 0.5 - 14.0 * absf(thick) - 2.0),
			Vector2(board_c.x + end * (half + 22.0), board_c.y - deck_h * 0.5 - 8.0 * absf(thick)),
			Vector2(board_c.x + end * half, board_c.y + deck_h * 0.5)]), face)
	var wheel_y := board_c.y + deck_h * 0.5 + 7.0
	for wx in [-52.0, 52.0]:
		_canvas.draw_circle(Vector2(board_c.x + wx, wheel_y + (1.0 - absf(thick)) * 4.0), 9.0, Color("#f6f1e0"))
		_canvas.draw_circle(Vector2(board_c.x + wx, wheel_y + (1.0 - absf(thick)) * 4.0), 9.0, INK, false, 3.0)
	# the body: a bold ink silhouette, knees bent on the roll and long in the air
	var hip := p + Vector2(-8.0, -62.0 * crouch - 24.0 * (1.0 - crouch))
	var shoulder := hip + Vector2(14.0 + lean * 100.0, -62.0 + 12.0 * (1.0 - crouch))
	var head := shoulder + Vector2(10.0, -26.0)
	var knee_f := hip + Vector2(32.0 * crouch + 8.0, 24.0)
	var knee_b := hip + Vector2(-30.0 * crouch - 6.0, 22.0)
	var foot_f := Vector2(board_c.x + 40.0, board_c.y - deck_h * 0.5 - 2.0)
	var foot_b := Vector2(board_c.x - 40.0, board_c.y - deck_h * 0.5 - 2.0)
	if air > 0.0:  # the feet stay near the tumbling board: pulled up behind it
		foot_f.y -= 4.0 * sin(f)
		foot_b.y += 3.0 * sin(f)
	_canvas.draw_circle(head + Vector2(0, 2), 128.0, Color("#ffcf3a", 0.14))  # a warm halo, so the figure reads against the towers
	for leg in [[hip, knee_f, foot_f], [hip, knee_b, foot_b]]:
		_canvas.draw_polyline(PackedVector2Array(leg), INK, 15.0, true)
		_canvas.draw_circle(leg[1], 7.5, INK)
	_canvas.draw_polyline(PackedVector2Array([hip, shoulder]), Color("#ff6b9a"), 26.0, true)
	_canvas.draw_circle(head, 20.0, INK)
	_canvas.draw_rect(Rect2(head.x - 24.0, head.y - 6.0, 48.0, 8.0), Color("#ff4f81"))  # the headband streams behind
	_canvas.draw_polyline(PackedVector2Array([head + Vector2(-24, -2), head + Vector2(-48 - air * 20.0, 6.0 + sin(_t * 20.0) * 4.0), head + Vector2(-70 - air * 28.0, 2.0)]), Color("#ff4f81"), 5.0, true)
	# the arms: the front one out for balance, the back one holding the money gun and kicking with the spray
	var gun_hand := shoulder + Vector2(58.0, 14.0 - air * 24.0)
	var spraying := _t > SPRAY_START and _t < SPRAY_START + BILLS * 0.034 + 0.2
	_canvas.draw_polyline(PackedVector2Array([shoulder, shoulder + Vector2(34.0, 22.0 - air * 20.0), gun_hand]), Color("#ff6b9a"), 13.0, true)
	_canvas.draw_polyline(PackedVector2Array([shoulder, shoulder + Vector2(-34.0, 6.0 - air * 30.0), shoulder + Vector2(-66.0, -4.0 - air * 40.0)]), Color("#ff6b9a"), 13.0, true)
	# the money gun: a fat brass hopper with a nozzle
	_canvas.draw_rect(Rect2(gun_hand.x - 6.0, gun_hand.y - 14.0, 44.0, 22.0), Color("#c8963a"))
	_canvas.draw_rect(Rect2(gun_hand.x + 36.0, gun_hand.y - 9.0, 22.0, 11.0), INK)
	_canvas.draw_rect(Rect2(gun_hand.x - 6.0, gun_hand.y - 14.0, 44.0, 22.0), INK, false, 3.0)
	if spraying:
		var flash := 10.0 + fmod(_t * 60.0, 3.0) * 6.0
		_canvas.draw_colored_polygon(PackedVector2Array([gun_hand + Vector2(58, -4), gun_hand + Vector2(58 + flash * 2.4, -flash), gun_hand + Vector2(58 + flash * 1.6, 0), gun_hand + Vector2(58 + flash * 2.4, flash)]), Color("#fff2cf"))
	b["hand"] = gun_hand + Vector2(58, -4)


func _bill_pos(b: Dictionary, hand: Vector2, now: float) -> Vector2:
	var dt: float = now - b.at
	if dt < 0.0:
		return Vector2(INF, INF)
	var pos := Vector2(hand.x + b.vx * dt * 0.62, hand.y + b.vy * dt * 0.62 + 640.0 * dt * dt)
	pos.x += sin(dt * 7.0 + b.phase) * 10.0 + b.drift * dt
	return pos


func _bills_in_flight(sk: Dictionary) -> void:
	for b in _bills:
		var at := _t
		var sp := _skater_state(b.at)  # a bill leaves the nozzle where the nozzle was when it was fired
		var hand := Vector2(sp.x + 122.0, sp.y - 112.0 - float(sp.air) * 24.0)
		var pos := _bill_pos(b, hand, at)
		if not pos.is_finite() or pos.y > 760.0:
			continue
		_draw_bill(pos, (at - b.at) * b.spin, 1.0)


func _draw_bill(pos: Vector2, rot: float, scale: float) -> void:
	_canvas.draw_set_transform(pos, rot, Vector2(scale, scale * absf(cos(rot * 0.7)) * 0.6 + 0.4 * scale))
	_canvas.draw_rect(Rect2(-22, -11, 44, 22), BILL)
	_canvas.draw_rect(Rect2(-22, -11, 44, 22), INK, false, 2.5)
	_canvas.draw_circle(Vector2.ZERO, 6.0, BILL_DARK)
	_canvas.draw_rect(Rect2(-17, -6, 5, 12), BILL_DARK)
	_canvas.draw_rect(Rect2(12, -6, 5, 12), BILL_DARK)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _crowd(sk: Dictionary) -> void:
	for p in _people:
		var x: float = p.x * 1600.0
		var react := clampf((_t - 2.0 - p.late) / 0.25, 0.0, 1.0)  # hands go up as the money arrives
		var hop := absf(sin((_t - 2.0 - p.late) * 9.0)) * 16.0 * react
		var y := 716.0 - hop
		var h: float = p.h
		var tone := Color("#1b1230")
		_canvas.draw_polyline(PackedVector2Array([Vector2(x - 12.0, y - h * 0.42), Vector2(x - 16.0, y)]), tone, 15.0)
		_canvas.draw_polyline(PackedVector2Array([Vector2(x + 12.0, y - h * 0.42), Vector2(x + 18.0, y)]), tone, 15.0)
		_canvas.draw_polyline(PackedVector2Array([Vector2(x, y - h * 0.4), Vector2(x, y - h * 0.82)]), tone, 36.0)
		_canvas.draw_circle(Vector2(x, y - h * 0.94), 19.0, tone)
		match int(p.hat):
			0:  _canvas.draw_rect(Rect2(x - 22.0, y - h * 0.94 - 24.0, 44.0, 9.0), Color("#ffcf3a"))  # a flat cap
			1:  _canvas.draw_rect(Rect2(x - 14.0, y - h * 0.94 - 34.0, 28.0, 22.0), Color("#ff4f81"))  # a woolly hat
			2:  _canvas.draw_circle(Vector2(x + 14.0, y - h * 0.94 - 14.0), 10.0, Color("#58c26a"))     # a bun, of sorts
		var arm_up := lerpf(0.0, 1.0, react)
		for side in [-1.0, 1.0]:
			var shoulder := Vector2(x + side * 14.0, y - h * 0.8)
			var hand := shoulder + Vector2(side * lerpf(16.0, 30.0, arm_up), lerpf(46.0, -62.0 - sin(_t * 12.0 + side) * 10.0 * arm_up, arm_up))
			_canvas.draw_polyline(PackedVector2Array([shoulder, hand]), tone, 11.0, true)
		if react > 0.0:  # a dollar sign pops over a head as it is paid
			var f: float = _t - 2.0 - p.late
			var a := clampf(1.0 - f * 0.45, 0.0, 1.0)
			_canvas.draw_string(ThemeDB.fallback_font, Vector2(x - 12.0, y - h - 24.0 - f * 26.0), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.35, 0.86, 0.45, a))


## Bills that rain on the whole picture as the game is released: the pay-off.
func _foreground_bills() -> void:
	if _released < 0.0:
		return
	var f := _t - _released
	for i in 70:
		var seed_v := float(i) * 12.9898
		var x := fposmod(sin(seed_v) * 43758.5453, 1.0) * 1700.0 - 50.0
		var delay := fposmod(sin(seed_v * 1.7) * 9631.7, 1.0) * 0.9
		var y := -60.0 + (f - delay) * (620.0 + fposmod(sin(seed_v * 3.1) * 777.0, 1.0) * 380.0)
		if f > delay and y < 980.0:
			_draw_bill(Vector2(x + sin(f * 3.0 + i) * 30.0, y), f * (3.0 + i % 5) + i, 1.6)


func _letterbox(s: Vector2, k: float, offset: Vector2) -> void:
	if offset.x > 0.0:  # a wide window: the picture is 16:9, the sides are ink
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_canvas.draw_rect(Rect2(0, 0, offset.x, s.y), INK)
		_canvas.draw_rect(Rect2(s.x - offset.x, 0, offset.x, s.y), INK)
		_canvas.draw_set_transform(offset, 0.0, Vector2(k, k))


func _title() -> void:
	var slam := clampf(_t / 0.35, 0.0, 1.0)
	var sc := 1.0 + (1.0 - _ease_out(slam)) * 1.6
	var a := slam
	var font := ThemeDB.fallback_font
	_canvas.draw_set_transform(Vector2(800.0, 150.0), -0.05, Vector2(sc, sc))
	for off in [Vector2(8, 8), Vector2(5, 5)]:
		_canvas.draw_string(font, Vector2(-330, 0) + off, "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 112, Color(INK, a))
	_canvas.draw_string_outline(font, Vector2(-330, 0), "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 112, 14, Color(INK, a))
	_canvas.draw_string(font, Vector2(-330, 0), "FIAT FRENZY", HORIZONTAL_ALIGNMENT_LEFT, 700, 112, Color(CREAM, a))
	_canvas.draw_set_transform(Vector2(800.0, 150.0), -0.05, Vector2.ONE)
	_canvas.draw_string(font, Vector2(-250, 52), "A  GAME  ABOUT  MONEY", HORIZONTAL_ALIGNMENT_LEFT, 600, 30, Color("#ffcf3a", a))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bar() -> void:
	var font := ThemeDB.fallback_font
	var shown := clampf(maxf(progress, minf(_t / 2.4, 0.9)), 0.0, 0.99)
	if _released >= 0.0:
		shown = 1.0
	var n := 24
	var x0 := 420.0
	for i in n:  # a bar made of bills, one more laid down each step
		var lit := float(i) / n < shown
		var r := Rect2(x0 + i * 30.0, 826.0, 26.0, 16.0)
		_canvas.draw_rect(r, BILL if lit else Color(1, 1, 1, 0.08))
		_canvas.draw_rect(r, INK, false, 2.0)
	_canvas.draw_string_outline(font, Vector2(420, 810), caption, HORIZONTAL_ALIGNMENT_LEFT, 700, 22, 6, INK)
	_canvas.draw_string(font, Vector2(420, 810), caption, HORIZONTAL_ALIGNMENT_LEFT, 700, 22, CREAM)
	_canvas.draw_string_outline(font, Vector2(420, 876), _tip, HORIZONTAL_ALIGNMENT_LEFT, 780, 20, 5, INK)
	_canvas.draw_string(font, Vector2(420, 876), _tip, HORIZONTAL_ALIGNMENT_LEFT, 780, 20, Color("#ffe9a8"))


func _fade() -> void:
	var a := 0.0
	if _t < 0.25:
		a = 1.0 - _t / 0.25
	if a > 0.0:
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_canvas.draw_rect(Rect2(-2000, -2000, 6000, 6000), Color(INK, clampf(a, 0.0, 1.0)))
