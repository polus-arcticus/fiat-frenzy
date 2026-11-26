## VIEW. A line's stop sign: a pole beside the track with a round board in the line's colour, its number on it, and the stop's
## name above. One for each stop of each line a tram runs, on the right of the way it goes. It only decorates (the shelters are
## the map's own: StreetThings).
class_name TramStopView
extends Node3D

const POLE := Color(0.24, 0.26, 0.30)
const BESIDE := 2.4   # metres from the track's middle
const AHEAD := 8.5    # ...and along it from where the car's middle stops: by its front door


## The sign for stop `stop` of `line`.
func setup(line: Line, stop: int) -> TramStopView:
	name = "TramStop"
	var s: float = line.stops[stop].s
	var dir := line.dir_at(s)
	var right := dir.rotated(PI * 0.5)  # (x east, y south: a quarter turn on from forward is to the right)
	position = Ground.at(line.pos_at(s + AHEAD) + right * BESIDE)
	rotation.y = atan2(dir.x, dir.y)
	var colour := line.colour if line.colour.a > 0.0 else TramView.TRIM
	Look.box(self, Vector3(0.09, 2.9, 0.09), Vector3(0, 1.45, 0), POLE)
	Look.box(self, Vector3(0.08, 0.7, 0.7), Vector3(0, 2.75, 0), colour)
	for face in [-1.0, 1.0]:
		var l := Look.label3d(self, line.number, Vector3(face * 0.06, 2.75, 0), 64, 80.0)
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.fixed_size = false
		l.pixel_size = 0.006
		l.no_depth_test = false
		l.rotation.y = face * PI * 0.5
	Look.label3d(self, str(line.stops[stop].name), Vector3(0, 3.4, 0), 24, 30.0)
	return self
