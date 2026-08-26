# CrudeWorks Roadmap

## Current baseline

Version 0.28.2 has a tested pilot plant and a substantial Area 02 refinery
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

**Graybox World: lay out the physical refinery experience around the proven
systems.** Establish walking routes, equipment neighborhoods, visual hierarchy,
expansion space and the Pilot → Area 02 journey before adding more simulation
depth. The first graybox acceptance pass must still validate port aiming,
pipe/valve readability, alarms, tank levels, LAB-101, LS-201, utilities,
VDU/FCC placement and pump-condition pacing at 1280 × 720. Headless tests
protect logic; they cannot replace human play.

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
is visible in the build menu but explains the refinery condition that unlocks
it instead of using XP.

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

v0.28 keeps the existing equipment prices and adds the fixed Utilities Yard at
no purchase cost. IA-101 and CWP-101 add 35 kW, so one first atmospheric train
uses 70 kW before commissioning, 80 kW with LAB/LS, and 100 kW with Sour
treatment. PU-101 still doubles generation to 200 kW for concurrent trains and
secondary processing. GF-101 starts with 40 L and accepts 25 L transfers from
real saleable diesel; no money or duplicate inventory is created. The fixed
yard preserves the starter line budget, while the initial free delivery and full refund
of placed equipment already avoid an obvious early financial soft-lock. The
next playtest should verify that the three required pumps are legible at
1280×720 and that this provisional pace feels satisfying.

## Development phases

### Phase A — Foundation

Mostly complete: pilot loop, free building, directed topology, atmospheric
distillation, material conservation, economy, progression gate and save/load.

### Phase B — Refinery depth

Largely established: multiple trains, feed/product routing, Sour treatment,
quality/LAB, storage choices, VDU/FCC secondary processing and electrical
generation/distribution. Add another major unit only when it unlocks a clear new player
decision rather than extending a machine checklist.

### Phase C — Make the refinery feel alive

High priority now. Choose small, tested improvements such as:

- physical process animation, readable tank level and local status cues;
- clearer pipe, port, valve, pump and alarm feedback;
- sound/status feedback that makes operation legible and satisfying;
- hands-on building and interaction improvements;
- condition/maintenance pacing and visible recovery.

### Phase D — Progression and game loop

High priority. Strengthen the first 20 minutes, the first 45–90 minute session,
and the reasons to keep expanding:

- compelling pilot-to-Area-02 transition;
- equipment/economy unlock pacing and reinvestment choices;
- storage, power, maintenance and layout as expansion decisions;
- clearer medium-term goals that are not simply "buy the next machine";
- scenario/save-preset foundations only when they reuse normal sandbox systems.

### Phase E — Quality and operations

Later depth: broader specifications, quality-dependent value, blending, richer
operator diagnosis and carefully expanded maintenance. Each addition must
produce a visible process decision or recovery path.

### Phase F — Automation and scale

Later progression: additional instruments, earned remote control, controlled
routing, scalable monitoring and simple automation. Automation must reduce a
manual task the player already understands; it must not turn CrudeWorks into an
idle game.

### Phase G — Large integrated refinery

Long-term focus: integration, reliability, throughput, quality, profitability,
utilities, tank farms and player-designed layouts—not the raw number of units.

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
  mass-conserving.
- Reuse manual interaction before adding remote/automatic control.
- Do not introduce process physics, utilities or new units without a clear
  player-facing decision.

## Deferred work

- Human playtesting at 1280 × 720, including expanded Area 02 layout.
- Economy/load balancing for multi-train, PU-101, VDU/FCC, fuel consumption and maintenance.
- Larger storage/manifolds, advanced automation, detailed pressure/energy systems,
  logistics and additional process families only after a demonstrated gameplay
  need.
