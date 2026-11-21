## People's names: a first name and a surname each, of the kinds you hear in Frankfurt's station district, picked by the person's
## uid (so the same person has the same name every run, on every machine, in every save, and naming nobody rolls the world's
## dice). About two and a half thousand pairs, so two neighbours rarely share one.
class_name Names
extends RefCounted

const FIRST := ["Aylin", "Bruno", "Chiara", "Dimitri", "Elif", "Finn", "Greta", "Hamza", "Ilse", "Jonas", "Kemal", "Lotte",
	"Milan", "Nora", "Olek", "Paula", "Rafa", "Sven", "Tamar", "Ugo", "Vera", "Wim", "Yusuf", "Zora", "Anja", "Bilal", "Carla",
	"Deniz", "Emre", "Frieda", "Goran", "Hanna", "Ivo", "Jana", "Kofi", "Lena", "Mehmet", "Nadia", "Oskar", "Petra", "Rania",
	"Stefan", "Tülay", "Uwe", "Valentina", "Walter", "Ximena", "Yara"]
const LAST := ["Demir", "Schneider", "Kowalski", "Rossi", "Yılmaz", "Becker", "Novak", "Hoffmann", "Popescu", "Wagner", "Kaya",
	"Fischer", "Petrović", "Schulz", "Nowak", "Weber", "Özdemir", "Meyer", "Horvat", "Richter", "Costa", "Klein", "Mensah",
	"Wolf", "Ivanova", "Schäfer", "Haddad", "Koch", "Bauer", "Şahin", "Lange", "Marino", "Krüger", "Dimitrova", "Braun",
	"Okafor", "Zimmermann", "Celik", "Hartmann", "Ferreira", "Schmitt", "Jovanović", "Werner", "Aydın", "Krause", "Nguyen",
	"Vogel", "Santos"]


## The name of whoever has uid `uid`.
static func of(uid: String) -> String:
	return "%s %s" % [FIRST[_mix(uid) % FIRST.size()], surname(uid)]


## Just their surname (for someone the story has given a first name).
static func surname(uid: String) -> String:
	return LAST[(_mix(uid) / FIRST.size()) % LAST.size()]


## A number from the uid that changes all over when one character does (uids differ only in their last digits, and a plain
## string hash moved the surname by nothing: a whole tile were Ivanovas).
static func _mix(uid: String) -> int:
	return uid.md5_text().substr(0, 8).hex_to_int()
