## Queues at the stands. Customers of a stand no longer crowd its counter and are all served at once: they line up out from
## the counter along the way it faces, and the one at the front is served, one at a time, each sale taking a moment of the
## vendor's time. A drone joins the line when it picks the stand for a job, walks to its place in it, shuffles up as the line
## moves, and leaves it when the job is done or has changed (it is no longer hungry, the stand sold out, it collapsed).
## The line itself is `Machine.line`, in order of arrival; nothing else keeps a record of it, so it is pruned whenever it is read.
class_name Queueing
extends RefCounted

const HEAD := 1.5       # how far from the stand the one being served stands (inside Logistics.TRADE_REACH)
const JOIN := 0.9      # how near the back of the line they must get to be in it
const LEAVE_BELOW := 0.3  # someone waiting whose other bar falls this low, and below the one they are queuing for by LEAVE_MARGIN, gives up their place
const LEAVE_MARGIN := 0.1 # (so they do not swap back and forth between two lines)
const GAP := 0.8        # between one person in the line and the next
const SERVICE := 1.6    # seconds the vendor takes over each customer
const WAIT_COST := 0.03 # what a person ahead of you is worth, to a shopper choosing a stand (cf. Logistics.DISTANCE_COST per metre)


## Is this the kind of job that waits its turn? Buying from a stand (food, drink, a vendor's restock), not repairs, picking up
## money, hauling or a bed (a tent seats its sleepers itself).
static func applies(job: Dictionary) -> bool:
	var t = job.get("target")
	return t is Machine and t.shelter == null and not (job.get("for") in ["repair", "cash", "haul", "warmth"])


## Drops from the line everyone who is no longer queuing here.
func prune(m: Machine) -> void:
	for i in range(m.line.size() - 1, -1, -1):
		var d: Drone = m.line[i]
		if not is_same(d.job.get("target"), m) or d.unconscious() or d.sheltered_in != null:  # (a target may be a tile's name: see Borders)
			m.line.remove_at(i)
	if m.line.is_empty():
		m.service_left = -1.0


## How many are waiting at `m`.
func length(m: Machine) -> int:
	prune(m)
	return m.line.size()


## A drone's place in the line at `m` (0 is the front), or -1 if it has not joined it yet.
func place(d: Drone, m: Machine) -> int:
	prune(m)
	return m.line.find(d)


## Where the person at `index` stands: out from the counter, along the way the stand faces.
static func spot(m: Machine, index: int) -> Vector2:
	return m.pos + m.front * (HEAD + GAP * index)


## One step of a queuing customer's turn. They walk to the back of the line and join it when they get there (so the line is in
## the order people arrive, and a quicker walker beats a slower one to it); then they walk up to their place, wait there facing
## the counter, and at the front give the vendor their moment. Returns whether they are served now.
func wait(d: Drone, m: Machine, dt: float, walking: Walking, pace: float) -> bool:
	var index := place(d, m)
	if index < 0:
		var back := spot(m, m.line.size())
		if d.pos.distance_to(back) > JOIN:
			d.job["stand"] = back
			d.face_to = Vector2(INF, INF)
			walking.step(d, back, dt * pace)
			return false
		m.line.append(d)
		index = m.line.size() - 1
	var at := spot(m, index)
	d.job["stand"] = at
	if d.pos.distance_to(at) > Logistics.ARRIVE:
		d.face_to = Vector2(INF, INF)
		walking.step(d, at, dt * pace)
		return false
	d.route = PackedVector2Array()
	d.face_to = m.pos
	if index != 0:
		return false
	if m.service_left < 0.0:
		m.service_left = SERVICE
	m.service_left -= dt
	if m.service_left > 0.0:
		return false
	m.service_left = -1.0
	return true


## Leaves the line (served, or the job has changed).
func leave(d: Drone, m: Machine) -> void:
	m.line.erase(d)
	if d.face_to == m.pos:
		d.face_to = Vector2(INF, INF)
