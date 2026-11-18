## Where the money is. It enters only through the gun (`printed`, which also counts what the world was seeded with) and is
## never destroyed: it sits in drones' wallets, in a hero's pocket, in bills lying about, or in `sunk` (what repairs paid to
## the world outside).
##
## Every hero has a pocket of their own (a world can hold more than one hero: a merged save, or co-op). `player_cash` and
## `stake_income` are the local hero's, so the game reads them as before.
class_name Ledger
extends RefCounted

## Two saves combined (see Merge): what each printed, sank and pocketed since their common start adds up.
const MERGE := {"printed": "sum", "issued": "sum", "sunk": "sum", "pockets": "sum", "incomes": "sum"}

var printed := 0.0
var issued := 0.0   # the part of `printed` that the welfare office was issued ("pass go": see Welfare), not the gun
var sunk := 0.0
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


func total(drones: Array, bills: Array) -> float:
	var t := sunk
	for h in pockets:
		t += pockets[h]
	for d in drones:
		t += d.wallet
	for b in bills:
		t += b.value  # in flight or lying in the street
	return t
