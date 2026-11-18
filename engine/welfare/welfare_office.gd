## The welfare office: a desk on the street, staffed by a clerk, that now and then throws a little money out to the town's
## residents (see Welfare). Its Premises: the money trade at tier 0 (the loan shark, the credit union and the bank branch
## above it are not built: docs/upgrade_trees.md). It stands where it was put and faces the street.
class_name WelfareOffice
extends Premises

const MERGE := {"given_out": "sum"}  # (see Merge)

var given_out := 0.0  # dollars thrown out, all told


func _init(at := Vector2.ZERO, toward := Vector2(0, 1)) -> void:
	kind = "welfare_office"
	trade = "money"
	pos = at
	front = toward
