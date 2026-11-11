## Mr. Nobody: the hero's sage. He lives on Battonnstraße, notices the money gun when the hero comes near, and
## wants a conversation. This is what is known about him and the hero: whether they have met, what he has told
## them, and what he will tell at the hero's level. It does not say how a conversation looks (the dialogue
## screen) or who walks where (the sage controller). He has no needs: he is the world's fixed point.
class_name Sage
extends RefCounted

const NOTICE_RANGE := 12.0  # how close the hero must come, with the gun, for him to notice
const GREET_RANGE := 3.5    # how close he comes to talk
const TALK_RANGE := 5.0     # how close the hero must be to start talking again by pressing Q

const SPEED := 1.5  # he ambles
const GIVE_UP := 30.0  # the hero has gone this far off: he goes home
const CALL_OUT_EVERY := 15.0
const HOST_RANGE := 4.5  # in his house, how close the hero must come in for him to begin

var met := false
var name_known := false  # he has given his name: until then he is just "Stranger"
var told := {}  # topic id -> true
var approaching := false  # walking over to the hero
var arrived := false      # he has reached them: the conversation should open
var talking := false      # in conversation (set by whoever runs it): he stays put
var home := Vector2(INF, INF)
## His house, if he has one: its footprint and where he waits for a guest, inside. With a house he invites the
## hero in to talk instead of coming out to them.
var house := PackedVector2Array()
var host_spot := Vector2(INF, INF)

var _call_out_in := 0.0

var _w: World


func _init(world: World) -> void:
	_w = world


## Gives him a house to receive the hero in: its footprint, and where he waits inside (on the line in from his door).
func set_house(footprint: PackedVector2Array, spot: Vector2) -> void:
	house = footprint
	host_spot = spot


func hosting() -> bool:
	return house.size() >= 3 and host_spot.is_finite()


func _in_house(p: Vector2) -> bool:
	return hosting() and Geometry2D.is_point_in_polygon(p, house)


## The drone that is Mr. Nobody, or null if this world has none.
func drone() -> Drone:
	return _w.sage_drone


## Mr. Nobody's day: he notices the hero and walks over, calls out if they are on the bike, and goes back to
## his door when they've gone or the talking is done.
func step(dt: float) -> void:
	var d := _w.sage_drone
	if d == null or _w.player == null:
		return
	if not home.is_finite():
		home = d.pos
	_call_out_in = maxf(0.0, _call_out_in - dt)
	if talking:
		return
	if not approaching and not arrived and noticed():
		approaching = true
		_call_out_in = CALL_OUT_EVERY
		if hosting():
			_w.chatter.say_line(d, "Ah! Is that what I think it is? Come in, my dear, come in. Out of the street.")
		else:
			_w.chatter.say_line(d, "Ah! Is that what I think it is? Stay there, my dear. I shall come to you.")
	if calls_out() and _call_out_in <= 0.0:
		_call_out_in = CALL_OUT_EVERY
		_w.chatter.say_line(d, "Do step off that contraption. I should like a proper look at that gun.")
	if approaching:
		var dist := d.pos.distance_to(_w.player.pos)
		if dist > GIVE_UP or _w.player.unconscious():
			approaching = false
		elif hosting():
			_host(d, dt)
		elif dist <= GREET_RANGE:
			approaching = false
			arrived = true
		else:
			var goal := _w.player.pos + (d.pos - _w.player.pos).normalized() * (GREET_RANGE - 0.5)
			_w.walking.step(d, goal, dt)
			d.face_to = _w.player.pos
	elif not arrived and d.pos.distance_to(home) > 0.4:
		_go(d, home, dt)  # back to his door
	if arrived or approaching or d.pos.distance_to(_w.player.pos) < 14.0:
		d.face_to = _w.player.pos


## Showing the hero in: he goes inside and waits in his room, and the talk begins once they have followed him in.
func _host(d: Drone, dt: float) -> void:
	_go(d, host_spot, dt)
	if d.pos.distance_to(host_spot) > 0.3:
		return
	if _in_house(_w.player.pos) and d.pos.distance_to(_w.player.pos) <= HOST_RANGE:
		approaching = false
		arrived = true
	elif _call_out_in <= 0.0:
		_call_out_in = CALL_OUT_EVERY
		_w.chatter.say_line(d, "Come in, come in. There is a chair, and it is far too cold to stand out there.")


## Where he is going: straight there if he has a house (the way in is the line through his door, which the
## streets know nothing of), otherwise the usual way along the streets.
func _go(d: Drone, goal: Vector2, dt: float) -> void:
	if not hosting():
		_w.walking.step(d, goal, dt)
		return
	var to := goal - d.pos
	d.pos += to.normalized() * minf(SPEED * dt, to.length())
	d.heading = to.angle()


## He has said who he is.
func learn_name() -> void:
	name_known = true
	if _w.sage_drone != null:
		_w.sage_drone.label = "Mr. Nobody"


## A conversation begins: he stays where he is.
func begin_talking() -> void:
	talking = true
	approaching = false
	arrived = false
	if _w.sage_drone != null:
		_w.sage_drone.face_to = _w.player.pos


## The conversation is over: he may go home.
func end_talking() -> void:
	talking = false
	arrived = false


## He notices the hero: he has not met them, the hero has the money gun, is on foot and awake, and is near.
func noticed() -> bool:
	return _w.sage_drone != null and not met and _w.gun_owned and _near(NOTICE_RANGE) and not _w.riding.riding() and not _w.player.unconscious()


## He sees the gun, but the hero is on the bike: he calls out and waits.
func calls_out() -> bool:
	return _w.sage_drone != null and not met and _w.gun_owned and _near(NOTICE_RANGE) and _w.riding.riding()


## The hero is close enough to talk to him (after the first meeting, by pressing Q).
func in_talking_range() -> bool:
	return _w.sage_drone != null and _near(TALK_RANGE) and not _w.player.unconscious()


## What he will tell the hero at `level`: [{id, title, told}], in the order of the stories.
func topics_for(level: int) -> Array:
	var out: Array = []
	for t in Stories.TOPICS:
		if t.level <= level and not (t.id == Stories.FIRST and met):
			out.append({"id": t.id, "title": t.title, "told": told.has(t.id)})
	return out


## Starts telling `id`: remembers it, and returns its pages ([] if it isn't open yet at the hero's level).
func tell(id: String) -> Array:
	var t := Stories.topic(id)
	if t.is_empty() or t.level > _w.player.growth.level:
		return []
	told[id] = true
	if id == Stories.FIRST:
		met = true
	return t.pages


func _near(range_m: float) -> bool:
	return _w.player != null and _w.sage_drone.pos.distance_to(_w.player.pos) <= range_m
