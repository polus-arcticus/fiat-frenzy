## Where the money is. It enters only through the gun (`printed`) and is never destroyed: it sits in
## drones' wallets, in the player's pocket, in bills lying about, or in `sunk` (what repairs paid to the
## world outside).
class_name Ledger
extends RefCounted

var printed := 0.0
var player_cash := 0.0     # the player's spending money: what they have picked up, plus their stakes' share
var stake_income := 0.0    # lifetime total of what the player's stakes have paid them
var sunk := 0.0


func total(drones: Array, bills: Array) -> float:
	var t := player_cash + sunk
	for d in drones:
		t += d.wallet
	for b in bills:
		t += b.value  # in flight or lying in the street
	return t
