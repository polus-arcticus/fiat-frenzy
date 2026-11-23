## The whole model as plain data, and back. A save is the state of a *started* world laid over a freshly built one: the
## scenario makes everything that is always there (the stands, the streets, the walls), and the snapshot says what has
## changed since, and what has turned up (the bankers, loose bills) or gone (a bill picked up).
##
## Everything is named by its uid (see World.mint), never by its place in a list, so a thing keeps its name across saves
## and two saves can be combined (see Merge). The lists are saved as lists of uids, in their order.
##
## It reads every script variable of the things that hold state, so a new field is saved without being listed anywhere.
## A thing that must not be saved (a cache, a back-pointer to the world) is simply not a value the codec can carry:
## the world, nodes, callables and footprints are left out. What is left is JSON, with the types JSON lacks tagged:
##   {"i": 3}              an integer inside a container (JSON has only floats)
##   {"var": "Vector2(1, 2)"}   anything else Godot can write as text (vectors, packed arrays, inf)
##   {"dict": {...}}       a dictionary with string keys; {"pairs": [[k, v], ...]} one with other keys
##   {"ref": "district#4"} another thing in the world, by its uid (a shelter is "<its owner's uid>.shelter")
##   {"obj": "Inventory", "p": {...}}  a small value object that belongs to whoever holds it
## Headless: no nodes, so it is tested like any other system.
class_name Snapshot
extends RefCounted

const VERSION := 6  # (3: the hero's bike is in their loadout, Drone.gear; 4: bins (WasteBin) for scrap piles, no food bank;
                    # 5: the bottle depot (Deposit) for the welfare office; 6: a runner's cart business is a component,
                    # Drone.runner, and a tent city's homes, Machine.residence)
## The systems whose state is saved: World.SAVED, the one list.
const SYSTEMS := World.SAVED
## Variables that are derived, or computed, and so are never written or read.
const DERIVED := {"Zones": ["_index", "_dirty", "version", "regions"], "Rescue": ["on_admitted"], "Chatter": ["_said"], "Machine": ["shelter"], "Skating": ["mounted"], "Portals": ["all"],
	"Ledger": ["player_cash", "stake_income"], "Equity": ["stake"]}
## The world's lists of things, and the class each holds (a thing the save has and the fresh world lacks is made from it).
const LISTS := {"drones": "Drone", "machines": "Machine", "bins": "WasteBin", "fires": "BarrelFire",
	"relief_trucks": "ReliefTruck", "hospitals": "Hospital", "ambulances": "Ambulance", "bills": "Bill", "heroes": "Drone",
	"bottle_depots": "BottleDepot"}
## The things the world holds one of, by its field, and their class.
const SINGLES := {"player": "Drone", "bus": "Bus", "shuttle": "Bus"}
## The world's own fields that are saved.
const WORLD_FIELDS := ["build_zone", "gun_owned", "author", "seeding", "_seeded", "_made", "rng_state"]
const _OMIT := "<omit>"

var _world: World
var _keys := {}   # Object -> uid
var _things := {} # uid -> Object
var _classes := {} # global class name -> script path


func _init(world: World) -> void:
	_world = world
	for c in ProjectSettings.get_global_class_list():
		_classes[c.class] = c.path
	_register()


## Every thing that other things can point at, by its uid. (Anything not yet named, say one a test made by hand, is named now.)
func _register() -> void:
	_keys.clear()
	_things.clear()
	for list in LISTS:
		for t in _world.get(list):
			_name(t)
	for t in _world.portals.all:
		_name(t)
	for field in SINGLES:
		_name(_world.get(field))


func _name(thing: Object) -> void:
	if thing == null:
		return
	if thing.uid == "":
		_world.mint(thing)
	_keys[thing] = thing.uid
	_things[thing.uid] = thing
	var shelter = thing.get("shelter")
	if shelter != null:
		_keys[shelter] = thing.uid + ".shelter"
		_things[thing.uid + ".shelter"] = shelter


# ---------------------------------------------------------------- writing

## The world as a dictionary that survives JSON.stringify.
func capture() -> Dictionary:
	var things := {}
	var lists := {}
	for list in LISTS:
		lists[list] = (_world.get(list) as Array).map(func(t): return t.uid)
	lists["portals"] = _world.portals.all.map(func(t): return t.uid)
	var singles := {}
	for field in SINGLES:
		var t: Object = _world.get(field)
		singles[field] = t.uid if t != null else null
	for key in _things:  # (a shelter is saved too: who has a berth in it)
		things[key] = {"cls": _class_of(_things[key]), "p": _props(_things[key])}
	var systems := {}
	for n in SYSTEMS:
		if _world.get(n) != null:  # (an engine-only world has no hero's or story's systems)
			systems[n] = _props(_world.get(n))
	var world := {"events": _encode(_world.events)}
	for f in WORLD_FIELDS:
		world[f] = _encode(_world.get(f))
	return {"version": VERSION, "things": things, "lists": lists, "singles": singles, "systems": systems, "world": world}


func _props(obj: Object, leave_out: Array = []) -> Dictionary:
	var out := {}
	var derived: Array = DERIVED.get(_class_of(obj), [])
	for p in obj.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = p.name
		if name in derived or name in leave_out:
			continue
		var v: Variant = _encode(obj.get(name), p.type == TYPE_INT or p.type == TYPE_BOOL or p.type == TYPE_STRING)
		if not (v is String and v == _OMIT):
			out[name] = v
	return out


func _class_of(obj: Object) -> String:
	var s: Script = obj.get_script()
	return s.get_global_name() if s != null else ""


