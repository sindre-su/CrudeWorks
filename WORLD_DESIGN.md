# CrudeWorks Graybox World Design

## Purpose and current boundary

This is the authoritative spatial brief for the CrudeWorks V1 Graybox World.
It translates `CRUDEWORKS_VISION.md` into a compact, traversable refinery
geography without prescribing final art, final equipment count or vehicles.

**Implementation status: v0.31.5 Process Boundary Connections.** The
world reads Harbor -> Lower Plant -> Main Plant -> Upper Plant, but those names
now describe progression districts rather than four giant physical shelves.
One continuous terrain mesh rises inland and contains locally level industrial
pads, roads, paths and the Pilot process surface.

The first functional migration slice is now active: stable portless CI-101 and
PD-101 terminals exist once at their Harbor zones, while fixed CI-201 and
PD-201 process boundaries keep player pipework at the Area 02 edges. Pilot,
Area 02 building and every other process, utility, LAB and storage system remain
in place. Normal fresh-game
progression continues from Pilot through Harbor CI to Area 02. The Process Scope
Freeze remains in force.

## Scale and coordinate convention

One Godot unit is approximately one metre. World x is east/west; world z is
north/south. North/inland is negative z. South/outward and the sea are positive
z.

- player bounds: x `-42..172`, z `-200..68` — **214 x 268 m**;
- visible playable land: x `-42..172`, z `-200..64` — **214 x 264 m**;
- canonical spawn: `(-10, 0.1, 8)` in the Harbor Pilot footprint;
- shoreline: z `64`; deep-water recovery: z `64.5+`;
- main-road x: `52`;
- Harbor-to-Upper route: approximately `248 m`, or `41 s` at the current
  normal 6 m/s walk speed before small route variation.

The v0.31.0 meaningful footprint was 230 x 395 m and the human-tested walk was
about 60 seconds. v0.31.1 reduces longitudinal spread by about 33% and
meaningful land area by about 38%, while leaving local service/build space.

## Natural grade and local pads

Harbor remains flat at 0 m through z `-42`. From there, one broad grade rises
continuously to +10.5 m at z `-200`, an average grade of about 6.6%. There are
no map-wide retaining walls and no separate terrace ramps.

The canonical progression districts are:

| District | Center x/z | Planning footprint | Local pad elevation |
| --- | ---: | ---: | ---: |
| Harbor | `65 / 11` | 214 x 106 m | 0 m |
| Lower Plant | `65 / -75` | 214 x 38 m | +3.5 m |
| Main Plant | `65 / -127` | 214 x 42 m | +7.0 m |
| Upper Plant | `65 / -178` | 214 x 36 m | +10.5 m |

Process areas are flat regions shaped into the continuous terrain mesh. A 6 m
transition blends each pad into the surrounding macro grade, producing local
embankments rather than full-width steps. The single terrain mesh owns both
rendering and collision. Road, path, Pilot-pad and area materials are surfaces
within that mesh, not stacked floor overlays.

## Compact area plan

| Area ID | Center x/z | Footprint | Elevation | Role |
| --- | ---: | ---: | ---: | --- |
| `pilot_plant` | `-10 / 5` | 55 x 42 m | 0 m | Contained functional tutorial. |
| `crude_intake` | `31 / 49` | 26 x 18 m | 0 m | Functional CI-101 intake. |
| `product_dispatch` | `138 / 49` | 34 x 18 m | 0 m | Functional PD-101 dispatch. |
| `operations_hub` | `120 / -10` | 80 x 60 m | +0.75 m | Unchanged functional Area 02 process yard. |
| `crude_storage` | `-15 / -75` | 38 x 26 m | +3.5 m | Future crude tank block. |
| `cdu` | `26 / -75` | 28 x 26 m | +3.5 m | First atmospheric block. |
| `ht` | `78 / -75` | 28 x 26 m | +3.5 m | Treatment block. |
| `utilities` | `113 / -75` | 34 x 26 m | +3.5 m | Utilities reservation. |
| `product_storage` | `-9 / -128` | 50 x 36 m | +7.0 m | Product tank block. |
| `control_room` | `30 / -116` | 20 x 14 m | +7.0 m | Future central supervision shell. |
| `lab` | `30 / -138` | 20 x 14 m | +7.0 m | Analytical shell beside Control. |
| `maintenance` | `87 / -128` | 46 x 34 m | +7.0 m | Workshop/service block. |
| `vdu` | `-8 / -178` | 48 x 28 m | +10.5 m | Future VDU block. |
| `fcc` | `31 / -178` | 22 x 28 m | +10.5 m | Future FCC block. |
| `future_expansion` | `87 / -178` | 46 x 28 m | +10.5 m | Approved-later expansion. |

The functional Area 02 footprint is intentionally not reduced because its
build rectangle, endpoint anchors, construction saves and player layouts share
that contract. Non-functional future pads carry the intimacy reduction.

## Roads, Harbor and wayfinding

