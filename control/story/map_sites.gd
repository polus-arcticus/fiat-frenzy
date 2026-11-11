## CONTROLLER (geometry only). Questions the starting scenario asks of the real map: where the street is, where a door
## should go in a building, and where the traffic jam stands. Pure functions of the district data: no state, no nodes.
class_name MapSites
extends RefCounted

const DOOR_WIDTH := 3.0
const DOOR_HEIGHT := 2.8


## The point on the named street nearest `near`, with the street's direction and width there.
static func street_frame(district: Dictionary, street: String, near: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for r in district.roads:
		if r.name != street:
			continue
		var pts := pts(r.pts)
		for k in pts.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(near, pts[k], pts[k + 1])
			var d := c.distance_to(near)
			if d < best_d and pts[k].distance_to(pts[k + 1]) > 0.5:
				best_d = d
				best = {"point": c, "dir": (pts[k + 1] - pts[k]).normalized(), "width": float(r.w)}
	return best


## Puts a door in the middle of the wall of building `id` that is nearest the street called `street`. Returns
## {id, edge, t, door, out, inward, along, depth, poly}, or {} if the building or street is not in the data.
static func plan_door(district: Dictionary, id: int, street: String) -> Dictionary:
	var poly := PackedVector2Array()
	for b in district.buildings:
		if int(b.id) == id:
			poly = pts(b.poly)
	var segs: Array = []
	for r in district.roads:
		if r.name == street:
			var pts := pts(r.pts)
			for k in pts.size() - 1:
				segs.append([pts[k], pts[k + 1]])
	if poly.size() < 3 or segs.is_empty():
		return {}
	var best := -1
	var best_d := INF
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		if p.distance_to(q) < DOOR_WIDTH + 2.0:
			continue
		var mid := (p + q) * 0.5
		var d := INF
		for sg in segs:
			d = minf(d, mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, sg[0], sg[1])))
		if d < best_d:
			best_d = d
			best = k
	if best < 0:
		return {}
	var p := poly[best]
	var q := poly[(best + 1) % poly.size()]
	var length := p.distance_to(q)
	var along := (q - p) / length
	var out := Vector2(along.y, -along.x)  # the same outward as CityBuilder works out for this wall
	var door := p + along * length * 0.5
	var depth := 0.0
	for pt in poly:
		depth = maxf(depth, (pt - door).dot(-out))
	return {"id": id, "edge": best, "t": length * 0.5, "door": door, "out": out, "inward": -out, "along": along, "depth": depth, "poly": poly}


## The traffic jam on Battonnstraße in front of Mr. Nobody's house: the bus in the lane nearest the house, a few
## cars nose to tail on either side of it, and where the hero steps off on the pavement.
static func plan_jam(district: Dictionary, sage_house: Dictionary) -> Dictionary:
	if sage_house.is_empty():
		return {}
	var door: Vector2 = sage_house.door
	var out: Vector2 = sage_house.out
	var street := street_frame(district, Scenario.SAGE_STREET, door)
	if street.is_empty():
		return {}
	var dir: Vector2 = street.dir
	var centre: Vector2 = street.point
	var lane := float(street.width) * 0.25
	var yaw := atan2(dir.x, dir.y)
	var cars: Array = []
	var colors := [Color(0.7, 0.2, 0.2), Color(0.85, 0.82, 0.7), Color(0.25, 0.35, 0.55), Color(0.3, 0.3, 0.32), Color(0.8, 0.6, 0.2), Color(0.35, 0.5, 0.35)]
	var spots := [[-9.5, -1], [-14.5, -1], [10.0, -1], [15.0, -1], [-6.0, 1], [-11.0, 1], [4.0, 1], [9.5, 1]]
	for k in spots.size():
		cars.append({"pos": centre + dir * spots[k][0] + out * (lane * spots[k][1]), "yaw": yaw if spots[k][1] < 0 else yaw + PI, "color": colors[k % colors.size()]})
	return {
		"bus": {"pos": centre - out * lane, "yaw": yaw}, "cars": cars,
		"arrival": door + out * 4.0 + (sage_house.along as Vector2) * 4.0,
	}


static func pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(0, flat.size(), 2):
		out.append(Vector2(flat[k], flat[k + 1]))
	return out
