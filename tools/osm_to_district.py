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
        roads.append({"name": t.get("name", ""), "class": cls, "w": ROAD_WIDTH[cls],
                      "pts": [round(c, 1) for p in pts for c in p]})

xs = [c for b in buildings for c in b["poly"][0::2]] + [c for r in roads for c in r["pts"][0::2]]
zs = [c for b in buildings for c in b["poly"][1::2]] + [c for r in roads for c in r["pts"][1::2]]
out = {"origin": {"lat": lat0, "lon": lon0}, "bounds": [min(xs), min(zs), max(xs), max(zs)],
       "buildings": buildings, "roads": roads}
json.dump(out, open(dst, "w"), separators=(",", ":"))
print("buildings", len(buildings), "roads", len(roads), "bounds", [round(v) for v in out["bounds"]])
