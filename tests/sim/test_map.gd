## Sim tests: the map's compass (the screen itself is checked in the scene suite).
extends TestCase


func test_the_compass_names_the_eight_winds_with_north_up() -> void:
	check(MapScreen.compass_name(Vector2(0, -1)) == "N", "north is toward -y (the world's -z)")
	check(MapScreen.compass_name(Vector2(1, 0)) == "E" and MapScreen.compass_name(Vector2(-1, 0)) == "W", "east is +x and west is -x")
	check(MapScreen.compass_name(Vector2(0, 1)) == "S", "south is +y")
	check(MapScreen.compass_name(Vector2(1, -1)) == "NE" and MapScreen.compass_name(Vector2(1, 1)) == "SE", "and the diagonals")
	check(MapScreen.compass_name(Vector2(-1, 1)) == "SW" and MapScreen.compass_name(Vector2(-1, -1)) == "NW", "all four")
	check(MapScreen.compass_name(Vector2(0.2, -1)) == "N" and MapScreen.compass_name(Vector2(1, -0.3)) == "E", "a little off a wind still reads as that wind")
