# CrudeWorks Graybox World Design

## Purpose and boundary

This is the practical spatial brief for the next phase: **Graybox World**. It
turns the long-term vision in `CRUDEWORKS_VISION.md` into layout constraints
without prescribing final art, final equipment count or a transport feature.
The current compact scene is a functional test layout, not the intended final
site geography.

Graybox answers: where everything is, how large it feels, how the player moves,
whether field work is accessible and where the refinery can grow. It does not
add new process families, detailed assets, vehicle gameplay or a complete
Control Room.

**Implementation status:** Graybox World Program Work Package 1 is complete.
The macro world, canonical coordinates, area footprints, roads, boundaries,
labels and collision skeleton are implemented. Functional equipment remains in
the compact prototype neighborhood until the later area-migration packages.

## Scale and navigation convention

Use **1 Godot world unit ≈ 1 metre** as the Graybox planning convention. The
current player capsule is approximately human height and current equipment sizes
already use metre-like dimensions, so new world geometry should preserve that
relationship.

The site should feel like a believable industrial facility scaled for play, not
a 1:1 real refinery and not a miniature platform. Walking must remain useful
inside a process block. Major-area distances should sometimes make a future
bicycle or small utility vehicle feel worthwhile.

Reserve from the first layout pass:

- a main site road connecting major zones and entrances;
- service roads for utilities, maintenance and tank-farm access;
- short walking paths and safe approach space at field equipment;
- sensible stopping/parking space near the Pilot, Control Room, Workshop, LAB,
  Utilities Yard and dispatch;
- clear barriers, fences, locked gates and out-of-bounds recovery at site edges.

Transport is a future possibility, not a Graybox feature. Do not tune the map
around a vehicle controller that does not exist; simply avoid paths, bridges or
gaps that would make future site transport impossible.

## Canonical coordinates and bounds

`scripts/world_layout.gd` is the single runtime source of truth for world,
active-build, placement, save-validation, spawn and recovery bounds. World x is
east/west and world z is north/south:

- north is negative z; south and the sea are positive z;
- the playable industrial site is x `-60..540`, z `-250..150`, exactly
  **600 m east-west x 400 m north-south**;
- the primitive terrain/safety buffer is x `-90..570`, z `-280..180`;
- the sea begins beyond the southern shoreline at z `150`;
- north, east and west use visible land/forest masses outside collision walls;
- the canonical new-game/recovery spawn is `(-10, 0.1, 8)` in the southwest
  Pilot/starter region.

Road surface is nominally `+0.02 m`, pedestrian path/marker height is
`+0.12 m`, and raised industrial platforms are nominally `+0.75 m`. The Pilot
footprint intentionally remains ground-level in Work Package 1 because its
working equipment still uses the original absolute y coordinates. It will be
re-evaluated when that functional area is migrated, rather than silently moving
or burying working equipment.

## Implemented v1 macro topology

```text
NORTH / INLAND EDGE

[ UTILITIES ]   [ VDU ]   [ FCC ]   [ FUTURE EXPANSION ]

                [ CDU ]   [ HT ]

[ PILOT ]       [ CONTROL + LAB ]   [ STORAGE ]

[ CRUDE INTAKE ] ===== LOGISTICS ===== [ PRODUCT DISPATCH ]

SOUTH / SEA
```

The implemented footprints are deterministic data rather than coordinates
duplicated in scene scripts:

