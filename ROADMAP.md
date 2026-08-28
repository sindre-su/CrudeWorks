# CrudeWorks Roadmap

## Current baseline

Version 0.31.2 retains the tested v0.28.2 process foundation, functional Pilot,
v0.30.3 Area 02 spatial contract and v0.30.4 build-menu/readability behavior.
It tightens the world to 214 x 264 m visible land with one continuous natural
grade from Harbor at 0 m to Upper at +10.5 m. Locally flattened pads and one
continuous main road communicate progression inland/uphill without shelves.
The elevated `operations_hub` remains the single runtime Area 02 source and
functional CI/PD compatibility pocket; the Harbor Main Gate now labels and
targets that live first construction yard as Main Refinery / Area 02. Other
Main Refinery systems remain unmigrated pending human approval of the new macro
world.

The underlying foundation has a tested pilot plant and a substantial Area 02 refinery
slice: free building, directed process networks, multiple independent trains,
shared-feed/product routing, Standard/Heavy/Sour crude, diesel treatment,
quality/LAB dispatch, VDU-301, FCC-401, electrical capacity, controls, alarms,
pump condition/filter repair, economy, validated save/load and functional
PG-101 → MCC-101 electrical gameplay with load, overload trip and recovery,
plus a functional Utilities Yard. Diesel feeds one canonical GF-101 day tank;
PG/PU generation consumes it deterministically. MCC power starts IA-101 and
CWP-101, whose Instrument Air and Cooling Water supplies interlock the CDU.
The stability pass also makes route-owned crude provenance authoritative for
save validation, gives every product tank an explicit quality-analysis state,
derives Pilot liquid visuals from canonical inventory, and separates pump RUN
commands from normal blocked/no-feed conditions and genuine safety trips.
The Process Foundation Gate adds one shared conservation invariant over the
canonical site inventories and makes the existing filter restriction readable
as derived pump capability, ΔP/restriction and achievable flow. It changes no
yields, utility balance, save schema or process-unit scope.

The core conclusion is deliberate: **process depth is no longer the primary
bottleneck.** Further process-unit expansion is lower priority until existing
systems feel physical, understandable, rewarding and scalable in real play.
The first physical feed-to-cash endpoints are now established: CI-101 receives
the canonical crude order into an explicit pending delivery, a player pump
moves it into crude storage, and PD-101 requires a compatible product tank and
running sales pump before it can invoke the existing dispatch transaction.

## Current priority

**Human-playtest v0.31.2 Wayfinding & Area Identity before any functional
migration.** Automated coverage validates continuous grade, locally flat pads,
non-overlapping reservations/roads, one Harbor-to-Upper route, shoreline/world
recovery, unchanged Area 02 placement/save compatibility and a Harbor-facing
Main Refinery / Area 02 sign derived from the live Operations Hub center.
A real 1280 x 720 WASD pass must judge Harbor/Pilot containment, uphill/downhill
orientation, intimate scale, landmark reading, natural grade and the
Harbor-to-Upper travel feel. It must also recheck Pilot signs, ports and the
10–20 minute demonstration. Headless tests protect contracts; they cannot
approve world feel.

Utilities are now mechanically meaningful and have focused automated coverage:
PG/GF/MCC/IA/CT/CWP field state, contextual interlocks, fail-safe behavior,
trip diagnosis, recovery and LS-201 overview. Human QA must still verify yard
discoverability, the full blackout-recovery sequence and local readability at
walking distance in a live 1280 × 720 playthrough.

The acceptance route should explicitly autosave through CI-101 intake,
mid-process, unanalyzed product, LAB-analyzed product, dispatch/empty product
and utility shutdown/recovery. A closed-valve or temporarily starved pump must
remain visibly commanded RUNNING and resume safely; a real MCC/power trip must
show TRIPPED, remain stopped after recovery and require deliberate restart.
Completing and reloading Pilot must leave every tank fill equal to its canonical
remaining inventory.

The first-hour flow now starts with state-based Pilot objectives, then asks the
player to receive the free first Standard delivery at CI-101, build its
physical intake, and establish the first atmospheric train. Advanced equipment
explains the refinery condition that unlocks it instead of using XP. Routing
headers remain hidden until the first atmospheric product, because their later
multi-train/multi-storage purpose is not useful in the first line.

## PROCESS SCOPE FREEZE

**PROCESS FOUNDATION READY FOR GRAYBOX.** V1 process scope is frozen around
the systems already implemented and approved: CDU, VDU, FCC, HT-201 treatment,
flow/routing, heaters, tanks, LAB, physical dispatch, utilities, controls,
alarms/interlocks and maintenance. During Graybox World work, improve their
physicality, readability, progression and integration; do not casually add a
new process-unit family.

Explicitly deferred until the world and existing loop demonstrate a need are
heat exchangers, blending, desalter, expanded naphtha processing, steam,
hydrogen, hydrocracker, coker, detailed hydraulics, detailed thermal simulation,
vehicle transport, major Control Room redesign and final art. Reconsidering one
requires a post-graybox player-value decision, not process completeness alone.

### First-hour economy baseline

| Step | Actual value | Meaning |
| --- | ---: | --- |
| Pilot sale | 3,000 kr minimum | Funds a complete physical starter line |
| Physical starter line | 3,000 kr | 4 tanks, 3 pumps, valve, heater, column |
| First Standard delivery | 0 kr | One protected commissioning batch via CI-101 |
| Later Standard delivery | 300 kr | 1,000 L |
| Standard gross output | ~5,000 kr | 300 L Naphtha, 350 L Diesel, 350 L Heavy Residue at target |
| HT-201 / PU-101 / VDU-301 / FCC-401 | 800 / 700 / 1,200 / 2,200 kr | Reachable after a successful first physical delivery; exact feel still needs human QA |