## `plain`: the value's own type says what it is (a typed variable), so an int needs no tag.
func _encode(v: Variant, plain := false) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_INT:
			return v if plain else {"i": v}
		TYPE_FLOAT:
			return v if is_finite(v) else {"var": var_to_str(v)}
		TYPE_ARRAY:
			var arr := []
			for item in v:
				var e: Variant = _encode(item)
				if not (e is String and e == _OMIT):
					arr.append(e)
			return {"list": arr}
		TYPE_DICTIONARY:
			var all_strings := true
			for k in v:
				all_strings = all_strings and k is String
			if all_strings:
				var d := {}
				for k in v:
					var e: Variant = _encode(v[k])
					if not (e is String and e == _OMIT):
						d[k] = e
				return {"dict": d}
			var pairs := []
			for k in v:
				var ek: Variant = _encode(k)
				var ev: Variant = _encode(v[k])
				if not (ev is String and ev == _OMIT) and not (ek is String and ek == _OMIT):
					pairs.append([ek, ev])
			return {"pairs": pairs}
		TYPE_OBJECT:
			return _encode_object(v)
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return _OMIT
	return {"var": var_to_str(v)}


func _encode_object(o: Object) -> Variant:
	if o == null:
		return null
	if _keys.has(o):
		return {"ref": _keys[o]}
	if o is World or o is Node or o is Footprint or o is RandomNumberGenerator:
		return _OMIT
	var cls := _class_of(o)
	if cls == "" or not _classes.has(cls):
		return _OMIT  # an inner class: a cache of some system
	return {"obj": cls, "p": _props(o)}


# ---------------------------------------------------------------- reading

## Lays a saved state over `_world`, which must be a fresh build of the same scenario (and have its player). Things the
## save has and the fresh world lacks are made; things the fresh world has and the save lacks are gone; the lists are put in
## the save's order. Returns the drones that were made; everything made is also put in World.arrivals, for views.
func apply(data: Dictionary) -> Array[Drone]:
	assert(int(data.get("version", 0)) == VERSION, "save is from another version of the game")
	var made: Array[Drone] = []
	for field in SINGLES:  # the fresh world's hero (or bus) is the saved one, whatever it was named when it was made
		var mine: Object = _world.get(field)
		var saved = data.singles[field]
		if mine != null and saved != null and mine.uid != saved:
			_things.erase(mine.uid)
			mine.uid = saved
			_name(mine)
	for uid in data.things:  # first everything exists, so that references between them resolve...
		if not _things.has(uid) and not uid.ends_with(".shelter"):  # (a shelter is made by its tent or fire)
			var t := _make(data.things[uid].cls, data.things[uid].p)
			t.uid = uid
			_name(t)
			_world.arrivals.append(t)
			if t is Drone:
				made.append(t)
	for list in LISTS:
		var arr: Array = _world.get(list)
		arr.clear()
		for uid in data.lists[list]:
			arr.append(_things[uid])
	_world.portals.all.clear()
	for uid in data.lists.portals:
		_world.portals.all.append(_things[uid])
	for field in SINGLES:
		var uid = data.singles[field]
		_world.set(field, _things[uid] if uid != null and _things.has(uid) else null)
	for uid in data.things:  # ...then each is filled in
		if _things.has(uid):
			_restore(_things[uid], data.things[uid].p)
	for n in data.systems:
		if _world.get(n) != null:
			_restore(_world.get(n), data.systems[n])
	for f in WORLD_FIELDS:
		_world.set(f, _decode(data.world[f], _world.get(f)))
	_world.events.assign(_decode(data.world.events, []))
	_world.reindex()
	return made.filter(func(d): return _world.drones.has(d))  # (a hero who is away is made too, but is nobody to draw)


func _restore(obj: Object, props: Dictionary) -> void:
	for name in props:
		var cur: Variant = obj.get(name)
		obj.set(name, _decode(props[name], cur))


func _decode(v: Variant, current: Variant) -> Variant:
	if v == null:
		return null
	if typeof(v) == TYPE_FLOAT and typeof(current) == TYPE_INT:
		return int(v)
	if typeof(v) != TYPE_DICTIONARY:
		return v
	if v.has("i"):
		return int(v.i)
	if v.has("var"):
		return str_to_var(v.var)
	if v.has("ref"):
		return _things.get(v.ref)
	if v.has("list"):
		var old: Array = current.duplicate() if current is Array else []
		var arr: Array = current if current is Array else []
		arr.clear()
		for i in v.list.size():
			arr.append(_decode(v.list[i], old[i] if i < old.size() else null))
		return arr
	if v.has("dict"):
		var old_d: Dictionary = current.duplicate() if current is Dictionary else {}
		var d: Dictionary = current if current is Dictionary else {}
		d.clear()
		for k in v.dict:
			d[k] = _decode(v.dict[k], old_d.get(k))
		return d
	if v.has("pairs"):
		var d2: Dictionary = current if current is Dictionary else {}
		d2.clear()
		for pair in v.pairs:
			d2[_decode(pair[0], null)] = _decode(pair[1], null)
		return d2
	if v.has("obj"):
		var target: Object = current if current is Object and _class_of(current) == v.obj else _make(v.obj)
		if target != null:
			_restore(target, v.p)
		return target
	return null


## A new thing of class `cls`, about to be filled in from `props`. A machine is made as its kind, so that it has the parts
## its kind has (a tent's shelter).
func _make(cls: String, props := {}) -> Object:
	if cls == "Machine" and props.has("kind"):
		return Machine.new(props.kind)
	if not _classes.has(cls):
		return null
	return (load(_classes[cls]) as GDScript).new()
