# CrudeWorks Graybox World Design

## Purpose and current boundary

This is the authoritative spatial brief for the CrudeWorks V1 Graybox World. It
translates `CRUDEWORKS_VISION.md` into a compact, traversable refinery geography
without prescribing final art, final equipment count or vehicle gameplay.

**Implementation status: v0.31.0 Harbor & Terraced World Rescale.** The active
world now reads **Harbor -> Lower Plant -> Main Plant -> Upper Plant**. Broad
geography, elevations, area footprints, Harbor anchors, one primary road spine,
service branches, recovery and non-functional landmark shells derive from
`scripts/world_layout.gd` and are rendered by `scripts/world_builder.gd`.

The milestone changes macro world design only. Pilot, Area 02 building,
functional CI-101/PD-101, Utilities, storage, LAB-101, LS-201, CDU/HT, VDU and
FCC gameplay remain functionally where they were before v0.31.0 unless noted in
the compatibility section below. The Process Scope Freeze remains in force.

## Scale and coordinate convention

Use **1 Godot world unit approximately equal to 1 metre**. World x is
east/west; world z is north/south. North/inland is negative z. South/outward and
the sea are positive z.

The previous v0.30.4 world spread planned areas uniformly across a 600 x 400 m
flat rectangle. v0.31.0 uses:

- canonical player bounds x `-60..180`, z `-325..80`: **240 x 405 m**;
- meaningful terrace footprint x `-55..175`, z `-320..75`: **230 x 395 m**;
- terrain/safety buffer x `-90..210`, z `-355..120`;
- canonical spawn `(-10, 0.1, 8)` in the Harbor Pilot footprint;
- sea/outward at the southern edge; refinery/inland toward negative z.

The long dimension still makes a future bicycle useful from Harbor to Upper
Plant, while neighboring equipment and local areas remain comfortable on foot.
The larger old v0.30.4 bounds survive only as save-migration data.

## Canonical terraces

Each operating terrace is broad and flat. Retaining masses create the visual
level change; 8 m road ramps connect levels at no more than 10% grade.
Individual process units never sit on sloping terrain.

| Terrace ID | Center x/z | Footprint | Elevation | Purpose |
| --- | ---: | ---: | ---: | --- |
| `harbor` | `60 / 17.5` | 230 x 115 m | 0 m | Spawn, Pilot, logistics and active compatibility. |
| `lower_plant` | `60 / -90` | 230 x 80 m | +5 m | Crude storage, first process block and early Utilities. |
| `main_plant` | `60 / -185` | 230 x 90 m | +10 m | Product storage, Control/LAB core and Maintenance. |
| `upper_plant` | `60 / -285` | 230 x 70 m | +16 m | VDU, FCC and approved late expansion. |

```text
NORTH / INLAND / UPHILL

[ VDU ] [ FCC ] -- MAIN ROAD -- [ LATE EXPANSION ]       +16 m
                         |
[ PRODUCT TANKS ] [ CONTROL + LAB ] -- [ MAINTENANCE ]    +10 m
                         |
[ CRUDE STORAGE ] [ CDU / HT ] -- [ UTILITIES ]            +5 m
                         |
[ PILOT ] [ HARBOR / QUAY ] [ CI / PD RESERVATIONS ]        0 m

SOUTH / SEA / OUTWARD
```

## Canonical area plan

Area definitions contain center, footprint, elevation, purpose, terrace,
road/access relationship and buildability where relevant. They are not
duplicated in `WorldBuilder`.

| Area ID | Center x/z | Footprint | Elevation | Spatial role |
| --- | ---: | ---: | ---: | --- |
| `pilot_plant` | `-10 / 5` | 55 x 42 m | 0 m | Contained functional tutorial at Harbor. |
| `crude_intake` | `42 / 50` | 40 x 30 m | 0 m | Exact final Harbor reservation for CI-101. |
| `product_dispatch` | `135 / 50` | 50 x 30 m | 0 m | Exact final Harbor reservation for PD-101. |
| `operations_hub` | `120 / -10` | 80 x 60 m | +0.75 m | Temporary active Area 02/CI/PD compatibility pocket. |
| `crude_storage` | `-25 / -95` | 55 x 50 m | +5 m | Future crude tank farm. |
| `cdu` | `32 / -95` | 52 x 60 m | +5 m | First atmospheric process block. |
| `ht` | `98 / -95` | 34 x 50 m | +5 m | Treatment support within Lower Plant. |
| `utilities` | `148 / -95` | 48 x 50 m | +5 m | Reserved early Utilities Yard. |
| `product_storage` | `-10 / -188` | 80 x 65 m | +10 m | Future product tank farm and routing. |
| `control_room` | `48 / -170` | 34 x 24 m | +10 m | Central future supervision shell. |
| `lab` | `48 / -207` | 28 x 20 m | +10 m | Analytical shell beside product operations. |
| `maintenance` | `140 / -188` | 60 x 55 m | +10 m | Central Workshop/service reservation. |
| `vdu` | `-20 / -285` | 70 x 55 m | +16 m | Future VDU process block. |
| `fcc` | `45 / -285` | 36 x 55 m | +16 m | Future FCC process block. |
| `future_expansion` | `135 / -285` | 75 x 55 m | +16 m | Naphtha, larger Utilities and approved-later expansion. |

