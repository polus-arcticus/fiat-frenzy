## The bus's way along the streets, made smooth: the street polyline with its corners rounded off into curves a bus
## can take, and a speed for every point on it (up to a top speed on the straight, slower through a bend, gently
## up from rest at the start and down to rest at the end). The bus moves by distance along it, so its position,
## heading and speed all change smoothly.
class_name BusPath
extends RefCounted

const RADIUS := 9.0        # how tightly it will turn a corner (metres): corners are rounded off with this
const CURVE_POINTS := 10   # a rounded corner is drawn as this many short stretches
const MAX_SPEED := 13.0    # on a straight, metres a second (about 47 km/h)
const MIN_SPEED := 2.5     # through the tightest bend
const LATERAL := 2.2       # sideways acceleration it will put up with: this sets the speed in a bend
const ACCEL := 1.8         # speeding up
const BRAKE := 2.6         # slowing down
const MAX_GAP := 3.0       # the path has a point at least this often, so the speed is worked out this often

var pts := PackedVector2Array()
var cum := PackedFloat32Array()   # distance along the path to each point
var speeds := PackedFloat32Array()  # the speed it should be doing at each point
var length := 0.0


## The path through `route` (its first point is where the bus is now).
static func build(route: PackedVector2Array) -> BusPath:
	var p := BusPath.new()
	p.pts = _resampled(_rounded(route))
	p._measure()
	p._profile()
	return p


## Each corner of `route` replaced by a curve (a quadratic one: its tangents are the two streets). A corner never
## uses more than 45% of either street, so two corners close together cannot overlap.
static func _rounded(route: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if route.is_empty():
		return out
	out.append(route[0])
	for i in range(1, route.size() - 1):
		var a := route[i - 1]
		var v := route[i]
		var b := route[i + 1]
		var in_leg := v - a
		var out_leg := b - v
		if in_leg.length() < 0.01 or out_leg.length() < 0.01:
			continue
		var in_dir := in_leg.normalized()
		var out_dir := out_leg.normalized()
		var turn := acos(clampf(in_dir.dot(out_dir), -1.0, 1.0))
		if turn < 0.04:
			out.append(v)
			continue
		var d := minf(RADIUS * tan(turn * 0.5), minf(in_leg.length(), out_leg.length()) * 0.45)
		var start := v - in_dir * d
		var finish := v + out_dir * d
		for k in CURVE_POINTS + 1:
			var t := float(k) / CURVE_POINTS
			out.append(start * ((1.0 - t) * (1.0 - t)) + v * (2.0 * (1.0 - t) * t) + finish * (t * t))
	out.append(route[route.size() - 1])
	# drop points that are on top of each other
	var clean := PackedVector2Array([out[0]])
	for q in out:
		if q.distance_to(clean[clean.size() - 1]) > 0.05:
			clean.append(q)
	return clean


## Extra points along any long straight stretch, so the speed can be worked out every few metres: speeding up and
## braking take place along a street, not only at its corners.
static func _resampled(path: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in path.size():
		if i > 0:
			var gap := path[i].distance_to(path[i - 1])
			var n := int(gap / MAX_GAP)
			for k in range(1, n + 1):
				out.append(path[i - 1].lerp(path[i], float(k) / (n + 1)))
		out.append(path[i])
	return out


func _measure() -> void:
	cum = PackedFloat32Array()
	var run := 0.0
	for i in pts.size():
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		cum.append(run)
	length = run


## How fast it should go at each point: what the bend there allows, then limited by how fast it can speed up from
## rest and how soon it must brake to stop at the end.
func _profile() -> void:
	var n := pts.size()
	speeds = PackedFloat32Array()
	speeds.resize(n)
	for i in n:
		var v := MAX_SPEED
		if i > 0 and i < n - 1:
			var a := pts[i] - pts[i - 1]
			var b := pts[i + 1] - pts[i]
			var turn := acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0))
			if turn > 0.001:
				var radius := (a.length() + b.length()) * 0.5 / turn
				v = clampf(sqrt(LATERAL * radius), MIN_SPEED, MAX_SPEED)
		speeds[i] = v
	if n == 0:
		return
	speeds[0] = 0.0
	for i in range(1, n):
		speeds[i] = minf(speeds[i], sqrt(speeds[i - 1] * speeds[i - 1] + 2.0 * ACCEL * (cum[i] - cum[i - 1])))
	speeds[n - 1] = 0.0
	for i in range(n - 2, -1, -1):
		speeds[i] = minf(speeds[i], sqrt(speeds[i + 1] * speeds[i + 1] + 2.0 * BRAKE * (cum[i + 1] - cum[i])))


## Which stretch (between point i and i + 1) distance `s` along the path is in.
func _stretch(s: float) -> int:
	if pts.size() < 2:
		return 0
	return clampi(cum.bsearch(s) - 1, 0, pts.size() - 2)


func pos_at(s: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector2.ZERO
	var i := _stretch(s)
	var run := cum[i + 1] - cum[i]
	return pts[i].lerp(pts[i + 1], clampf((s - cum[i]) / maxf(run, 0.0001), 0.0, 1.0))


## The way the path is pointing at `s` (a unit vector).
func dir_at(s: float) -> Vector2:
	if pts.size() < 2:
		return Vector2.RIGHT
	var i := _stretch(s)
	return (pts[i + 1] - pts[i]).normalized()


## How fast the bus should be going at `s`: between the speeds at the ends of its stretch, as an acceleration
## would have it (the speed squared grows evenly with the distance).
func speed_at(s: float) -> float:
	if pts.size() < 2:
		return 0.0
	var i := _stretch(s)
	var run := cum[i + 1] - cum[i]
	var k := clampf((s - cum[i]) / maxf(run, 0.0001), 0.0, 1.0)
	return sqrt(lerpf(speeds[i] * speeds[i], speeds[i + 1] * speeds[i + 1], k))
