## How an Inventory's counts lay out into slots, the way Planet Crafter shows them: one slot holds one
## kind of item, up to SIZE of it, so 13 bread is two slots (10 and 3).
class_name Stacks
extends RefCounted

const SIZE := 10


static func slots_for(count: int) -> int:
	return ceili(float(count) / SIZE)


static func slots_used(inv: Inventory) -> int:
	var n := 0
	for item in inv.counts:
		n += slots_for(inv.counts[item])
	return n


## One entry per slot in use: {item, count}, in the order the items were first held.
static func layout(inv: Inventory) -> Array:
	var out: Array = []
	for item in inv.counts:
		var left: int = inv.counts[item]
		while left > 0:
			out.append({"item": item, "count": mini(left, SIZE)})
			left -= SIZE
	return out


## Is there a slot for one more of `item`, in a bag of `slots` slots?
static func can_add(inv: Inventory, item: String, slots: int) -> bool:
	var c := inv.count(item)
	if c > 0 and c % SIZE != 0:
		return true  # room in its last stack
	return slots_used(inv) < slots
