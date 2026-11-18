## Printed money as an object. It exists from the moment the gun fires it, in flight or lying in the
## street, so no money is ever unaccounted for. A "gift" bill that hits someone is their gift. Once it lands
## it is plain "cash": loose money that anyone who walks over it can pick up. (Investing is done with
## contracts, which are not money and are never left lying about: see Contract.)
class_name Bill
extends RefCounted

var uid := ""  # see World.mint
var value := 2.0
var mode := "gift"  # gift, or cash once it has landed
var zone := "district"
var pos := Vector2.ZERO
var loose := false  # lying on the ground, ready to be picked up
var aboard := false # lying on the floor of the bus, and going where it goes (then `local` is where, in the bus's own coordinates)
var local := Vector2.ZERO


func _init(amount := 0.0, fired_as := "cash") -> void:
	value = amount
	mode = fired_as
