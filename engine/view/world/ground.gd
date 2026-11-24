## VIEW. How high the ground is under a thing a view stands in the world: the shape of the land (Landform.height_at: a street's
## surface, a building's floor, else the ground) plus, on a raised pavement (Kerbs), a kerb's height. In the view's metres:
## above `datum` (the land at the tile's market), not the sea, so a view's floating origin is where the game is and the views
## that still stand things at a fixed height are near the ground (CityBuilder draws the city the same way). The game sets all
## three when it builds the city; with none (tests, tools that build no city) it is 0 everywhere. The sim stands nothing on
## this: it reads the Landform itself.
class_name Ground
extends RefCounted

static var kerbs: Kerbs
static var landform: Landform
static var datum := 0.0


## How high the land is at `p` (a street's surface, a floor, the ground), without the kerbs.
static func land(p: Vector2) -> float:
	return landform.height_at(p) - datum if landform != null and not landform.flat else 0.0


static func y(p: Vector2) -> float:
	return land(p) + (kerbs.height_at(p) if kerbs != null else 0.0)


## A point in the sim's plane, stood on the ground.
static func at(p: Vector2, above := 0.0) -> Vector3:
	return Vector3(p.x, y(p) + above, p.y)
