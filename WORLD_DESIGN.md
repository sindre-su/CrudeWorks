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
