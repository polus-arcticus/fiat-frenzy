## The quests, as data: who gives them, what they say, and the objectives in order. An objective is done when its
## `key` is (see Quests.done), and points the beacon at `at` (a World property name: "bus_stop", "sage", or "" for
## nowhere in particular). Rewrite freely: nothing here is rules.
class_name QuestBook
extends RefCounted

const LETTER := "letter"
const UPGRADE := "upgrade"

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
		"gate": [
			"Good morning. European Central Bank, visitors' entrance. Nobody walks up to the building: it is three hundred metres of lawn and very good security.",
			"A letter? In your hand? Let me see... a helicopter, a write-off, bankers in a state. Hm. I have seen stranger things come through this gate. Not many.",
			"Now. Procedure says I ask every visitor to declare what they are carrying. I have read the procedure twice, and I have decided that this is a question for a braver doorman.",
			"So: letter, noted. The lawn, lovely today. And whatever else you have there, I haven't seen it, my colleagues haven't seen it, and the cameras have been, ah, very interested in the sky.",
			"I will lift the barrier. The shuttle is waiting just inside: hop on, keep your hands in the vehicle, and it will take you round to the main entrance. The reception desk will take the letter from you there.",
		],
		"gate_reminder": "The shuttle is just inside the gate, there. It drives itself. Sit down, keep your hands inside, and mind the lawn. I say this with great affection: keep the rest where it is, too.",
		"gate_asked": "European Central Bank, visitors' entrance. Do you have business with the Bank? ... I am looking at your face. Only your face. It is a very good face.",
		"delivery": [
			"Hm? A letter? Hand-delivered, in this age? Nobody has done that since the telegraph.",
			"Stranded, hungry, the helicopter a write-off... and fed by a stranger with a very strange gun. I will see that it reaches the right desk. Eventually. We are, after all, a bank.",
			"You may have noticed nobody asked you to check anything at the cloakroom. The cloakroom attendant has gone for a long lunch. It began on Tuesday. He has not said which one.",
			"We have forty-one policies on the creation of money in this building. Not one of them mentions what is on your hip. Forty-one lawyers read them over, and not one wanted to be the person who wrote it down.",
			"Do tell the gentlemen we got their message. Whether we can do anything about it is another matter.",
			"Now. Before you go. A note has come down for you, on a form we do not use, from a floor that is not in our directory. It says: \"Send up the one with the instrument.\" I have not read it twice.",
			"The lift is there, beside the desk. It has one button and nobody here has ever pressed it. Please do. Mind the marble on your way. It is a lovely lobby. We would like it to stay one.",
		],
		"objectives": [
			{"text": "Take the bus to the European Central Bank. The stop is by the market (E at the bus to board).", "key": "rode_bus", "at": "bus_stop"},
			{"text": "The bus is stuck in traffic. Look around: someone is watching you.", "key": "met_sage", "at": "sage"},
			{"text": "Talk with Mr. Nobody as long as you like: when you are ready to move on, say farewell, and the traffic will clear.", "key": "jam_cleared", "at": "sage"},
			{"text": "The traffic is moving again and the bus is waiting. Get back on (E at the bus) to carry on to the European Central Bank.", "key": "rode_on", "at": "bus"},
			{"text": "You are at the European Central Bank. Report to the doorman at the security gate (aim at him and press Q).", "key": "cleared_gate", "at": "ecb"},
			{"text": "The gate is open. Hop on the shuttle just inside (E at the cart): it will take you to the main entrance.", "key": "rode_shuttle", "at": "shuttle"},
			{"text": "Give the letter to the receptionist at the main entrance (aim at them and press Q).", "key": "delivered", "at": "reception"},
		],
	},
}



const UPGRADE_BOOK := {
	"title": "Instrument maintenance",
	"objectives": [
		{"text": "The receptionist has sent you to the lift beside the desk. Step in: it has one button.", "key": "rode_lift", "at": "lift"},
		{"text": "Someone upstairs has been expecting you. Talk to the technician (aim and press Q).", "key": "met_technician", "at": "technician"},
	],
	"lift_reminder": "The lift, beside the desk. One button. I would not keep it waiting. It has been waiting a very long time.",
	"technician": [
		"Ah. You are early. Or the committee is late. It is hard to say, up here. The clocks are on the committee's budget.",
		"Instrument maintenance, sub-basement of a building that has no sub-basement. We service the things no one will say they own. No forms, no questions, and we do not look up from the bench.",
		"Yours, I take it? Of course it is. No, do not hand it over. They never do. It does not come off, does it? It never has.",
		"The bench is not in service yet. We are waiting on a ruling about what to call what it does, and on someone to sign it who is willing to sign anything with that word on it.",
		"Come back when you have printed something worth the paper. Mind the lift going down. It has opinions.",
	],
	"technician_again": "The bench is still waiting on its ruling. Do not touch it. It will not mind, but I would.",
}


static func quest(id: String) -> Dictionary:
	return UPGRADE_BOOK if id == UPGRADE else BOOK[id]