| Canonical ID | Center x/z | Footprint | Elevation | Work Package 1 role |
| --- | ---: | ---: | ---: | --- |
| `crude_intake` | `-10 / 75` | 80 x 70 m | +0.75 m | Empty logistics pad; functional CI-101 is not migrated yet. |
| `pilot_plant` | `-10 / -10` | 75 x 75 m | ground | Southwest starter footprint containing the current Pilot neighborhood. |
| `operations_hub` | `120 / -10` | 80 x 60 m | +0.75 m | Shared Control Room/LAB graybox platform. |
| `control_room` | `105 / -10` | 30 x 22 m | +0.75 m | Marked sub-footprint only; no full control gameplay. |
| `lab` | `145 / -10` | 24 x 20 m | +0.75 m | Marked sub-footprint only; LAB-101 is not migrated yet. |
| `storage` | `260 / 5` | 150 x 120 m | +0.75 m | Crude/product tank-farm reserve. |
| `cdu` | `120 / -105` | 100 x 90 m | +0.75 m | Main atmospheric process platform. |
| `ht` | `260 / -105` | 90 x 80 m | +0.75 m | Diesel treatment platform. |
| `utilities` | `0 / -195` | 110 x 90 m | +0.75 m | Dedicated support yard. |
| `vdu` | `120 / -200` | 100 x 90 m | +0.75 m | Secondary-process platform. |
| `fcc` | `260 / -197.5` | 110 x 95 m | +0.75 m | Secondary-process platform. |
| `future_expansion` | `430 / -180` | 160 x 130 m | +0.75 m | Explicitly empty and reserved. |
| `product_dispatch` | `440 / 75` | 90 x 70 m | +0.75 m | Empty road-facing dispatch pad; functional PD-101 is not migrated yet. |

Raised platforms have at least one primitive walk-up ramp; Operations and
Storage have paired approaches so the Control/LAB-to-tank-farm route does not
require a long perimeter detour. Yellow perimeter lines, billboard labels,
canonical IDs, dimensions and elevation make the planned areas inspectable
without implying final signage or art.

## Implemented road skeleton

The 8 m main logistics road runs east-west at z `120` between Crude Intake and
Product Dispatch. Two 5 m north-south service roads at x `62.5` and x `342.5`
connect the southern logistics edge to the process areas. A 5 m cross road at
z `-57.5` and a short orthogonal jog between z `-152.5`/`-147.5` connect the
lower, middle and staggered northern rows without passing under a platform. Short
primitive access links connect the logistics pads. A 3 m, `+0.12 m` pedestrian
link connects the Operations and Storage ramps. These are broad circulation
reserves; final parking, additional footpaths, gates and road dressing remain
later Graybox work.

### Work Package 1 traversal baseline

The following times were measured with a player-sized collision body at the
normal `6 m/s` walk speed, following the implemented ramps, road lanes and
platform approaches from the Control Room center. They are a deterministic
graybox scale baseline, not a promise of final travel pacing:

| Destination | Measured walk time |
| --- | ---: |
| CDU | 32.4 s |
| HT | 73.7 s |
| VDU | 48.2 s |
| FCC | 89.1 s |
| Utilities | 48.2 s |
| Storage | 28.2 s |
| Crude Intake | 48.1 s |
| Product Dispatch | 69.6 s |

The longer FCC/HT/dispatch routes are intentionally meaningful at this scale,
but must be reassessed during functional migration and human playtesting. Work
Package 1 does not add a vehicle or compensate with teleportation.

## Save and migration strategy

Construction and player saves use absolute coordinates. Work Package 1 enlarges
the world around all previously valid positions instead of translating saved
objects. The active prototype build/placement bounds therefore remain x
`-20..20`, z `10.5..38.5` until functional-area migration deliberately expands
or replaces them. `BuildController` and `SaveSystem` both delegate footprint
checks to `WorldLayout`; neither owns a second bounds constant.

Player save validation now uses the canonical 600 x 400 m site and y `-5..40`.
Collision walls stop normal travel at north/east/west/shore edges, and a player
who falls below y `-20` or is externally moved outside canonical x/z bounds is
returned to the southwest spawn. Existing valid saves keep their absolute
positions with no silent relocation. Invalid/corrupt coordinates still use the
existing validated save-recovery behavior.

In debug builds, the HUD reports live player coordinates, site bounds and the
current canonical area ID. World-space labels expose area ID, dimensions and
elevation. These aids are graybox diagnostics, not final player navigation UI.

