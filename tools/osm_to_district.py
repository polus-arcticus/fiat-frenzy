#!/usr/bin/env python3
"""Converts an Overpass JSON extract (ways with geometry) into the district file the game loads.

    python3 tools/osm_to_district.py data/raw/strip_raw.json data/bahnhofsviertel.json [--origin LAT,LON]

Coordinates become local metres: x east, z south (so north is -Z, the way Godot's camera looks), around a
fixed origin (by default the middle of the original station extract). The origin is pinned, not worked out from
the extract, so growing the map never moves anything already in it: the scenario, the bike shop and every
building keep their coordinates. Only geometry is kept: footprints, heights, street lines.
"""
import json, math, sys, hashlib

DEFAULT_ORIGIN = (50.1086307, 8.6687641)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
src, dst = args[0], args[1]
origin = DEFAULT_ORIGIN
for a in sys.argv[1:]:
    if a.startswith("--origin="):
        origin = tuple(float(v) for v in a.split("=", 1)[1].split(","))
els = json.load(open(src))["elements"]

lat0, lon0 = origin
KX = 111320.0 * math.cos(math.radians(lat0))
KZ = 110574.0


def bike_lanes(t):
    """[left, right] bike provision of a street from its OpenStreetMap tags: '', 'lane' or 'track' ('separate' and the like are
    ways of their own that we do not read, and 'no' is none)."""
    out = ["", ""]
    for k, v in t.items():
        if k == "cycleway" or k.startswith("cycleway:"):
            if v not in ("lane", "track"):
                continue
            sides = {"cycleway": (0, 1), "cycleway:both": (0, 1), "cycleway:left": (0,), "cycleway:right": (1,)}.get(k, ())
            for i in sides:
                if out[i] != "track":
                    out[i] = v
    return out


def project(p):
    return ((p["lon"] - lon0) * KX, -(p["lat"] - lat0) * KZ)


def signed_area(pts):
    a = 0.0
    for i in range(len(pts)):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % len(pts)]
        a += x1 * z2 - x2 * z1
    return a / 2.0


# Only a few buildings are named in the data (the quest destinations): everything else stays anonymous.
NAMED = {156432555: "Europäische Zentralbank", 112658569: "Europäische Zentralbank"}

DEFAULT_LEVELS = {"apartments": 5, "commercial": 4, "office": 6, "hotel": 5, "public": 3, "residential": 4, "yes": 4}
ROAD_WIDTH = {"primary": 12, "secondary": 9, "tertiary": 8, "residential": 7, "unclassified": 6,
              "pedestrian": 6, "service": 4, "living_street": 5}

buildings, roads = [], []
for e in els:
    t = e["tags"]
    geom = e.get("geometry")
    if not geom:
        continue
    pts = [project(p) for p in geom]
    if "building" in t:
        if len(pts) > 3 and pts[0] == pts[-1]:
            pts = pts[:-1]
        if len(pts) < 3:
            continue
        area = signed_area(pts)
        if abs(area) < 15:
            continue
        if area < 0:
            pts.reverse()  # counter-clockwise
        kind = t["building"]
        if "height" in t:
            try:
                h = float(str(t["height"]).split()[0])
            except ValueError:
                h = None
        else:
            h = None
        if h is None:
            if "building:levels" in t:
                try:
                    levels = max(1, int(float(t["building:levels"])))
                except ValueError:
                    levels = 4
            else:
                base = DEFAULT_LEVELS.get(kind, 4)
                jitter = int(hashlib.md5(str(e["id"]).encode()).hexdigest(), 16) % 3 - 1
                levels = max(2, base + jitter)
            h = levels * 3.3
        else:
            levels = max(1, round(h / 3.3))
        if kind == "roof":
            h, levels = 3.5, 1
        b = {"id": e["id"], "kind": kind, "levels": levels, "h": round(h, 1),
             "poly": [round(c, 1) for p in pts for c in p]}
        if e["id"] in NAMED:
            b["name"] = NAMED[e["id"]]
        buildings.append(b)
    elif "highway" in t:
        cls = t["highway"]
        if cls not in ROAD_WIDTH:
            continue
        r = {"name": t.get("name", ""), "class": cls, "w": ROAD_WIDTH[cls],
             "pts": [round(c, 1) for p in pts for c in p]}
        bike = bike_lanes(t)
        if bike != ["", ""]:
            r["bike"] = bike
        roads.append(r)

