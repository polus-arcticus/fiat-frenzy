## What Mr. Nobody tells. Data only, so the words are easy to change. Each topic has a title, the hero's level
## it opens at, and a few pages, each a short paragraph in his voice. He is vague and untemporal: no dates, no
## kings, no names of places, just "once" and "an island the sea has forgotten". The stories are about money
## and scarcity and trust and promises, never about what kind of people handle it, and none of them leans on a
## stereotype (there is a test for the worst offenders, so a rewrite doesn't slip one in).
class_name Stories
extends RefCounted

## The one that opens the first meeting, whatever else is on offer.
const FIRST := "who"

const TOPICS: Array[Dictionary] = [
	{"id": "who", "title": "Who is Mr. Nobody?", "level": 1, "pages": [
		"Ah. There you are. Don't mind the shield: it is only red because red was the paint that was left. I am Mr. Nobody. Everyone says so, and I have found it is the safest name to answer to. Nobody has ever been taxed, arrested or married in my name.",
		"And what is that you are carrying? It prints. Yes, yes, I know what it prints. I have watched money being made for a very long time, in a great many places, and I have never once seen it done so cheerfully.",
		"Come and sit with me now and then. I have stories, and a weakness for people with strange tools. Ask me anything and I will answer with something nearby.",
	]},
	{"id": "shell", "title": "The shell that was loved", "level": 1, "pages": [
		"Once, on a shore with no name, a small white shell was loved by everyone. It was smooth, it was small, it did not rot, and it could not be made at home. The sea made it, and the sea does not hurry. So the people agreed that one was worth a loaf, or a song, or a day of carrying.",
		"Then a ship came with a hold full of shells from another sea. Suddenly they were everywhere, and a loaf cost a bucket of them. Nobody had stolen anything. The shells had only stopped being rare. That is the first lesson, and perhaps the last: money is a promise that something is scarce.",
		"The shell is still loved, mind you. It sits in a drawer in a town I have forgotten, being loved for no reason at all, which may be the other lesson.",
	]},
	{"id": "stones", "title": "Stones too heavy to move", "level": 2, "pages": [
		"On an island far enough away that its name has worn smooth, the people kept their money in stone discs taller than a man. Much too heavy to carry, so they didn't. When a stone changed hands, everyone simply agreed, and remembered. The stone stayed where it sat.",
		"There is a tale of a great stone that slid off a raft in deep water and sank. It was counted in full for generations. Nobody could see it, but everybody knew exactly whose it was. I find that rather beautiful: a ledger no one could burn, because it lived in everyone.",
		"Notice that the stone was never the money. The remembering was. You, my dear, carry a gun that prints a great many stones. I do wonder who will remember.",
	]},
	{"id": "gold", "title": "Gold, which is mostly patience", "level": 2, "pages": [
		"Gold is a metal that does nothing. It does not rust, it does not feed anyone, and you cannot build a roof of it. That is exactly why people trust it: it is the most reliable nothing there is.",
		"Rivers gave a little of it up to anyone patient with a pan. It was melted, stamped, buried, dug up again, and always came back the same weight. A thing that never changes is a wonderful thing to measure change with.",
		"But a thing that only sits is a poor friend. Some of the gold I have known has lain in the dark for so long it has forgotten it was ever anything but a promise to itself.",
	]},
	{"id": "beads", "title": "Beads along the water", "level": 3, "pages": [
		"Along rivers and through forests, strings of small polished beads passed from hand to hand, made patiently, one hole at a time. In some places they were gifts, in some the memory of an agreement, in some a kind of money, and the people who made them did not always agree with the people who counted them about which.",
		"That is how it usually goes with money. It means one thing to the hand that holds it and another to the hand that made it. A string of beads is a sentence, and a sentence is read differently by whoever is listening.",
	]},
	{"id": "buildings", "title": "On buildings", "level": 3, "pages": [
		"I am a tiresome man about buildings. Look at the corner of any building worth looking at: somewhere there is a stone that was laid first, and every other stone is only agreeing with it. A city is a very long argument about where the corners are.",
		"I draw them. The whole district, from memory and from windows. This street has a rhythm of five floors and a hat, and that rhythm was an agreement, as surely as any coin. When you print money at a builder you do not get buildings. You get an opinion about buildings. Be careful whose.",
		"I keep the drawings somewhere safe. One day, perhaps, I shall show you one.",
	]},
	{"id": "salt", "title": "Salt, and who was paid in it", "level": 4, "pages": [
		"They say that once a road was kept open by soldiers who were paid in salt, or in money for salt, and that the word for that pay is still hiding in the word we use for a wage. I have never checked. A story that good has earned the right to go unchecked.",
		"Salt is a lovely sort of money because everybody needs a little and nobody needs a lot. Like bread. Like water. Like kindness. The trouble begins when someone owns the only well.",
		"Which brings me back to your gun. You are, I think, about to own the only well.",
	]},
	{"id": "beetles", "title": "On beetles", "level": 4, "pages": [
		"I collect beetles, the rare ones. A jewel beetle the green of a coin that was never minted. A stag with horns like a small cathedral. There are more kinds of beetle than of anything else the world has made, and nobody counts them as money, and yet each is worth more than it looks.",
		"I keep them in glass, in neat rows, with little cards, somewhere you would never think to look. A collector is a sort of bank, you see: I keep what is rare so that it stays rare. And, like any bank, I am always a little short of exactly the thing I want.",
		"If you ever find a beetle that glitters as though it had been minted, do not squash it. Bring it to me. I may have something to give you in return. That is a hint, my dear, and not yet a promise.",
	]},
	{"id": "river", "title": "The black river", "level": 4, "pages": [
		"Down a river so dark with fallen leaves that the boatmen called it black, the traders kept their accounts on notched reeds, and the river itself set the price. When it rose, a sack of grain cost more than the field it came from. When it fell, the same sack could be had for a song.",
		"The boatmen used to say the current was the only honest banker on the water, because it never promised anything. I think about that when I look at a printed note.",
	]},
	{"id": "tally", "title": "Notches in a stick", "level": 5, "pages": [
		"Before there was writing for it, there were sticks. Split a stick down its length; one half for the one who is owed, one for the one who owes; cut notches across both. Debt is older than coins, and it fits in a pocket.",
		"A stick like that could be money too, in its way. You could hand your half to a third person and say, now it is they who owe you. The match is the whole trick: two halves of one thing, kept by two people, agreeing.",
		"That is all trust ever was, I think. A split stick, and two honest memories.",
	]},
	{"id": "paper", "title": "Paper that promised", "level": 5, "pages": [
		"In a city of canals and tea, somebody grew tired of carrying heavy coins and printed paper instead, with a promise on it: this is worth so many coins. People took it because the promise was kept, and because everyone else took it. For a while it was marvellous.",
		"Then the printers found that paper was cheaper to make than promises were to keep. They printed a little more. Then more. Prices rose like steam off a kettle. In the end the paper was worth the paper.",
		"You carry a printing gun. I am not scolding. I am only narrating with a very pointed voice.",
	]},
	{"id": "tulips", "title": "The tulip season", "level": 6, "pages": [
		"There was a spring when a flower bulb cost a house. Not the flower: the bulb, an onion with a rumour inside. Everyone was sure someone else would pay more tomorrow, and for a while someone always did.",
		"Then one morning somebody asked, why? and the rumour went home. Nothing had changed about the bulb. Everything had changed about the asking.",
		"Be wary of anything priced entirely by how many people want it, my dear. That includes a good many currencies, and one or two people.",
	]},
	{"id": "feathers", "title": "Red feathers", "level": 6, "pages": [
		"On an island in a warm sea they made money from the red feathers of a bird no bigger than a thumb, bound into coils so long they were rolled up like ribbon. Every coil was a mountain of patience, and everyone could see it.",
		"I mention it because of the beetles. The things we love to look at are very often the things we end up counting. And the things we count are very often the things we end up losing the looking of.",
	]},
]


static func topic(id: String) -> Dictionary:
	for t in TOPICS:
		if t.id == id:
			return t
	return {}
