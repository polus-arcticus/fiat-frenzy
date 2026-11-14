## Printed money as an object. It exists from the moment the gun fires it, in flight or lying in the
## street, so no money is ever unaccounted for. A "gift" bill that hits someone is their gift. Once it lands
## it is plain "cash": loose money that anyone who walks over it can pick up. (Investing is done with
## contracts, which are not money and are never left lying about: see Contract.)
class_name Bill
extends RefCounted

var value := 2.0
var mode := "gift"  # gift, or cash once it has landed
var zone := "district"
var pos := Vector2.ZERO
var loose := false  # lying on the ground, ready to be picked up


func _init(amount: float, fired_as: String) -> void:
	value = amount
	mode = fired_as
