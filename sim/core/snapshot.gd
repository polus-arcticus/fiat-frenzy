## The whole model as plain data, and back. A save is the state of a *started* world laid over a freshly built one: the
## scenario makes everything that is always there (the stands, the streets, the walls), and the snapshot says what has
## changed since, and what has turned up (the bankers, loose bills, the bike).
##
## It reads every script variable of the things that hold state, so a new field is saved without being listed anywhere.
## A thing that must not be saved (a cache, a back-pointer to the world) is simply not a value the codec can carry:
## the world, nodes, callables and footprints are left out. What is left is JSON, with the types JSON lacks tagged:
##   {"i": 3}              an integer inside a container (JSON has only floats)
##   {"var": "Vector2(1, 2)"}   anything else Godot can write as text (vectors, packed arrays, inf)
##   {"dict": {...}}       a dictionary with string keys; {"pairs": [[k, v], ...]} one with other keys
##   {"ref": "drone:4"}    another thing in the world, named by its place in it
##   {"obj": "Inventory", "p": {...}}  a small value object that belongs to whoever holds it
## Headless: no nodes, so it is tested like any other system.
class_name Snapshot
extends RefCounted

const VERSION := 1
## The systems whose state is saved, by their field on the world. (Navigation and Heating are rebuilt by the scenario.)
const SYSTEMS := ["clock", "ledger", "needs", "logistics", "relief", "gun", "commerce", "cash", "levels", "rescue", "chatter",
	"hero", "riding", "sage", "portals", "transit", "skating", "quests", "attention", "zones"]
## Variables that are derived, or computed, and so are never written or read.
const DERIVED := {"Zones": ["_index", "_dirty", "version", "regions"], "Skating": ["mounted"]}
const _OMIT := "<omit>"

var _world: World
var _keys := {}   # Object -> "drone:3"
var _things := {} # "drone:3" -> Object
var _classes := {} # global class name -> script path


func _init(world: World) -> void:
	_world = world
	for c in ProjectSettings.get_global_class_list():
		_classes[c.class] = c.path
	_register()


## Every thing that other things can point at, named by its place in the world.
func _register() -> void:
	_keys.clear()
	_things.clear()
	_name_all("drone", _world.drones)
	_name_all("machine", _world.machines)
	_name_all("food_bank", _world.food_banks)
	_name_all("fire", _world.fires)
	_name_all("truck", _world.relief_trucks)
	_name_all("hospital", _world.hospitals)
	_name_all("ambulance", _world.ambulances)
	_name_all("bill", _world.bills)
	_name_all("portal", _world.portals.all)
	for i in _world.machines.size():
		if _world.machines[i].shelter != null:
			_name("shelter:%d" % i, _world.machines[i].shelter)
	_name("player", _world.player)
	_name("bike", _world.bike)
	_name("bus", _world.bus)
	_name("shuttle", _world.shuttle)


func _name_all(prefix: String, things: Array) -> void:
	for i in things.size():
		_name("%s:%d" % [prefix, i], things[i])


func _name(key: String, thing: Object) -> void:
	if thing != null:
		_keys[thing] = key
		_things[key] = thing


# ---------------------------------------------------------------- writing

## The world as a dictionary that survives JSON.stringify.
func capture() -> Dictionary:
	var things := {}
	for key in _things:
		things[key] = _props(_things[key])
	var systems := {}
	for n in SYSTEMS:
		systems[n] = _props(_world.get(n))
	return {
		"version": VERSION,
		"counts": {"drones": _world.drones.size(), "bills": _world.bills.size(), "bike": _world.bike != null},
		"things": things,
		"systems": systems,
		"world": {"build_zone": _world.build_zone, "gun_owned": _world.gun_owned, "events": _encode(_world.events)},
	}


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

## Lays a saved state over `_world`, which must be a fresh build of the same scenario (and have its player). Returns
## how many drones the fresh world had, so the caller can make views for the ones the save adds.
func apply(data: Dictionary) -> int:
	assert(int(data.get("version", 0)) <= VERSION, "save is from a newer game")
	var fresh_drones := _world.drones.size()
	var counts: Dictionary = data.counts
	while _world.drones.size() < int(counts.drones):
		_world.drones.append(Drone.new(_world.drones.size(), Vector2.ZERO))
	while _world.bills.size() < int(counts.bills):
		_world.bills.append(Bill.new(0.0, "cash"))
	if counts.bike and _world.bike == null:
		_world.bike = Bike.new(Vector2.ZERO)
	_register()
	for key in data.things:
		if _things.has(key):
			_restore(_things[key], data.things[key])
	for n in data.systems:
		_restore(_world.get(n), data.systems[n])
	_world.build_zone = data.world.build_zone
	_world.gun_owned = data.world.gun_owned
	_world.events.assign(_decode(data.world.events, []))
	_world.zones.invalidate()
	return fresh_drones


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


func _make(cls: String) -> Object:
	if not _classes.has(cls):
		return null
	return (load(_classes[cls]) as GDScript).new()
