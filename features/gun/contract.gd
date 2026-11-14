## An investment contract, as the gun spits it: an offer to buy into someone's business for `value`. Unlike a
## bill it is not money yet and never lies in the street: it either reaches a vendor, who takes as much as
## fits under the 49% cap, or it is void. Nothing is printed until a business accepts it.
class_name Contract
extends RefCounted

var value := 0.0


func _init(amount: float) -> void:
	value = amount
