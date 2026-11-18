# Tiles, saves and co-op

The plan is a Planet Crafter-style game where players bring their own part of the world and combine saves. The rules it rests on
are in `docs/ENGINE.md` §6–7.

## Why not a CRDT
Planet Crafter's host owns the world; friends send inputs and get state back. A generic CRDT over the sim's state would break the
invariant that money is only printed (merging two wallets that way makes money). So two saves are merged **three ways, against
their common ancestor**: the tile as its map seeds it.

## Tiles and regions (`engine/core/tile_key.gd`)
- A tile is a web-map tile at zoom 16, about 390 m across at Frankfurt, named `"16/x/y"`. Each tile is a zone.
- Tiles are grouped in zoom-10 regions (64 × 64 tiles, about 25 km). Positions are metres from the region's north-west corner,
  so a `Vector2` stays precise to millimetres.
- Regions will meet through gates (bus, train), not borders.
- Frankfurt's district does not use tiles yet: it keeps its pinned origin and its hand-made zones.

## Heroes
A world can hold several heroes (`World.heroes`). Only the local one is present; the others' pockets (`Ledger.pockets`) and
stakes go on earning.

## Borders (`npc/agents/borders.gd`)
Where two loaded tiles touch:
- a drifter who can't get food or drink at home (or would pay more than $1 over the neighbour's price) crosses over;
- a cart runner hauls a load from one tile's food bank to the other's short shops, at most one cart each way every two minutes.

## Merging (`engine/core/merge.gd`)
`Merge.combine(host, guest, build)`:
- tiles only one save has are taken as they are;
- shared tiles are merged against their seed, field by field, by each class's `MERGE` table.

| rule | meaning | examples |
|---|---|---|
| `sum` | seed + what each save added | wallets, stock, sales, experience, stakes, the ledger |
| `max` / `any` | the larger / true if either | tiers, beds; a stand is working if either save repaired it |
| `union` | both saves' keys | tiles |
| (anything else) | the host's | positions, bars, the story |

`Merge.settle` then:
- scales down stakes over 49% and refunds what the excess was worth;
- cuts stock back to shelf room;
- clears half-done errands;
- retiers;
- works out levels again from experience.

The merged world holds exactly host + guest − seed in money.

Limits: the guest's story state is not carried over, and only the host plays.

## Co-op, later (not built)
- **Live.** The host runs the sim. Clients send commands (`{hero_uid, verb, args}`) and get their tile's changes back, over
  Godot's `MultiplayerPeer`. This needs the hero-facing systems to take a hero instead of reading `world.player`.
- **Cloud.** Versioned saves, with `Merge` run headless on push.
- **Your own streets.** An OSM import for anywhere, written as tiles. The Overpass URLs are named before anything is fetched.
