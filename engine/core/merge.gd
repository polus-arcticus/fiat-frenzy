## Two saves become one world. The host's save (`a`) and a guest's (`b`) may each hold tiles the other does not, and may share
## some: both players started on the same streets. A shared tile has a common ancestor, its **seed** (what building it makes,
## the same every time: see World.mint and World.random), so the merge is three-way, against that seed:
##   - a thing only one save has is kept (unless it was in the seed and the other save got rid of it: a spent bill, gone);
##   - a thing both have is merged field by field by its class's MERGE table: "sum" adds what each save changed since the
##     seed (base + (a - base) + (b - base): wallets, stock, takings, experience, stakes), "max" and "any" are what they say,
##     "union" keeps both saves' keys, and anything else is the host's;
##   - the host's systems (story, quests, the hero at this machine) carry on; the guest's hero joins as one who is away.
## Money is neither made nor lost: the merged world holds exactly a + b - seed. `settle` then puts right what adding up can
## put wrong: the 49% cap on stakes (the excess is refunded, owner to hero), stock over a shelf's room, half-done errands.
##
## Works on Snapshot data (plain JSON), so it is the same code whether the saves come from two files, a co-op host and a
## friend joining, or a cloud store of tiles.
class_name Merge
extends RefCounted

static var _system_classes := {}  # a saved system's field on the world -> its class (read off a world, once: see _system_class)

static var _rules_cache := {}


## The whole thing: `build` makes a freshly seeded world of the tiles it is given (an Array of tile keys), the same way both
## saves' tiles were made. Returns the merged world, settled.
static func combine(a: Dictionary, b: Dictionary, build: Callable) -> World:
	var tiles_a := tiles_of(a)
	var tiles_b := tiles_of(b)
	var shared := tiles_a.filter(func(t): return t in tiles_b)
	var every := tiles_a + tiles_b.filter(func(t): return not t in tiles_a)
	var base := _json(Snapshot.new(build.call(shared)).capture())
	var w: World = build.call(every)
	Snapshot.new(w).apply(merge(_json(a), _json(b), base))
	settle(w)
	return w


## The tile keys a save holds.
static func tiles_of(data: Dictionary) -> Array:
	return (data.systems.zones.tiles.dict as Dictionary).keys()


## Snapshot data for the merged world. All three are Snapshot.capture() data that has been through JSON.
static func merge(a: Dictionary, b: Dictionary, base: Dictionary) -> Dictionary:
	var things := {}
	var gone := {}
	for uid in a.things:
		if b.things.has(uid):
			if base.things.has(uid):
				var t: Dictionary = a.things[uid]
				things[uid] = {"cls": t.cls, "p": _props(t.cls, base.things[uid].p, t.p, b.things[uid].p)}
			else:
				things[uid] = a.things[uid]  # (both made it in play: one save and a copy of it)
		elif base.things.has(uid):
			gone[uid] = true  # the guest's save got rid of it
		else:
			things[uid] = a.things[uid]
	for uid in b.things:
		if a.things.has(uid):
			continue
		if base.things.has(uid):
			gone[uid] = true  # the host's save got rid of it
		else:
			things[uid] = b.things[uid]
	var lists := {}
	for list in a.lists:
		var out: Array = (a.lists[list] as Array).filter(func(u): return things.has(u))
		for u in b.lists.get(list, []):
			if things.has(u) and not u in out:
				out.append(u)
		lists[list] = out
	var systems := {}
	for n in a.systems:
		var cls := _system_class(n)
		if not _rules(cls).is_empty() and b.systems.has(n) and base.systems.has(n):
			systems[n] = _props(cls, base.systems[n], a.systems[n], b.systems[n])
		else:
			systems[n] = a.systems[n]
	var world: Dictionary = a.world.duplicate(true)
	world["_seeded"] = _value("max", base.world._seeded, a.world._seeded, b.world._seeded)
	return {"version": a.version, "things": things, "lists": lists, "singles": a.singles, "systems": systems, "world": world}


## After the merged data is laid on a world: what adding up may have put wrong.
static func settle(w: World) -> void:
	for d in w.drones + w.heroes:  # half-done errands are dropped: everyone plans afresh in the merged town
		d.job = {}
		d.route = PackedVector2Array()
		d.route_goal = Vector2(INF, INF)
		d.route_nav = -1
		if d.sheltered_in != null:
			d.sheltered_in.release(d)
		_relevel(d.growth)
		if d.runner != null:
			_cap(w, d.runner.equity, d, d.runner.equity.value(Runner.CART_VALUE, d.growth.xp), d.label + "'s cart")
	for m in w.machines:
		var ladder: Array = Catalog.TRADES.get(m.trade, [])
		if m.tier < ladder.size() and ladder[m.tier] != "":
			m.retier(ladder[m.tier])  # (the higher tier of the two saves: its kind, recipe and shelf follow)
		m.line.clear()
		m.service_left = -1.0
		if m.shelter != null:
			m.shelter.berths.clear()
		var owner := w.drone(m.owner)
		if owner != null and owner.growth != m.growth:
			_relevel(m.growth)
		m.set_level(m.growth.level)
		_clamp(m.input)
		_clamp(m.output)
		_cap_stakes(w, m)
	for b in w.bins:
		_clamp(b.output)
	for f in w.fires:
		f.shelter.berths.clear()
	w.reindex()


