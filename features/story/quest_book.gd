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
			{"text": "Talk with Mr. Nobody as long as you like: when you are ready to move on, say farewell, and the traffic will clear.", "key": "jam_cleared", "at": "sage"},
			{"text": "The traffic is moving again and the bus is waiting. Get back on (E at the bus) to carry on to the European Central Bank.", "key": "rode_on", "at": "bus"},
			{"text": "You are at the European Central Bank. Give the letter to the doorman at the gate (aim at him and press Q).", "key": "delivered", "at": "ecb"},
		],
	},
}


static func quest(id: String) -> Dictionary:
	return BOOK[id]
