## The quests, as data: who gives them, what they say, and the objectives in order. An objective is done when its
## `key` is (see Quests.done), and points the beacon at `at` (a World property name: "bus_stop", "sage", or "" for
## nowhere in particular). Rewrite freely: nothing here is rules.
class_name QuestBook
extends RefCounted

const LETTER := "letter"

const BOOK := {
	"letter": {
		"title": "A letter for the bank",
		"giver": "banker",
		"offer": [
			"Listen. My phone is a brick, and so is everyone's: they broke in the crash. Nobody at the European Central Bank knows we are alive.",
			"You, with the gun, have been keeping us fed. Take this letter to them and spell out our predicament: stranded, hungry, and the helicopter is a write-off.",
			"The bus leaves from the stop by the market. Do hurry. A banker's patience is measured in basis points.",
		],
		"reminder": "The bus, my dear fellow, the bus. The stop is by the market.",
		"delivery": [
			"Hm? A letter? Hand-delivered, in this age? Nobody has done that since the telegraph.",
			"Stranded, hungry, the helicopter a write-off... and fed by a stranger with a very strange gun. I will see that it reaches the right desk. Eventually. We are, after all, a bank.",
			"Do tell the gentlemen we got their message. Whether we can do anything about it is another matter.",
		],
		"objectives": [
			{"text": "Take the bus to the European Central Bank. The stop is by the market (E at the bus to board).", "key": "rode_bus", "at": "bus_stop"},
			{"text": "The bus is stuck in traffic. Look around: someone is watching you.", "key": "met_sage", "at": "sage"},
			{"text": "Carry the letter on to the European Central Bank, east of here. Ask at the door (aim at the doorman and press Q).", "key": "delivered", "at": "ecb"},
		],
	},
}


static func quest(id: String) -> Dictionary:
	return BOOK[id]
