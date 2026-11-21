## Who someone is, for the tent city's ID cards: where they are from, what they did before the street, how they came to it and
## what they hope for. Drawn from short lists by dice seeded with their uid, so the same person has the same story every time,
## on every machine, and nothing needs saving. A line about the work they do here comes from their role. Words only: nothing in
## the sim reads it.
class_name Biography
extends RefCounted

const HOMETOWNS := ["Offenbach", "Hanau", "Darmstadt", "Gießen", "Mainz", "Wiesbaden", "Kassel", "Fulda", "Mannheim", "Würzburg",
	"Saarbrücken", "Bremen", "Leipzig", "Rostock", "Kraków", "Timișoara", "Izmir", "Thessaloniki", "Porto", "Palermo", "Sofia",
	"Zagreb", "Aleppo", "Lyon"]
const WAS := ["a forklift driver", "a hotel cook", "a parcel courier", "a hairdresser", "a nurse's aide", "a bricklayer",
	"a bank teller", "a call-centre agent", "a taxi driver", "a seamstress", "a warehouse picker", "a schoolteacher",
	"a sound engineer", "a carpenter", "a cleaner at the airport", "a waiter on the Zeil", "a printer", "a bike mechanic"]
const FELL := ["The firm folded in a week and the last wages never came.", "The rent went up twice in one year, and then the lease ran out.",
	"A divorce took the flat, and the savings went on the lawyer.", "An injury, then a long wait, then no job to go back to.",
	"The money they sent home was needed more than the room they slept in.", "A landlord sold the building; nobody would rent to them after.",
	"The bank's new rates ate the loan, then the car, then the rest.", "They came for a job that had gone by the time they arrived.",
	"A bad winter, a debt to the wrong people, and a door that stayed shut.", "Prices climbed faster than any wage they could get."]
const HOPES := ["They want a room with a lock and a window.", "They are saving for a train ticket home.",
	"They'd like to work with their hands again.", "They want their kids to visit somewhere that isn't the street.",
	"They dream of a stall of their own.", "They'd settle for a winter without the cold in their bones.",
	"They keep a list of every euro they owe, and mean to pay it.", "They want to learn to fix bikes properly."]
## What their work here is, by role (a vendor by what their stand is).
const HERE := {"drifter": "Gets by on what the street gives.", "runner": "Pushes a cart between the food bank and the stands.",
	"keeper": "Minds the food bank's shelves.", "clerk": "Hands out the welfare office's money, a few dollars at a time.",
	"medic": "Patches people up at the first aid post.", "tent": "Keeps the tent city, and makes tents and barrels from scrap.",
	"hostel": "Keeps the hostel, and makes tents and barrels from scrap.", "bakery": "Bakes the town's bread.",
	"bake_shop": "Runs the bake shop.", "lemonade_stand": "Mixes lemonade from water and sugar.",
	"coffee_stop": "Runs the coffee stop.", "hot_dog_stand": "Sells hot dogs from a bun and a sausage.",
	"burger_bar": "Runs the burger bar.", "scrap_camp": "Builds old skateboards out of scrap.",
	"bike_camp": "Builds old bikes out of scrap.", "thrift_stall": "Stitches old coats from scrap.",
	"clothing_shop": "Runs the clothing shop."}


## {id, hometown, was, fell, hope, here}: `id` an ID-card number, the rest lines of their story.
static func of(d: Drone, w: World) -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = d.uid.hash()
	var m := w.machine_of(d)
	var role: String = m.kind if m != null else d.kind
	return {
		"id": "%02d-%04d" % [dice.randi() % 100, dice.randi() % 10000],
		"hometown": HOMETOWNS[dice.randi() % HOMETOWNS.size()],
		"was": WAS[dice.randi() % WAS.size()],
		"fell": FELL[dice.randi() % FELL.size()],
		"hope": HOPES[dice.randi() % HOPES.size()],
		"here": HERE.get(role, ""),
	}
