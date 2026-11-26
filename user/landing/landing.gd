## Where a game begins: the map it is played on and the world built on it, where the hero starts, and which way things face.
## The story's Frankfurt is one (Scenario, with its cast, quests and opening crash); a tile anywhere on the planet is another
## (TileLanding: its map from OpenStreetMap and an atom on it, no story). The game asks this shape only, and builds the story's
## own pieces only when `story()` says there is one.
class_name Landing
extends RefCounted

var district: Dictionary            # the map (see OsmImport, tools/story_district.gd): buildings and streets
var facing := {}                    # a thing in the world -> the yaw it faces (for its view)
var start := Vector2.ZERO           # where the hero begins
var start_yaw := 0.0


## The world on this map, as it is when the game begins.
func build() -> World:
	return World.new()


## Which buildings get a door cut into them (CityBuilder): {building id: {edge, t, width, height}}.
func openings() -> Dictionary:
	return {}


## The places the map screen marks: [{pos, label, color}].
func landmarks(_w: World) -> Array:
	return []


## What the map screen calls the place.
func title() -> String:
	return ""


## Whether this is the story (its cast, quests, bus and opening crash are built), or a sandbox.
func story() -> bool:
	return false


## The vehicles (by name: Vehicle.name) that are wholly the landing's own: its controllers draw and ride them (the story's golf
## cart).
func own_rides() -> Array:
	return []


## Is the vehicle called `called` the landing's own to ride just now, so nobody gets on it at its door (a quest has it: the
## story's tram)?
func held(_w: World, _called: String) -> bool:
	return false


## What a save needs to build this landing again: {kind: "story"} or {kind: "tile", key, lat, lon}.
func spec() -> Dictionary:
	return {"kind": "story"}
