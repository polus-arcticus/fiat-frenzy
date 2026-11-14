## Says what a drone is doing and why, in plain lines: who it is, how it is, its job and where it is walking, and, when it
## has no job, what it wants and why nothing answers. A read-only look at the model (it changes nothing), so it is tested
## headless; the inspector's screen only shows what this says.
class_name Inspector
extends RefCounted

## `still_for`: how long (seconds) the drone has stayed in one place, if the caller has been watching.
static func lines(w: World, d: Drone, still_for := 0.0) -> PackedStringArray:
	var out := PackedStringArray()
	var name := d.label if d.label != "" else d.kind
	out.append("#%d  %s    (%s%s)" % [d.id, name, d.kind, ", looks like a %s" % d.look if d.look != "" and d.look != d.kind else ""])
	out.append("zone %s (%s)   at (%.1f, %.1f)" % [d.zone, "running" if w.is_active(d.zone) else "dormant", d.pos.x, d.pos.y])
	out.append("wallet $%.2f    thinks of you %.2f    level %d" % [d.wallet, d.rep, d.growth.level])
	out.append("hunger %.2f   thirst %.2f   warmth %.2f" % [d.bars.hunger, d.bars.thirst, d.bars.warmth])
	var flags := PackedStringArray()
	if d.aloof:
		flags.append("ALOOF (takes no part in errands)")
	if d.needless:
		flags.append("NEEDLESS (no needs)")
	if d.sheltered_in != null:
		flags.append("sheltered (sitting at a fire or in a tent)")
	if d.care != "":
		flags.append("CARE: %s" % d.care)
	out.append("state: %s" % (", ".join(flags) if not flags.is_empty() else "fit and free"))
	if d.job.is_empty():
		out.append("JOB: none")
		out.append_array(_why_idle(w, d))
	else:
		var stand: Vector2 = d.job.get("stand", Vector2.INF)
		out.append("JOB: %s -> %s" % [d.job.get("for", "?"), _thing(d.job.get("target"))])
		if stand.is_finite():
			out.append("     to stand at (%.1f, %.1f), %.1f m away" % [stand.x, stand.y, d.pos.distance_to(stand)])
		if d.job.has("stage"):
			out.append("     stage: %s" % d.job.stage)
	if d.route.is_empty():
		out.append("ROUTE: none")
	else:
		var last: Vector2 = d.route[d.route.size() - 1]
		out.append("ROUTE: %d waypoints, next (%.1f, %.1f), last (%.1f, %.1f)" % [d.route.size(), d.route[0].x, d.route[0].y, last.x, last.y])
	if still_for >= 5.0:
		out.append("NOT MOVED for %d s%s" % [int(still_for), " while on a job: STUCK?" if not d.job.is_empty() else ""])
	return out


## A thing a job aims at, in a few words.
static func _thing(t) -> String:
	if t == null:
		return "nothing"
	if t is Machine:
		return "%s at (%.0f, %.0f)" % [t.display_name(), t.pos.x, t.pos.y]
	if t is Bill:
		return "a $%.2f bill at (%.1f, %.1f)" % [t.value, t.pos.x, t.pos.y]
	if "pos" in t:
		return "%s at (%.0f, %.0f)" % [t.get_script().get_global_name() if t.get_script() != null else "thing", t.pos.x, t.pos.y]
	return str(t)


## No job: what they want, and what the town can give them.
static func _why_idle(w: World, d: Drone) -> PackedStringArray:
	var out := PackedStringArray()
	if d.unconscious() or d.sheltered_in != null or d.aloof:
		out.append("     (not looking for work in this state)")
		return out
	var wants: Array = w.needs.demands(d)
	if wants.is_empty():
		out.append("     wants nothing right now")
		return out
	out.append("     wants: %s" % ", ".join(PackedStringArray(wants)))
	for cls in ["food", "drink"]:
		if cls in wants:
			var offering := 0
			var affordable := 0
			for m in w.zones.machines_in(d.zone):
				if Catalog.class_of(m.item) == cls and m.offers(m.item):
					offering += 1
					if m.price <= d.wallet:
						affordable += 1
			out.append("     %s: %d stand(s) have it, %d he can afford" % [cls, offering, affordable])
	var plan := w.logistics.plan(d)
	out.append("     the planner would send them: %s" % (("%s -> %s" % [plan.get("for"), _thing(plan.get("target"))]) if not plan.is_empty() else "nowhere (nothing to go for)"))
	return out