# Together the heroes may own at most Equity.MAX_STAKE of a business. Over it (each save bought up to the cap on its own),
# every stake is scaled down to fit, and what the excess was worth goes back from the owner to each hero, as far as the
# owner's wallet goes: money moves, nothing is made.
static func _cap_stakes(w: World, m: Machine) -> void:
	_cap(w, m.equity, w.drone(m.owner), m.value(), "the " + m.display_name())


# The same for any business: `e` its stakes, `owner` who refunds, `worth` what it is worth.
static func _cap(w: World, e: Equity, owner: Drone, worth: float, what: String) -> void:
	var total := e.stake
	if total <= Equity.MAX_STAKE + 1e-9:
		return
	var keep := Equity.MAX_STAKE / total
	var owed := {}
	var owed_total := 0.0
	for h in e.stakes:
		owed[h] = e.stakes[h] * (1.0 - keep) * worth
		owed_total += owed[h]
		e.stakes[h] *= keep
	var can := minf(owed_total, owner.wallet if owner != null else 0.0)
	if can <= 0.0:
		return
	for h in owed:
		var back: float = can * owed[h] / owed_total
		owner.wallet -= back
		w.ledger.pockets[h] = float(w.ledger.pockets.get(h, 0.0)) + back
	w.events.append("t=%d stakes in %s were over the cap after the merge: $%.2f refunded" % [w.clock.time, what, can])


static func _clamp(inv: Inventory) -> void:
	for item in inv.counts:
		if inv.caps.has(item) and inv.counts[item] > inv.caps[item]:
			inv.counts[item] = inv.caps[item]


static func _relevel(g: Growth) -> void:
	g.level = 1
	g.add(0.0)


# ---------------------------------------------------------------- field by field

# The merged properties of one thing of class `cls`.
static func _props(cls: String, base_p: Dictionary, a_p: Dictionary, b_p: Dictionary) -> Dictionary:
	var rules := _rules(cls)
	var out := {}
	for key in a_p:
		out[key] = _value(rules.get(key, ""), base_p.get(key), a_p[key], b_p.get(key)) if b_p.has(key) else a_p[key]
	for key in b_p:
		if not a_p.has(key):
			out[key] = b_p[key]
	return out


# One encoded value (see Snapshot's codec), by rule.
static func _value(rule: String, base: Variant, a: Variant, b: Variant) -> Variant:
	match rule:
		"sum":
			return _sum(base, a, b)
		"max":
			return _max(a, b)
		"any":
			return a or b
		"union":
			if a is Dictionary and a.has("dict") and b is Dictionary and b.has("dict"):
				var d: Dictionary = (b.dict as Dictionary).duplicate()
				d.merge(a.dict, true)
				return {"dict": d}
	if a is Dictionary and a.has("obj") and b is Dictionary and b.has("obj") and a.obj == b.obj:
		var bp: Dictionary = base.p if base is Dictionary and base.has("p") else {}
		return {"obj": a.obj, "p": _props(a.obj, bp, a.p, b.p)}
	return a


static func _sum(base: Variant, a: Variant, b: Variant) -> Variant:
	if a is Dictionary and a.has("dict") or b is Dictionary and b.has("dict"):
		var da: Dictionary = a.dict if a is Dictionary and a.has("dict") else {}
		var db: Dictionary = b.dict if b is Dictionary and b.has("dict") else {}
		var d0: Dictionary = base.dict if base is Dictionary and base.has("dict") else {}
		var out := {}
		for k in da.keys() + db.keys():
			if not out.has(k):
				out[k] = _sum(d0.get(k), da.get(k), db.get(k))
		return {"dict": out}
	var tagged: bool = (a is Dictionary and a.has("i")) or (b is Dictionary and b.has("i"))
	var n := _num(a) + _num(b) - _num(base)
	return {"i": roundi(n)} if tagged else n


static func _max(a: Variant, b: Variant) -> Variant:
	if a is Dictionary and a.has("dict") and b is Dictionary and b.has("dict"):
		var out: Dictionary = (b.dict as Dictionary).duplicate()
		for k in a.dict:
			out[k] = _max(a.dict[k], out[k]) if out.has(k) else a.dict[k]
		return {"dict": out}
	return a if _num(a) >= _num(b) else b


static func _num(v: Variant) -> float:
	if v == null:
		return 0.0
	if v is Dictionary and v.has("i"):
		return float(v.i)
	return float(v)


# The class of the system the world keeps in field `n` (World.SAVED), or "".
static func _system_class(n: String) -> String:
	if _system_classes.is_empty():
		var w := World.new()
		for field in World.SAVED:
			var s: Object = w.get(field)
			_system_classes[field] = s.get_script().get_global_name() if s != null and s.get_script() != null else ""
	return _system_classes.get(n, "")


# A class's MERGE table (field -> rule), or {} if it has none.
static func _rules(cls: String) -> Dictionary:
	if not _rules_cache.has(cls):
		var rules := {}
		for c in ProjectSettings.get_global_class_list():
			if c.class == cls:
				var m = (load(c.path) as GDScript).get_script_constant_map().get("MERGE")
				if m is Dictionary:
					rules = m
		_rules_cache[cls] = rules
	return _rules_cache[cls]


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
