# CrudeWorks Graybox World Design

## Purpose and current boundary

This is the authoritative spatial brief for the CrudeWorks V1 Graybox World.
It translates `CRUDEWORKS_VISION.md` into a compact, traversable refinery
geography without prescribing final art, final equipment count or vehicles.

**Implementation status: v0.31.2 Wayfinding & Area Identity Fix.** The
world reads Harbor -> Lower Plant -> Main Plant -> Upper Plant, but those names
now describe progression districts rather than four giant physical shelves.
One continuous terrain mesh rises inland and contains locally level industrial
pads, roads, paths and the Pilot process surface.

This milestone changes world design only. Pilot, Area 02 building, functional
CI-101/PD-101 and every process, utility, LAB, storage, economy and progression
system remain functionally where they were. The Process Scope Freeze remains in
force until human playtesting approves the world.

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
| `crude_intake` | `31 / 49` | 26 x 18 m | 0 m | Final non-functional CI reservation. |
| `product_dispatch` | `138 / 49` | 34 x 18 m | 0 m | Final non-functional PD reservation. |
| `operations_hub` | `120 / -10` | 80 x 60 m | +0.75 m | Unchanged functional Area 02 compatibility pocket. |
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

The Main Refinery gate is at `(52, 0, -28)`. Its complete board/text assembly is
rotated 180 degrees so `MAIN REFINERY / AREA 02 →` is readable while approaching
from Harbor. Its target is the live `operations_hub` center `(120, -10)`, not a
separate uphill waypoint. The uphill road communicates deeper, later refinery
progression and has no competing immediate-destination sign. Pilot remains near
spawn, visually calmer than the inland silhouettes, and connected by one short
service branch.

## Surface and flicker rule

There must be one rendered ground surface at every visible floor location.
`IndustrialGround` is the authoritative multi-material terrain mesh; its
`TerrainBuffer` collision derives from the same triangles. Roads, paths,
industrial pads and the Pilot process pad are material regions in that mesh.
Area footprints and the full Area 02 build overlay are metadata/boundary-only,
so they cannot form coplanar duplicate floors.

## Functional compatibility and SPEC DEVIATIONS

The long-term layout places CI-101 and PD-101 at the Harbor reservations above.
Moving them now would separate them from the active Area 02 build surface before
storage and routing are migrated. Functional CI-101 and PD-101 therefore remain
once at the unchanged Operations Hub support anchors. Harbor reserve masses are
non-gameplay geometry with no stable unit IDs, ports, inventory or persistence.

The following are intentionally not migrated in v0.31.2:

- fixed Utilities and LS-201;
- player-built storage, trains and product tanks;
- LAB-101 and HT-201;
- VDU-301 and FCC-401;
- active Area 02 construction;
- functional CI-101 and PD-101.

## Save and recovery behavior

Area 02 bounds, height and fixed endpoint anchors are unchanged. Existing
v0.30.2 construction migration remains supported. Valid players left in the
larger v0.31.0 world but outside v0.31.1 bounds recover to Harbor without
changing process, economy or construction. Runtime recovery still handles
falls below y `-20`, world exits and deep water. Unknown positions outside all
recognized legacy bounds remain corrupt rather than guessed.

## Human approval route

Before functional migration continues:

1. Inspect spawn, Pilot containment, shoreline and the single Harbor edge.
2. Approach the gate from Harbor and confirm `MAIN REFINERY / AREA 02 →` is
   readable, then use the short service branch into the active construction yard.
3. Walk the main road at normal speed to Upper Plant; target 35–45 seconds.
4. Confirm the route feels continuously uphill, not like four floors.
5. Walk across local pads and their blended edges; check collision and scale.
6. Return without HUD navigation; downhill should naturally recover Harbor.
7. Strafe and rotate around the Pilot/main-road junction and confirm no floor
   flicker.
8. Recheck unchanged Pilot, Area 02, CI/PD, ports and Build Mode.

Do not begin functional refinery migration until this pass is human-approved.