# How far each street's pavement runs out to the buildings on either side (the carriageway is only its traffic lanes: the
# rest, out to the building line, is pavement, parking and kerb that OpenStreetMap maps as separate ways we do not read).
_edges = []
for b in buildings:
    q = list(zip(b["poly"][0::2], b["poly"][1::2]))
    for i in range(len(q)):
        _edges.append((q[i], q[(i + 1) % len(q)]))
_cell = 40.0
_grid = {}
for (a, c) in _edges:
    for gx in range(int(min(a[0], c[0]) // _cell) - 1, int(max(a[0], c[0]) // _cell) + 2):
        for gz in range(int(min(a[1], c[1]) // _cell) - 1, int(max(a[1], c[1]) // _cell) + 2):
            _grid.setdefault((gx, gz), []).append((a, c))


def _nearest_building(px, pz, nx, nz, reach=18.0):
    """Distance from (px, pz) along the unit normal (nx, nz) to the first building edge, or None."""
    best = None
    for (a, c) in _grid.get((int(px // _cell), int(pz // _cell)), []):
        # ray from p along n against the segment a-c
        dx, dz = c[0] - a[0], c[1] - a[1]
        den = nx * dz - nz * dx
        if abs(den) < 1e-9:
            continue
        t = ((a[0] - px) * dz - (a[1] - pz) * dx) / den
        u = ((a[0] - px) * nz - (a[1] - pz) * nx) / den
        if 0.3 < t < reach and 0.0 <= u <= 1.0 and (best is None or t < best):
            best = t
    return best


for r in roads:
    pts = list(zip(r["pts"][0::2], r["pts"][1::2]))
    sides = [[], []]
    for i in range(len(pts) - 1):
        (x1, z1), (x2, z2) = pts[i], pts[i + 1]
        length = math.hypot(x2 - x1, z2 - z1)
        if length < 1.0:
            continue
        dx, dz = (x2 - x1) / length, (z2 - z1) / length
        nx, nz = -dz, dx  # the right-hand side of the way, as the game's +normal is
        for k in range(max(1, int(length // 8.0))):
            tt = (k + 0.5) * min(8.0, length / max(1, int(length // 8.0)))
            px, pz = x1 + dx * tt, z1 + dz * tt
            for side, sgn in ((0, -1.0), (1, 1.0)):
                d = _nearest_building(px, pz, nx * sgn, nz * sgn)
                if d is not None:
                    sides[side].append(d)
    half = r["w"] / 2.0
    pave = []
    for side in sides:
        if len(side) >= 2:
            side.sort()
            m = side[len(side) // 2]  # the typical distance to the building line
            pave.append(round(max(half + 1.7, min(m - 0.3, 16.0)), 1))
        else:
            pave.append(round(half + 1.7, 1))
    r["pave"] = pave

xs = [c for b in buildings for c in b["poly"][0::2]] + [c for r in roads for c in r["pts"][0::2]]
zs = [c for b in buildings for c in b["poly"][1::2]] + [c for r in roads for c in r["pts"][1::2]]
out = {"origin": {"lat": lat0, "lon": lon0}, "bounds": [min(xs), min(zs), max(xs), max(zs)],
       "buildings": buildings, "roads": roads}
json.dump(out, open(dst, "w"), separators=(",", ":"))
print("buildings", len(buildings), "roads", len(roads), "bounds", [round(v) for v in out["bounds"]])
