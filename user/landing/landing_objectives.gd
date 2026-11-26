## The objective line on a tile with no story: get to the market, then get it going. The beacon points at the market until the
## hero is there.
class_name LandingObjectives
extends Objectives

const THERE := 15.0  # metres from the market that count as being at it

var _market := Vector2.ZERO
var _street := ""
var _player := Vector2.ZERO
var _arrived := false
var _news: Array[String] = []


func _init(landing: TileLanding) -> void:
	_market = landing.market
	_street = str(landing.site.get("street", ""))


func update(player: Vector2) -> void:
	_player = player
	if not _arrived and player.distance_to(_market) < THERE:
		_arrived = true
		_news.append("You found the market.")


func take_news() -> Array[String]:
	var out := _news
	_news = []
	return out


func text() -> String:
	if not _arrived:
		var where := " on %s" % _street if _street != "" else ""
		return "Find this tile's market%s: about %d m that way. If the cold gets to you on the way, put down the barrel fire in your bag (Tab, right-click it)." % [where, roundi(_player.distance_to(_market))]
	return "The town is a tent city and its keeper. Put up tents (E at the tent city) and its people come, one for each, with their stands: wrecked, their owners broke. Spray them with money to get them going, and buy into the ones you like."


func marker() -> Variant:
	return null if _arrived else _market
