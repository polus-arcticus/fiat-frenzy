## What people say. Each voice has three things to say when the player comes close, and one line each for
## picking up loose money, being given money and being invested in. Data only: Chatter picks from it.
class_name Lines
extends RefCounted

const NEAR := "near"
const CASH := "cash"
const GIFT := "gift"
const INVEST := "invest"

const VOICES := {
	"drifter": {
		"near": ["Spare a coin?", "Cold out here...", "Is that a money gun?"],
		"cash": ["Finders keepers!"],
		"gift": ["Bless you, stranger."],
		"invest": ["A partner? Me?"],
	},
	"vendor": {
		"near": ["Stock's coming, I promise.", "Business is business.", "Careful with that thing."],
		"cash": ["Not a bad day."],
		"gift": ["Now we're talking!"],
		"invest": ["A partner! Splendid."],
	},
	"keeper": {
		"near": ["Food bank's open.", "Take only what you need.", "Mind the queue."],
		"cash": ["Every bit helps."],
		"gift": ["Donations welcome."],
		"invest": ["The food bank thanks you."],
	},
	"runner": {
		"near": ["Coming through!", "Mind the cart!", "Fees don't earn themselves."],
		"cash": ["A tip's a tip."],
		"gift": ["For me? Really?"],
		"invest": ["Investing in a runner?"],
	},
	"sage": {
		"near": ["Mm. Yes. Quite.", "Have you ever counted a cloud?", "Mind the beetle on your shoulder. No, the other one."],
		"cash": ["Ah. A coin on the ground: the oldest bank."],
		"gift": ["Generous. Suspiciously so."],
		"invest": ["A partner? I haven't had one since the shell."],
	},
	"banker": {
		"near": ["Do you know who I am?", "Is this a hostile takeover?", "My helicopter..."],
		"cash": ["Mine. Obviously."],
		"gift": ["Acceptable."],
		"invest": ["Pleasure doing business."],
	},
}


## Which voice someone has: a banker looks like one, otherwise it goes with what they do.
static func voice_of(d: Drone) -> String:
	if d.look == "banker":
		return "banker"
	return d.kind if VOICES.has(d.kind) else "drifter"


## The lines this person has for `event`.
static func for_event(d: Drone, event: String) -> Array:
	return VOICES[voice_of(d)][event]
