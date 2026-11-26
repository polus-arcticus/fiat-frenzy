## Where the money is. It enters through the gun (`printed`, which also counts what the world was seeded with), and in the
## pockets of people passing through (`brought`), who leave with what they have left (`taken`). None is destroyed: it sits in
## drones' wallets, in a hero's pocket, in bills lying about, in `sunk` (what repairs paid to the world outside), or has been
## taken away.
##
## Every hero has a pocket of their own (a world can hold more than one hero: a merged save, or co-op). `player_cash` and
## `stake_income` are the local hero's, so the game reads them as before.
class_name Ledger
extends RefCounted

## Two saves combined (see Merge): what each printed, sank and pocketed since their common start adds up.
const MERGE := {"printed": "sum", "issued": "sum", "sunk": "sum", "brought": "sum", "taken": "sum", "pockets": "sum", "incomes": "sum"}

var printed := 0.0
var issued := 0.0   # the part of `printed` paid out as deposits on bottles, once the depot's fund ran dry (Deposit), not the gun
var sunk := 0.0
var brought := 0.0  # what passersby have come into town with...
var taken := 0.0    # ...and left it with
var pockets := {}   # hero uid -> spending money: what they have picked up, plus their stakes' share
var incomes := {}   # hero uid -> lifetime total of what their stakes have paid them
var local := ""     # the uid of the hero at this machine (see World.add_player)

## The local hero's spending money.
var player_cash: float:
	get:
		return pockets.get(local, 0.0)
	set(v):
		pockets[local] = v

## Lifetime total of what the local hero's stakes have paid them.
var stake_income: float:
	get:
		return incomes.get(local, 0.0)
	set(v):
		incomes[local] = v


## A hero's cut of a sale, into their pocket.
func pay(hero: String, amount: float) -> void:
	pockets[hero] = float(pockets.get(hero, 0.0)) + amount
	incomes[hero] = float(incomes.get(hero, 0.0)) + amount


## All the money there is, counting what has been taken away and not what was brought in: so it is what was printed.
## `drones`: everyone with a wallet, the passersby about among them.
func total(drones: Array, bills: Array) -> float:
	var t := sunk + taken - brought
	for h in pockets:
		t += pockets[h]
	for d in drones:
		t += d.wallet
	for b in bills:
		t += b.value  # in flight or lying in the street
	return t
