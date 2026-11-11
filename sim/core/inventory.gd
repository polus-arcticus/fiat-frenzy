## Item slots, Planet Crafter style: item id -> count, with an optional capacity per item, plus the
## logistics flags a drone reads to know what to move where:
##   want   item -> how many this holder would like delivered (a demand sink)
##   offer  item -> how many this holder has available to be taken (a supply)
## Money is not an item. It is a plain number on the drones that hold it.
class_name Inventory
extends RefCounted

var counts := {}
var caps := {}
var want := {}
var offer := {}


func count(item: String) -> int:
	return counts.get(item, 0)


func room(item: String) -> int:
	return caps.get(item, 1 << 30) - count(item)


## Puts up to n in; returns how many went in.
func add(item: String, n: int) -> int:
	var added := maxi(0, mini(n, room(item)))
	counts[item] = count(item) + added
	return added


## Takes up to n out; returns how many came out.
func take(item: String, n: int) -> int:
	var taken := maxi(0, mini(n, count(item)))
	counts[item] = count(item) - taken
	return taken


func move_to(other: Inventory, item: String, n: int) -> int:
	var moved := other.add(item, mini(n, count(item)))
	take(item, moved)
	return moved
