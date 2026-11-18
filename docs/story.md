# The story: places, quests and the scripted cast

The quest and animatronic space: what is scripted rather than simulated. The engine's rules are in `docs/ENGINE.md`.

## The design note: the gun is a curse

The undertone of the whole game: **the money gun is not a gift, it is a curse the hero carries** (think of Ashitaka's arm in
*Princess Mononoke*). It is never said outright. The game shows it, and every feature should lean the same way:
- The hero **cannot put it down or give it up**: no unequip, no drop, no sale.
- **Nobody asks for the gun.** They ask for the bills.
- When the hero collapses, the **money is stolen but the gun is not**.
- **The ECB** is where a player expects the gun to be taken at the gate. It is not, and that is the point. Nobody at the bank
  looks at it, asks about it or touches it, and no one names the curse.
- **The end is inflation.** However well the hero plays, printing scales until inflation overtakes everything. That is the end
  of the game, not a failure state.
- **Where the money goes decides how it ends.** Print for learning (the *trivium and quadrivium*) and the welfare of many, and the
  hero escapes the gravity well. Print for vice, and the hero ends on the skull throne in the sand kingdom.

## The map

The district runs from the Hauptbahnhof east along Battonnstraße to the European Central Bank on Sonnemannstraße:
- 2,890 buildings, from OpenStreetMap through `tools/osm_to_district.py` into `data/bahnhofsviertel.json`;
- the origin is pinned, so growing the map never moves anything already in it;
- streets carry their pavement width (`pave`) and bike lanes.

Landmarks are drawn with character (`engine/view/world/landmarks.gd`):
- the ECB tower and the Grossmarkthalle;
- the Paulskirche;
- the Kaiserdom;
- the Einheitsdenkmal;
- the Hauptbahnhof's reception building and train halls.

## The landing street (`story/town/scenario.gd`)

The game opens at 6:47 on Kaiserstraße: a helicopter of bankers crashes, and the money gun drops at the hero's feet
(`IntroController`). Laid out across the street's width (`Scenario._spot`):
- the first market at the kerb: a hot dog stand, a bakery, a lemonade stand;
- the tent against the buildings, and the barrel fire;
- the food bank and two cart runners 40 m down the street;
- the medical tent and its ambulance bay;
- the welfare office;
- the bus stop.

Every stand starts wrecked and every vendor broke: nothing runs until the hero funds it.

## The tutorial (`story/quests/tutorial.gd`)

The tutorial is a set of goals that are open together, not a list: meet the vendors, fund each stand, buy into the bakery, feed
the bankers. The main goal is shown with the others as "Also open", and the beacon points at the nearest. People who need the
hero's help glow gold (`story/quests/attention.gd`).

## The shops (`story/town/scenario.gd`, `user/bike`, `user/skating`)

- **The bike shop** is OSM building 174326357, with a door cut into it. Its rich owner sells one bicycle for $3,000, and the
  business is worth $2 million, so investing in it gets nowhere. Press F next to the bike to ride: about 2.4× walking speed.
- **The skate shop** is next door (`MapSites.neighbour`), selling complete boards at $120.

## Mr. Nobody (`story/sage/`)

On Battonnstraße lives **Mr. Nobody**, a vague, whimsical sage in a suit with a small red pin. He is a "Stranger" until he says
who he is, and the one thing that marks him out is that he never bends down for loose money.
- He notices the gun within 12 m and asks the hero into his house.
- He tells stories of the money of all ages from a menu that grows with the hero's level (`stories.gd` is data). The stories are
  about scarcity, trust and promises, never about what kind of people handle money; a test keeps it that way.
- Later: his upgrades are earned by bringing him insects and building materials.

## Quests (`story/quests/quest_book.gd`, `quests.gd`)

1. **The letter for the bank.** Once every stand runs and each banker has eaten, the bankers ask (Q at any of them) for a letter
   to be taken to the ECB, and it goes in the bag.
2. **The bus.** E at the stop: the bus drives itself 1.5 km along the real streets (`user/transit/`) to a traffic jam outside
   Mr. Nobody's house. The jam clears when the hero says farewell to him, and the bus carries on to the bank. The sim never stops
   during the ride. Money fired inside the bus stays in its frame and is gathered when the hero gets off.
3. **The gate** (`story/ecb/`). The doorman reads the letter and lifts the barrier. The **shuttle**, a golf cart, drives the
   hero about 400 m to the tower's door, where the **receptionist** takes the letter.
4. **Instrument maintenance.** A lift beside the desk goes to a room of its own (zone `ecb_lift`). There the technician's bench
   will be the gun's tech tree; for now he only talks.

## The market at the bank

Across from the gate is a market of its own: a lemonade stand, a hot dog stand and a bakery (wrecked), a food bank and a runner,
a medical tent, and three visitors. It is a zone of its own (`"ecb"`, a rectangle in `Zones.regions`), asleep until the hero gets
there, so the first market's people never trek 2 km to it.

## The scripted cast (animatronics)

Characters that do not follow the town's rules:
- Mr. Nobody;
- the ECB doorman, receptionist and technician;
- the bankers, who arrive by helicopter and need feeding.

They are needless and aloof agents, placed by the scenario and held by role in the story's `Cast` (`story/town/cast.gd`), which
the world carries as `World.cast` without looking inside.

## Jumping ahead (developer)

In a debug build the pause menu has "Dev: jump forward to", or start with `godot --path . -- --skip-intro --stage=<id>`. The ids
are offer, jam, bus, gate, inside, desk, lift and room (`DevStageController`). `tools/check_stages.gd` runs them all.

## Designed, not built

- **The seven sins and seven virtues.** Who the hero prints at decides what world rises.
- **The block tier.** Neighbouring blocks merge into districts.
- **Parked** (built once, in `~/proto/ff3d-parked/`): banks and rent, zombies, tech trees, sins and virtues.
