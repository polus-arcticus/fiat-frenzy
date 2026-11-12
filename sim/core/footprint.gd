## What a solid thing in the street takes up: a few boxes and circles on the ground plane. Drones are kept
## out of them (they slide along an edge instead of walking through it), so nobody crosses a tent wall or a
## counter. A tent is three walls with the front left open, plus a `door` point outside the opening. Anyone already
## standing in a wall's swelled edge (someone sitting up in a bed by the wall) is not held by that wall, so they can
## always walk out. Where people go round these is not decided here: Navigation stamps the parts into a grid and plans
## paths over it; this is the shapes, and the last guard (`slide`) that keeps a body out of a wall.
##
## Shapes are given in the thing's own frame: x across its front, z backward (the stand faces -z, toward its
## customers). `front` is the unit vector from the thing out to the street, as Machine.front.
class_name Footprint
extends RefCounted

const BODY := 0.2        # a drone's radius: how far from a wall its middle stays

## One box (or, with `r` > 0, a circle) on the ground.
class Part:
	var c := Vector2.ZERO
	var half := Vector2.ZERO
	var ax := Vector2.RIGHT  # the box's own x axis, in the world
	var r := 0.0

	## Is `p` inside, with the box swelled by `pad` on every side?
	func contains(p: Vector2, pad := 0.0) -> bool:
		var d := p - c
		if r > 0.0:
			return d.length() < r + pad
		var az := Vector2(-ax.y, ax.x)
		return absf(d.dot(ax)) < half.x + pad and absf(d.dot(az)) < half.y + pad

	## Does the straight move from `a` to `b` pass through the box (swelled by `pad`)?
	func crosses(a: Vector2, b: Vector2, pad: float) -> bool:
		if r > 0.0:
			return Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) < r + pad
		var az := Vector2(-ax.y, ax.x)
		var la := Vector2((a - c).dot(ax), (a - c).dot(az))
		var lb := Vector2((b - c).dot(ax), (b - c).dot(az))
		var lo := 0.0
		var hi := 1.0
		var dir := lb - la
		var ext := half + Vector2(pad, pad)
		for k in 2:
			if absf(dir[k]) < 0.000001:
				if absf(la[k]) >= ext[k]:
					return false
			else:
				var t1 := (-ext[k] - la[k]) / dir[k]
				var t2 := (ext[k] - la[k]) / dir[k]
				lo = maxf(lo, minf(t1, t2))
				hi = minf(hi, maxf(t1, t2))
				if lo > hi:
					return false
		return true

var parts: Array[Part] = []
var enclosure: Part = null  # a tent's inside
var hull: Part = null       # a tent's whole outline: what to go round (its walls only hold you once you are close)
var door := Vector2.ZERO    # outside its open front
var _at := Vector2.ZERO
var _front := Vector2(0, 1)


func _init(at: Vector2, front: Vector2) -> void:
	_at = at
	_front = front


## The footprint of a stand, tent, food bank or the like from its shape in Catalog (MachineDef.footprint).
static func of(kind: String, at: Vector2, front: Vector2) -> Footprint:
	var f := Footprint.new(at, front)
	var shape: Dictionary = Catalog.footprint_of(kind)
	for b in shape.get("boxes", []):
		f.box(b[0], b[1], b[2], b[3])
	for c in shape.get("circles", []):
		f.circle(c[0], c[1], c[2])
	if shape.has("tent"):
		f.tent(shape.tent[0], shape.tent[1], shape.tent[2])
	return f


## World position of the spot (x, z) in this thing's frame.
func world_at(lx: float, lz: float) -> Vector2:
	return _at + Vector2(-_front.y, _front.x) * lx - _front * lz


func box(lx: float, lz: float, hx: float, hz: float) -> Part:
	var p := Part.new()
	p.c = world_at(lx, lz)
	p.half = Vector2(hx, hz)
	p.ax = Vector2(-_front.y, _front.x)
	parts.append(p)
	return p


func circle(lx: float, lz: float, radius: float) -> void:
	var p := Part.new()
	p.c = world_at(lx, lz)
	p.r = radius
	parts.append(p)


## Two side walls and a back wall, open at the front (z0 is the open end, z1 the back).
func tent(half_width: float, z0: float, z1: float) -> void:
	var mid := (z0 + z1) * 0.5
	var half_len := (z1 - z0) * 0.5
	box(-half_width, mid, 0.05, half_len)
	box(half_width, mid, 0.05, half_len)
	box(0.0, z1, half_width, 0.05)
	enclosure = Part.new()
	enclosure.c = world_at(0.0, mid)
	enclosure.half = Vector2(half_width, half_len)
	enclosure.ax = Vector2(-_front.y, _front.x)
	hull = Part.new()
	hull.c = enclosure.c
	hull.half = enclosure.half + Vector2(0.05, 0.05)
	hull.ax = enclosure.ax
	door = world_at(0.0, z0 - 0.7)


## Where a drone that tried to go from `from` to `to` ends up: at `to` if nothing is in the way, else
## sliding along whatever it ran into (or staying put if it cannot).
func slide(from: Vector2, to: Vector2) -> Vector2:
	var hit: Part = null
	for p in parts:
		if not p.contains(from, BODY) and p.crosses(from, to, BODY):
			hit = p
			break
	if hit == null:
		return to
	var move := to - from
	var ax := hit.ax
	var az := Vector2(-ax.y, ax.x)
	var along := [ax * move.dot(ax), az * move.dot(az)]  # the move split along the box's own axes
	along.sort_custom(func(a, b): return a.length() > b.length())
	for s in along:
		if s.length() < 0.0001:
			continue
		var cand: Vector2 = from + s
		if s.length() >= move.length() * 0.5 and _free(from, cand):
			return cand
	# Head-on: slip sideways toward whichever end of the wall is nearer, so it goes round and not nowhere.
	var tangent := ax if hit.half.x >= hit.half.y else az  # along the wall
	if hit.r > 0.0:
		tangent = (from - hit.c).orthogonal().normalized()
	var side := 1.0 if (from - hit.c).dot(tangent) >= 0.0 else -1.0
	var cand2 := from + tangent * side * move.length() * 0.8
	return cand2 if _free(from, cand2) else from


## Is the straight way from `a` to `b` clear of this thing's walls and boxes?
func clear(a: Vector2, b: Vector2) -> bool:
	return _free(a, b)


func _free(a: Vector2, b: Vector2) -> bool:
	for p in parts:
		if not p.contains(a, BODY) and p.crosses(a, b, BODY):
			return false
	return true