v0.31.2 retains the existing equipment prices and fixed Utilities Yard at
no purchase cost. IA-101 and CWP-101 add 35 kW, so one first atmospheric train
uses 70 kW before commissioning, 80 kW with LAB/LS, and 100 kW with Sour
treatment. PU-101 still doubles generation to 200 kW for concurrent trains and
secondary processing. GF-101 starts with 40 L and accepts 25 L transfers from
real saleable diesel; no money or duplicate inventory is created. The fixed
yard preserves the starter line budget, while the initial free delivery and full refund
of placed equipment already avoid an obvious early financial soft-lock. The
next playtest should verify that the three required pumps are legible at
1280×720 and that this provisional pace feels satisfying.

## Graybox World roadmap

The following phase is the highest-priority path to a more physical, scalable
refinery-builder. Detailed spatial constraints live in `WORLD_DESIGN.md`.

### 1. Graybox Master Layout & Scale

Establish the total site footprint, human-scale convention, major zones,
approximate travel distances, sightlines and deliberately empty expansion pads.
The compact prototype layout is not the target world.

**Status: tightened in v0.31.1 and clarified in v0.31.2; awaiting human approval.** Human testing
found v0.31.0's 230 x 395 m footprint and 60-second walk too broad. The current
214 x 264 m land and approximately 41-second canonical walk retain Harbor-to-
Upper progression with substantially denser area clusters.

### 2. Roads, Paths & Boundaries

Establish a main site road, service roads, short field walking paths,
maintenance/parking approaches, entrances, fences/gates, safe edges and
reliable out-of-bounds recovery. Reserve routes that can support future simple
site transport without implementing transport now.

**Status: natural-grade hierarchy complete in v0.31.1; v0.31.2 wayfinding now
targets Area 02 before the uphill road; awaiting human approval.** One 8 m primary road changes from flat Harbor to a continuous 6.6%
inland grade. Road/path/pad materials share the authoritative terrain mesh.
Short service branches, an open Harbor gate, one quay edge and deep-water
recovery exist. Detailed parking and dressing remain later refinement.

### 3. Functional Area Migration

Move the working Pilot, CI-101, crude storage, Area 02, Utilities Yard, Product
Tank Farm, LAB-101 and PD-101 into their intended zones. Preserve IDs,
interactions, ports, process topology and saves where practical. Do not place
visual duplicates of functional equipment.

**Status: paused for v0.31.2 macro-world approval.** Pilot remains complete and
visually stable; Area 02 remains on its v0.30.3 platform. Functional CI-101 and
PD-101 remain once at the Operations Hub compatibility anchors, while exact
final Harbor CI/PD reservations now exist as non-gameplay Graybox areas. Crude
storage, CDU/HT, Utilities, product storage, LAB, dedicated logistics, VDU and
FCC migration remains pending and must proceed in smaller validated slices only
after the natural-grade layout passes human playtesting.

### 4. Control Room & Expansion Graybox

Create the physical shell/location for the future Control Room, retain LS-201 as
the current local-control seed, and reserve accessible pads for VDU, FCC,
future Naphtha work and utility/Steam expansion. Do not implement a full Control
Room or new process systems in this step.

**Spatial reservation tightened in v0.31.1 and unchanged in v0.31.2.** Control Room, LAB and Maintenance
shells occupy the compact Main district. VDU/FCC and approved-later expansion
occupy the Upper district. Functional migration and gameplay remain pending.

### 5. Full Graybox Gameplay Pass

Start a fresh game and play the current loop at real site scale: Pilot ->
CI-101 -> crude storage -> Area 02 -> utilities -> LAB -> PD-101. Test field
access, discovery, road/path readability, alarms, ports, build pads, tank
levels, utility recovery and the meaningful travel between major areas.

### 6. Graybox Lock

Correct scale, navigation, access and world-safety issues, then freeze broad
geography before systematic final asset replacement. Reassess progression,
automation and art only after this lock.

## Later progression after Graybox

- Make existing equipment feel alive through visual/audio/readability passes.
- Strengthen the first 20 minutes, the 45–90 minute arc and reinvestment choices.
- Add richer operations, maintenance and automation only where manual gameplay
  already creates a clear task to improve.
- Grow toward a large integrated refinery through reliability, throughput,
  utilities, tank farms, player layouts and earned control-room capability—not
  raw process-unit count.

## Play-scale guardrails

- **Micro session (~20 min):** one concept can be demonstrated quickly through
  normal physical systems, eventually supported by scenario/preset loading.
- **Standard session (45–90 min):** pilot → build → operate → diagnose →
  reinvest forms a coherent session arc.
- **Sandbox (hours):** the same pumps, tanks, routing and maintenance systems
  gain depth as the refinery grows.

## Decision rule

After every meaningful milestone, **reassess**. Do not blindly implement the
next listed idea. Ask: *what currently prevents CrudeWorks from becoming a more
fun, physical refinery-builder game?* Choose the smallest change that removes
that bottleneck and preserves both short-session usefulness and long-form value.

## Architecture guardrails

- `ProcessNetwork` remains the sole topology authority.
- `BuiltRefineryModel` remains the Area 02 material/operation authority.
- Keep material transfers capacity-bounded, product identity-preserving and
  governed by the shared mass-balance invariant.
- Reuse manual interaction before adding remote/automatic control.
- Do not introduce new process physics, utility families or process units
  without an explicit player-facing decision after Graybox.

## Deferred work

- Human playtesting at 1280 × 720, including expanded Area 02 layout.
- Economy/load balancing for multi-train, PU-101, VDU/FCC, fuel consumption and maintenance.
- Larger storage/manifolds, advanced automation, detailed pressure/energy systems,
  logistics and additional process families only after a demonstrated gameplay
  need.