Areas on one terrace do not overlap. Their smaller footprints replace the
former pattern of giving every future process an enormous isolated pad. Open
land now communicates a specific route, service edge or expansion reservation.

## Harbor

Harbor is the stable orientation landmark:

- sea and the quay are outward/south;
- the refinery road runs inland/north and visibly climbs;
- a flat apron contains the functional Pilot and small logistics context;
- a continuous quay edge, simple barriers and deep-water recovery prevent a
  permanent water trap; swimming is not implemented;
- two low warehouse/logistics masses identify the final CI/PD reservations
  without pretending to be functional equipment;
- the existing Pilot remains close to spawn and visually much smaller than the
  uphill refinery silhouettes.

The functional Pilot process is unchanged. Its equipment, stable IDs, tank
levels, process feedback and visual-stability fixes remain authoritative in
`main.gd`. The current fixed Utility objects near the Pilot are deliberately
not migrated during this macro-layout milestone.

## Navigation and road hierarchy

There is one primary 8 m road spine at x `72`. From south to north it consists
of four flat terrace segments and three edge-matched ramps:

1. Harbor flat, z `75..-25`, elevation 0 m;
2. Harbor -> Lower ramp, 50 m run / 5 m rise;
3. Lower flat, z `-75..-115`, elevation +5 m;
4. Lower -> Main ramp, 50 m run / 5 m rise;
5. Main flat, z `-165..-215`, elevation +10 m;
6. Main -> Upper ramp, 60 m run / 6 m rise;
7. Upper flat, z `-275..-320`, elevation +16 m.

Short 5–6 m service branches terminate at individual areas. The Control Room
and LAB share one short pedestrian link. Finding the main road is sufficient to
recover orientation: downhill means Harbor; uphill means deeper progression.
The road reserves future bicycle/small-utility-vehicle use but adds no vehicle.

## Control/LAB and Maintenance core

The Control Room shell sits near the main road on the Main Plant terrace, with
LAB directly north and a pedestrian connection between them. Product storage
is west; Maintenance/Workshop is east. This gives the future central core quick
access downhill to first process, sideways to product/repair work and uphill to
late processing. Road-side stopping space remains available. No full Control
Room, LAB migration or Maintenance gameplay is implemented here.

## Functional compatibility and CI/PD decision

### SPEC DEVIATIONS

The long-term layout places CI-101 and PD-101 at the Harbor reservations above.
Moving them there now would separate them from the active Area 02 build surface
before crude/product storage and routing are migrated. v0.31.0 therefore keeps
the single functional CI-101 and PD-101 instances on the unchanged
`operations_hub` edge anchors. Stable IDs, port direction, physical transfer,
dispatch and saves remain unchanged.

This is one explicit temporary compatibility placement, not a second canonical
destination. `crude_intake` and `product_dispatch` are the final Harbor area
reservations; `area02_anchor()` remains the current runtime placement contract
until a dedicated functional logistics migration moves the whole material path.
Harbor reserve masses are marked non-gameplay and have no unit IDs, ports,
inventory or persistence.

The following functional systems are intentionally not migrated in v0.31.0:

- fixed Utilities and LS-201;
- player-built storage, atmospheric trains and product tanks;
- LAB-101 and HT-201;
- VDU-301 and FCC-401;
- active Area 02 construction;
- functional CI-101 and PD-101.

## Save and recovery behavior

Area 02 construction bounds, height and fixed endpoint anchors are unchanged,
so v0.30.3/v0.30.4 player construction needs no further translation. Existing
legacy v0.30.2 Area 02 migration remains supported.

Valid player positions inside the old 600 x 400 m world but outside the compact
v0.31.0 bounds migrate safely to the Harbor spawn without discarding process,
economy or construction state. Unknown corrupt positions remain rejected.
Normal runtime recovery also handles:

- falling below y `-20`;
- leaving canonical x/z bounds;
- entering deep water at z `76` or farther south.

The player has no swimming mechanic and cannot remain permanently trapped below
the quay or outside the site.

## Graybox implementation rules

Use primitive meshes, flat development materials, block shells, simple water,
roads, retaining masses, barriers, collision and restrained labels. Landmark
silhouettes have no unit IDs, process ports, construction state or persistence.
Do not add final ships, vegetation, decorative pipe clutter, detailed buildings,
production textures, final lighting or final refinery assets during Graybox.

When a functional migration is approved later, preserve canonical equipment
IDs/semantics, process ports, interactions, topology and saves; never duplicate
functional equipment to populate a destination visually.

## Human Graybox approval route

Before functional migration continues, play at 1280 x 720:

1. Spawn at Harbor and verify Pilot containment, obvious sea direction and an
   understandable inland/uphill route.
2. Walk Harbor -> Lower -> Main -> Upper on the main road. Judge distance,
   ramp feel, landmark reading and empty-space purpose.
3. Return without HUD instructions; downhill should naturally recover Harbor.
4. Walk each placeholder area and judge future build/service room.
5. Confirm a bicycle would help Harbor-to-Upper later, but is unnecessary
   between neighboring equipment.
6. Recheck the unchanged Pilot and active Area 02 loop, ports and Build Mode.

Do not begin functional logistics/process migration until this macro world is
human-approved.
