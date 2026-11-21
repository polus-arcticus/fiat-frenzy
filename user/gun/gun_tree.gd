## The money gun's upgrade tree: four branches, each a ladder of nodes, the first of each owned from the start (today's gun). The
## story unlocks the rest (`unlock`, for quests to call: none do yet), one step at a time up a branch. The gun reads what is
## owned (GunController): the bill it prints, how fast, its modes. A node that is not `live` has no behaviour yet: it can be
## shown and owned, but changes nothing (the rolled and feather bills, a line of credit).
class_name GunTree
extends RefCounted

const BRANCHES := ["bills", "rate", "ammo", "finance"]
const BRANCH_NAMES := {"bills": "Bill size", "rate": "Fire rate", "ammo": "Ammo", "finance": "Finance modes"}
## Each node: id, branch, name, what it does, the value the gun reads, and whether it works yet. In order up its branch.
const NODES := [
	{"id": "bill_1", "branch": "bills", "name": "$1 bills", "effect": "Prints ones.", "value": 1.0, "live": true},
	{"id": "bill_5", "branch": "bills", "name": "$5 bills", "effect": "Every bill is a five.", "value": 5.0, "live": true},
	{"id": "bill_20", "branch": "bills", "name": "$20 bills", "effect": "Every bill is a twenty.", "value": 20.0, "live": true},
	{"id": "bill_100", "branch": "bills", "name": "$100 bills", "effect": "Every bill is a hundred.", "value": 100.0, "live": true},
	{"id": "rate_6", "branch": "rate", "name": "6 a second", "effect": "A steady spray.", "value": 6.0, "live": true},
	{"id": "rate_9", "branch": "rate", "name": "9 a second", "effect": "A faster spray.", "value": 9.0, "live": true},
	{"id": "rate_12", "branch": "rate", "name": "12 a second", "effect": "A blizzard of money.", "value": 12.0, "live": true},
	{"id": "paper", "branch": "ammo", "name": "Paper bills", "effect": "Flutter where they will.", "value": "paper", "live": true},
	{"id": "rolled", "branch": "ammo", "name": "Rolled bills", "effect": "Fly straighter and further.", "value": "rolled", "live": false},
	{"id": "feather", "branch": "ammo", "name": "Feather bills", "effect": "Float, and drift onto crowds.", "value": "feather", "live": false},
	{"id": "gift", "branch": "finance", "name": "Gift", "effect": "Money for nothing.", "value": "gift", "live": true},
	{"id": "invest", "branch": "finance", "name": "Invest", "effect": "A charged contract: a share of a business.", "value": "invest", "live": true},
	{"id": "credit", "branch": "finance", "name": "Line of credit", "effect": "Lend, and be owed.", "value": "credit", "live": false},
]
const START := ["bill_1", "rate_6", "paper", "gift", "invest"]

var owned: Array = START.duplicate()  # node ids (saved)


func _init(_world = null) -> void:
	pass


static func node(id: String) -> Dictionary:
	for n in NODES:
		if n.id == id:
			return n
	return {}


static func in_branch(branch: String) -> Array:
	return NODES.filter(func(n): return n.branch == branch)


func owns(id: String) -> bool:
	return id in owned


## Whether `id` is the next step up its branch (the one before it owned, it not yet).
func can_unlock(id: String) -> bool:
	var n := node(id)
	if n.is_empty() or owns(id):
		return false
	var ladder := in_branch(n.branch)
	var i := ladder.find(n)
	return i == 0 or owns(ladder[i - 1].id)


## The story gives the hero `id`. Returns whether it was unlocked.
func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	owned.append(id)
	return true


## The highest owned node of `branch` that works.
func _top(branch: String) -> Dictionary:
	var best := {}
	for n in in_branch(branch):
		if owns(n.id) and n.live:
			best = n
	return best


func bill_value() -> float:
	return float(_top("bills").value)


func shots_per_second() -> float:
	return float(_top("rate").value)


func ammo() -> String:
	return String(_top("ammo").value)


## The finance modes the gun can switch between (scroll), in order: the owned ones that work.
func modes() -> Array:
	return in_branch("finance").filter(func(n): return owns(n.id) and n.live).map(func(n): return n.value)
