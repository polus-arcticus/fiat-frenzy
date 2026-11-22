## VIEW. How high the ground is under a thing a view stands in the street: on a raised pavement (Kerbs) a kerb's height,
## else 0. The game sets `kerbs` when it builds the city; with none (tests, tools that build no city) it is 0 everywhere.
## The sim is flat: only what is drawn stands on the kerbs.
class_name Ground
extends RefCounted

static var kerbs: Kerbs


static func y(p: Vector2) -> float:
	return kerbs.height_at(p) if kerbs != null else 0.0


## A point in the sim's plane, stood on the ground.
static func at(p: Vector2, above := 0.0) -> Vector3:
	return Vector3(p.x, y(p) + above, p.y)