The 8 m main road has two edge-matched canonical pieces: a flat Harbor section
from z `64..-42`, then one continuous z `-42..-200` inland grade. Short 5 m
service corridors terminate at its edges and never overlap it. Downhill points
to Harbor; uphill points deeper into the refinery.

Visible Harbor land ends exactly at z `64`, where one continuous physical quay
safety edge blocks the player. Water begins beyond it and recovery remains a
fallback for genuine boundary escape. The old separate south boundary and
segmented parallel quay barrier were removed; Harbor has one barrier for one
purpose.

Leaving Pilot, the `pilot_access` / main-road junction at `(48, 5)` has one
west-approach `CRUDE INTAKE / CI-101 →` sign. It derives its direction from the
live CI area center and supports the real post-Pilot objective without a HUD
waypoint. Harbor CI-101 and PD-101 are logistics terminals without process
ports. Their physical process continuations are CI-201 and PD-201 at the Area
02 west/east boundaries.

The next meaningful Harbor decision is the main-road / `area02_access` fork at
`(56, -10)`: continuing north reaches the inland grade, while turning east
reaches the active Area 02 yard. A complete Harbor-facing sign sits just before
that fork at `(45.5, 0, -4)` and reads `AREA 02 / PROCESS YARD →`; its arrow is
derived from the live `operations_hub` center `(120, -10)`. At the west ramp, a
single west-approach `AREA 02 / PROCESS YARD` gateway marker identifies arrival
without repeating a direction. The physical inland transition gate at
`(52, 0, -28)` remains open but has no sign: it only leads onward to later,
currently non-functional refinery districts. Pilot remains near spawn and is
connected by one short service branch.

Directional signs belong before or at the junction where a player chooses a
route. Gateway signs identify only the area immediately beyond their gate.
Do not use `MAIN REFINERY` as a synonym for the current Area 02 yard.

## Surface and flicker rule

There must be one rendered ground surface at every visible floor location.
`IndustrialGround` is the authoritative multi-material terrain mesh; its
`TerrainBuffer` collision derives from the same triangles. Roads, paths,
industrial pads and the Pilot process pad are material regions in that mesh.
Area footprints and the full Area 02 build overlay are metadata/boundary-only,
so they cannot form coplanar duplicate floors.

## Functional migration and SPEC DEVIATIONS

CI-101 remains at `(31, 1.32, 49)` and PD-101 at `(138, 1.42, 49)` as unique,
interactive Harbor logistics terminals. They intentionally have no process
ports. CI-201 at `(82, -10)` exposes one east-facing output and PD-201 at
`(158, -10)` exposes product inputs facing west. These fixed endpoints have no
modeled hold-up: Harbor CI claims create canonical pending crude consumed only
through a running local CI-201 route, while Harbor PD completes sales only from
a valid route ending at PD-201. The dynamic physical Build Mode sign is removed;
the overlay and boundary lines remain authoritative.

The following remain intentionally unmigrated in v0.31.5:

- fixed Utilities and LS-201;
- player-built storage, trains and product tanks;
- LAB-101 and HT-201;
- VDU-301 and FCC-401;
- active Area 02 construction.

Save format 2 remains valid. Startup creates exactly one terminal and one local
boundary per role. Legacy process edges using Harbor IDs remap deterministically
to CI-201/PD-201; a pre-existing canonical local edge wins conflicts. Player
placements, inventory and relative layout do not move, and replacement pipe
visuals are local to Area 02 rather than stretched to Harbor.

SPEC DEVIATIONS: the implementation retains the historic catalog type names
`crude_intake` and `product_dispatch` for the local boundaries to minimize save
and model churn; new `*_terminal` catalog types represent Harbor visuals. The
save schema remains format 2 because its existing migration marker handles the
ID remap without changing serialized structure.

## Save and recovery behavior

Area 02 bounds, height and player construction are unchanged. Existing
v0.30.2 construction migration remains supported. Valid players left in the
larger v0.31.0 world but outside v0.31.1 bounds recover to Harbor without
changing process, economy or construction. Runtime recovery still handles
falls below y `-20`, world exits and deep water. Unknown positions outside all
recognized legacy bounds remain corrupt rather than guessed.

## Human approval route

Before the next functional migration continues:

1. Start fresh, complete Pilot and confirm the objective immediately names CI-101.
2. Follow the single CI sign from Pilot, inspect portless Harbor CI-101, then
   claim the free Standard delivery.
3. Follow the main road to the Area 02 fork, take the signed east branch and
   confirm the gateway marker at the Process Yard.
4. Enter Build Mode and verify the unchanged Area 02 surface, no dynamic
   physical build sign, and readable CI-201/PD-201 local process ports.
5. Claim crude before connecting a route; verify it remains pending, then pump
   it from CI-201 into a player tank.
6. Confirm PD-201 inspection cannot sell; connect an eligible product route and
   complete the sale only by interacting with Harbor PD-101.
7. Save/reload and confirm unique terminals/boundaries, progression, economy and player
   construction remain intact.
8. Recheck shoreline, natural grade, floor stability and world recovery.

Do not begin Crude Storage, process, Utilities, LAB or tank-farm migration until
this pass is human-approved.