## Major-area plan

The broad geography should make the material story readable rather than forcing
a perfectly straight process line:

| Area | Current role | Graybox requirement |
| --- | --- | --- |
| Pilot / Training Area | Existing manual first loop | Near the site approach; compact, legible and visibly smaller than the refinery it unlocks. |
| CI-101 and Crude Intake | Physical delivery boundary | Road/service access and a clear handoff into crude storage. |
| Crude Storage | Feed hold-up and route source | Tank-farm room, safe walk-up access and corridor space toward Area 02. |
| Area 02 / Main Process | Player-built CDU trains and HT-201 | Generous build pads, pipe corridors, service access and room for parallel trains/redesign. |
| Utilities Yard | GF-101, PG/PU, MCC, IA, CT and CWP | Dedicated support zone, visibly separate from process trains but with direct service-road access. |
| Product Tank Farm | Product storage/routing | Meaningful space, maintenance access and a clear physical route to LAB and PD-101. |
| LAB-101 | Sampling and analysis | A recognizable reachable facility near product operations, never a duplicate sale terminal. |
| PD-101 / Dispatch | Canonical product-to-money boundary | Road-facing export edge with product-pump access; normal sales happen here. |
| LS-201 / Future Control Room | Local operations seed and future central supervision | LS-201 remains usable in the field; reserve a separate Control Room shell with a credible view/access to the plant. |
| Maintenance / Workshop | Repair, inspection and future service identity | Road/service access and proximity to active plant without blocking process routes. |
| VDU/FCC pads | Implemented secondary processing | Reserve typed feed/output storage space, utility access and future expansion around their current simplified gameplay. |
| Locked expansion land | Future Naphtha, utilities/steam and other approved-later choices | Fence/gate it clearly; leave it empty enough to remain a meaningful expansion resource. |

The intended high-level visual reading is:

`Crude In -> Storage -> Process -> Product Storage -> Dispatch / Money Out`

Utilities should form a logical support area rather than appearing randomly
inside process equipment. The Control Room should have clear access to the main
plant without occupying an active process pad.

## Field accessibility

Every functional or planned field interaction needs a human-scale approach:

- pumps, manual valves, filters and local reset/service points;
- sample points, tank interfaces and product-dispatch equipment;
- PG/MCC/GF/IA/CT/CWP utility equipment;
- visible process ports used for building and piping;
- enough clearance to inspect, connect, repair and walk away safely.

Do not create visually dense but unserviceable process blocks. Keep functional
equipment distinct from decorative placeholders, especially while migrating
the current scene.

## Graybox implementation rules

Use primitive meshes, block buildings, simple materials, labels, basic roads,
simple fences/barriers, collision and landmark silhouettes. Do not spend this
phase on detailed props, decorative pipe clutter, final textures, final
lighting, vegetation polish or replacing every placeholder model.

When relocating an implemented system, preserve its canonical ID/semantics when
saves or model registration require it; preserve ports, interactions and
process-network behavior; do not duplicate functional machines just to make an
area look populated. Run the affected integration and save tests after each
meaningful migration slice.

## Graybox completion checks

Before broad world geography is locked, play a fresh game through the existing
Pilot -> CI-101 -> Area 02 -> LAB -> PD-101 loop and verify:

- orientation, travel, access and service approaches are understandable;
- the Utilities Yard, LAB and PD-101 are discoverable at real scale;
- working equipment, ports and pipes remain accessible and connected;
- roads and corridors leave room for parallel trains, VDU/FCC and future pads;
- edges are safe and restricted/locked areas communicate their purpose;
- the site feels intentionally industrial, not compressed to eliminate walking.

After correcting scale and navigation issues, freeze the broad geography before
systematic final asset replacement. See `ROADMAP.md` for milestone order and
`AGENTS.md` for Codex migration/scope rules.
