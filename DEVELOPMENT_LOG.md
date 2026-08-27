# CrudeWorks Development Log

## v0.31.1 — World Intimacy & Natural Grade Pass

- Human v0.31.0 playtesting found a 60-second Harbor-to-Upper walk, shelf-like
  terraces, localized floor flicker, false walkable Harbor ground, duplicate
  barriers and a gate sign readable from the wrong side.
- Reduced visible land from 230 x 395 m to 214 x 264 m. The canonical
  Harbor-to-Upper road route is about 248 m / 41 seconds at normal walk speed;
  non-functional area pads were reduced and clustered while the functional
  80 x 60 m Area 02 contract stayed unchanged.
- Replaced four full-width terrace masses and three separate ramps with one
  continuous terrain mesh: flat Harbor transitions into a 158 m, approximately
  6.6% inland grade reaching +10.5 m. Lower/Main/Upper pads are locally shaped
  flat at +3.5/+7.0/+10.5 m with short blended embankments.
- Eliminated the floor-flicker root cause. Full-area footprint overlays, road
  overlays, path overlays and the Pilot pad no longer stack over ground; their
  materials are separate surfaces in the same authoritative terrain mesh, and
  collision derives from those same triangles. The Area 02 build zone now uses
  boundary lines without a duplicate full-pad floor.
- Aligned visible land, water and recovery: land ends at z 64, one physical
  quay safety edge blocks access, sea begins beyond it and z 64.5+ remains a
  safe fallback recovery. Removed the separate south perimeter wall and the
  segmented parallel quay barrier layer.
- Rotated the complete Main Refinery gate sign assembly to face the Harbor
  approach. The board still derives its arrow/target from canonical wayfinding.
- Added deterministic checks for natural elevation ordering, flat local pads,
  non-overlapping rendered road regions, one Harbor barrier, shoreline/OOB
  consistency, sign facing, full route traversal and v0.31.0 player recovery.
  Player-height and overview renders covered the old flicker junction, gate,
  grade and shoreline.
- No process, utility, economy, progression, equipment ID, Area 02 construction
  or functional CI/PD migration occurred. Process Scope Freeze remains active.

## v0.31.0 — Harbor & Terraced World Rescale

- Replaced the flat, scattered 600 x 400 m area plan with a compact 230 x 395 m
  meaningful refinery footprint inside 240 x 405 m player bounds. The world now
  progresses Harbor -> Lower -> Main -> Upper at 0, +5, +10 and +16 m.
- Added canonical terrace purpose/footprint/elevation data and rationalized all
  planned area sizes. Lower holds crude storage/CDU/HT/Utilities; Main holds
  product storage plus central Control/LAB/Maintenance shells; Upper holds
  VDU/FCC and approved-later expansion.
- Built broad flat primitive terrace masses with retaining faces. Canonical road
  notches prevent hidden vertical collisions where three 8 m, <=10% main-road
  ramps meet the four flat road sections. Short service branches and one
  Control-to-LAB pedestrian link remain local and foot-friendly.
- Added a recognizable Harbor apron, continuous quay edge, simple barriers,
  non-functional CI/PD logistics reservation masses and one warehouse mass.
  Sea means outward; the single dark road and rising silhouettes mean
  inland/deeper progression.
- Preserved the entire functional Pilot and active Area 02 contract. Functional
  CI-101/PD-101 remain once on the unchanged Operations Hub support anchors;
  their final Harbor areas are exact non-gameplay reservations with no unit ID,
  ports, inventory or persistence. Utilities, storage, LAB/LS, CDU/HT, VDU/FCC
  and product tanks were intentionally not migrated.
- Added safe migration for valid v0.30.4 player positions outside the compact
  world: only player location/facing recover to Harbor, while construction,
  process and economy remain unchanged. Runtime recovery now explicitly catches
  deep water at z 76+, world exits and falls below y -20. Save format remains 2.
- Expanded deterministic coverage for terrace elevations, non-overlapping
  areas, exact Harbor anchors, road sequence/grade, canonical geometry
  consumption, all active level ramps, deep-water recovery and old-world player
  migration. Render inspection covered spawn, Harbor/inland reading and the
  complete oblique terrace hierarchy at 1280 x 720.
- Process Scope Freeze remains unchanged. The macro world requires human WASD
  approval before any functional logistics or refinery migration proceeds.

## v0.30.4 — Graybox Readability & Build Menu Cleanup

- Removed the obsolete Pilot-side Crude Intake wayfinding specification and
  generated sign. Starter Site, Pilot process and Main Refinery gate signs
  remain canonical and the focused Pilot route remains readable.
- Replaced the Operations–Storage 3 m overlapping path rectangles with two
  flush 5 m segments that meet on an edge. The connection remains visual-only,
  preserves the existing ramp/traversal route and has no coplanar overlap or
  added collision lip.
- Reordered the full build hotbar to Tank, Pump, Manual Valve, Heater,
  Distillation Column, Diesel Treater, then routing and advanced tools. Key
  labels, selection mapping and contextual help derive from the same visible
  catalog order.
- Audited Crude Feed Header and Product Routing Header: both remain required
  for later shared-crude and multiple-destination storage routing, so neither
  was removed. The existing first-atmospheric-production availability state now
  hides both from the first-line menu; saved headers and all network behavior
  remain valid.
- Added regressions for the first five key mappings, displayed labels, deferred
  routing items, retained header previews, removed sign authority and
  non-overlapping consistent-width paths. No process mechanics, progression
  state, Area 02 spatial contract or save schema changed.

## v0.30.3 — Area 02 Spatial Coherence

- Root cause: the rendered elevated Operations Hub, runtime build rectangle,
  blue build-pad mesh, ghost/save y placement and fixed CI-101/PD-101 positions
  were separate spatial definitions. The v0.29 world therefore showed one Area
  02 while construction and logistics still used the compact prototype.
- Made `WorldLayout.operations_hub` the single active Area 02 contract. Its
  x `80..160`, z `-40..20`, `+0.75 m` platform derives a 4 m inset build zone,
  placement height, overlay and validation. The old x `-20..20`, z
  `10.5..38.5` bounds remain explicitly migration-only.
- Replaced `PrototypeBuildPad` with a Build Mode-only `Area02BuildOverlay` whose
  footprint and boundary lines derive directly from canonical validation.
  Repeated off/on toggles restore the same state; no blue legacy zone remains.
- Moved the existing functional `built_crude_intake_0` and
  `built_product_dispatch_0` to west/east platform-edge support anchors. Their
  whole functional transforms derive from the refinery-facing port direction:
  CI output points east/inward, every PD product input lies on the west/inward
  face, and outbound blank/logistics faces point away from Area 02.
- Preserved endpoint IDs, interactions, contract/dispatch behavior, topology
  and save format. Qualifying v0.30.2 construction receives one all-or-nothing
  `(120, 0.61, -34)` translation; relative layout, rotations, pipes and IDs are
  preserved while player position is unchanged. Fixed CI/PD are rebuilt once
  at their canonical anchors, preventing legacy duplicates.
- Added deterministic regressions for the platform/build/overlay contract,
  legacy-zone rejection, reversible toggles, valid/invalid placement, CI/PD
  anchors and real port orientation, stable-ID uniqueness, save migration and
  duplicate-free load. Render inspection at 1280 × 720 covered Build Mode off,
  Build Mode on and both endpoint approaches.
- Broader Main Refinery, Utilities, Storage, LAB, CDU/HT/VDU/FCC and dedicated
  logistics-pad migration remains out of scope. No process mechanic, economy
  value, progression rule, material yield or save schema changed.

## v0.30.2 — Visual Stability & Pilot World Coherence

- Removed the release-blocking macro-ground depth conflict. `TerrainBuffer`
  now provides collision only, while `IndustrialGround` is the single rendered
  600 × 400 m ground layer; their former top faces were exactly coplanar at
  `y = 0`. Controlled shadow-off, candidate-surface and placeholder-caster
  isolation distinguished the surface conflict from directional shadows.
- Rebuilt reusable sign depth as viewer → text → board → post, reduced the
  normal board/text scale and disabled graybox navigation-helper shadows.
- Moved starter wayfinding placement, facing and target IDs into canonical
  `WorldLayout` data. Pilot and Crude Intake now derive left arrows from the
  actual target center relative to the readable board face; the Main gate
  derives straight ahead.
- Identified the unexplained yellow Pilot wedge as the obsolete two-metre
  starter approach strip and removed it. The actual build pad, bounds and sign
  remain intact but are shown only while Build Mode is active.
- Added a configurable `pilot_slice` completion cap. Human testing now ends at
  `PILOT COMPLETE` instead of displaying the unmigrated CI-101 objective;
  selecting `main_refinery` restores the unchanged underlying progression.
- Preserved legacy CI-101/PD-101 IDs, ground-level coordinates, gameplay and
  saves. Their mismatch with elevated canonical destination pads remains
  explicit v0.31+ migration debt.
- Added deterministic coverage for one rendered macro ground, sign hierarchy,
  canonical directions, contextual build visualization and reversible Pilot
  completion. Render inspection covered signs, Pilot, Build Mode and completion;
  a continuous 1,800-frame route around Pilot/open ground showed no rapid
  dark/diagonal ground flashes.

## v0.30.1 — Graybox Traversal & Readability Cleanup

- Corrected the human-playtest traversal defects without changing process,
  economy, progression, equipment IDs, map coordinates or save schema.
- Moved the canonical terrain collider to exact base grade and converted the
  Pilot/build pads, roads and pedestrian surfaces into near-flush semantic
  visual overlays. The former 12–14 cm Pilot/build-pad colliders were the main
  hidden catches.
- Recalculated each simple rectangular ramp so its exposed top face meets both
  base and `+0.75 m` platform grade exactly. Added a north Crude Intake ramp for
  the intended direct starter route; no arbitrary polygon connectors remain.
- Rebuilt the Main Refinery entrance as fence–six-metre opening–fence with
  visible posts and one short overhead board.
- Added reusable `GrayboxSign` geometry with two-line limits, predictable board
  size, local non-billboard text and safe depth offset. Starter, Crude Intake,
  Pilot, build-area and gate text now use it.
- Strengthened flat semantic colors for terrain, main/service roads, paths,
  platforms, buildable and reserved areas. Added non-gameplay primitive CDU,
  VDU, FCC, HT, Utilities and Storage silhouettes for player-height orientation.
- Split development visibility: `F7` controls core coordinate/bounds HUD and
  `F8` controls area labels, which default off.
- Extended deterministic coverage for canonical elevations, semantic colors,
  sign constraints, placeholder isolation, every raised ramp and a no-jump
  spawn → Pilot → Crude Intake → gate → Operations → CDU CharacterBody route.
- Render-inspected spawn, starter signs, Pilot/Crude route, gate, Operations
  approach, CDU sightline and a raised-platform transition at 1280 × 720.
- Main Refinery gameplay migration remains out of scope. A human WASD retest is
  still required before v0.31.

## v0.30.0 — Functional Pilot Integration

- Proved the existing fixed Pilot as one complete fresh-save gameplay slice in
  the canonical v0.29 Graybox World. No process logic, material definition,
  stable equipment ID, topology rule, yield, economy value or save schema was
  replaced.
- Added a restrained physical starter treatment: one short 2 m approach strip,
  a mounted Starter Site direction board, a mounted Pilot process-chain board
  and an open pedestrian-width Main Refinery transition gate. The signs establish
  Pilot, southern Crude Intake and distant Main Refinery direction without a
  waypoint system or giant floating tutorial marker.
- Retained the fixed ground-level Pilot platform and every legacy absolute
  equipment coordinate. Starter crude remains canonical preloaded `raw_tank`
  inventory; no duplicate CI-101 or competing crude architecture was created.
- Added a deterministic full-world Pilot acceptance suite. It starts grounded
  at the southwest spawn, verifies all stable Pilot IDs inside the canonical
  footprint, diagnoses pump-against-closed-valve LOW FLOW, heats to 200 °C,
  produces approved light/diesel/heavy inventory, sells through the existing
  terminal and unlocks the established post-Pilot build state.
- The same acceptance route places and rotates a tank and pump, creates one
  real OUT-to-IN connection, validates overlap/bounds feedback, writes through
  `SaveSystem`, restores into a fresh Main instance and verifies player state,
  equipment IDs/positions/rotations, connection identity, canonical inventory,
  economy and progression. Pump motion resumes only after a deliberate restart,
  then continues processing and remains save-valid.
- Render-inspected the normal 1280 × 720 spawn, Starter Site board and Main
  transition gate. Corrected the gate label's viewing orientation before lock.
- Preserved all prior process, network, building, refinery, logistics,
  progression, Main, save and world-layout tests. Main CDU, HT, VDU, FCC,
  Utilities, Storage, LAB and PD-101 migration remains explicitly out of scope.
- Main-world travel scale remains provisional. A real human WASD session must
  evaluate Pilot pacing, sign discovery, spacing and the 10–20 minute feel
  before v0.31 moves another functional area.

## v0.29.0 — Graybox World Program WP1: World Skeleton

- Completed the repository and process-readiness audit. The tested v0.28.2
  process foundation already covers the V1 systems required for Graybox, so no
  new process family or gameplay simulation was added.
- Extracted macro geometry from `main.gd` into `world_builder.gd` and established
  `world_layout.gd` as the sole authority for the 600 x 400 m site, area/road
  coordinates, active placement bounds, southwest spawn and player/save bounds.
- Built the primitive Nordic coastal macro world: flat industrial terrain,
  southern sea, north/east/west land/forest borders, perimeter collision, all
  planned V1 pads, explicit Future Expansion, 8 m logistics road, 5 m service
  roads, access links, raised-platform ramps and graybox labels/boundaries.
- Kept the working Pilot, fixed logistics/utilities and active Area 02 build pad
  at their existing absolute coordinates. The enlarged world contains all old
  valid coordinates, so no equipment or player save is silently translated.
  `BuildController` and `SaveSystem` now delegate footprint validation to the
  same canonical layout source.
- Added a debug HUD with player coordinates, current area ID and world bounds,
  plus world-space area ID/dimension/elevation labels. These are diagnostic
  graybox aids rather than final signage or navigation UX.
- Added deterministic world-layout coverage for unique IDs, positive target
  footprints, containment, future expansion, spawn, road widths, road/platform
  clearance, canonical bounds ownership, legacy coordinates, generated world
  nodes, collision boundaries and player-sized traversal of every raised ramp.
- Render-inspected the full overhead layout and the actual 1280 x 720 fresh
  spawn. The first pass exposed cross roads hidden beneath Storage/FCC and a
  ramp touching the Utilities road centerline; both were corrected before lock.
- Measured collision-world walking routes from Control Room at 6 m/s: CDU 32.4
  s, HT 73.7 s, VDU 48.2 s, FCC 89.1 s, Utilities 48.2 s, Storage 28.2 s,
  Crude Intake 48.1 s and Product Dispatch 69.6 s. Human feel/pacing remains a
  required check during functional migration; no transport feature was added.
- Preserved all prior process, progression, physical-logistics, full-Main and
  save/load tests. Functional-area migration intentionally stops before Work
  Package 2.

## v0.28.2 — Vision & Repository Documentation Sync

- Recorded the completed Process Foundation Gate as the boundary before world
  development: **PROCESS FOUNDATION READY FOR GRAYBOX**. The v0.28.2 gameplay
  version and process simulation were not changed.
- Synchronized the long-term vision, current roadmap, architecture map, README
  and Codex guidance with the implemented Pilot/Area 02, PD-101, LAB, utilities,
  canonical-state, material-balance, operator-state and simplified ΔP systems.
- Added a dedicated Graybox World spatial brief. The next primary phase is now
  permanent broad geography, human-scale navigation, roads/service access,
  functional-area migration, expansion pads and a full existing-loop playtest;
  it is not more process-unit expansion or final art production.
- Clarified the long-term Field versus Control Room division: field work keeps
  building, inspection, maintenance, repair and physical intervention, while
  earned central control grows from LS-201 only when world scale justifies it.
- Preserved the process-scope freeze. CDU, VDU, FCC, HT-201, routing/storage,
  LAB, PD-101, utilities, controls, alarms/interlocks and maintenance remain the
  approved V1 process family; additional process families and detailed
  hydraulic/thermal simulation are deferred until post-Graybox value is proven.

## v0.28.2 — Process Foundation Gate

- Completed the final process-foundation audit before Graybox World. Material
  paths were classified as **needs small generalization**: transfers and unit
  splits were already atomic/capacity-bounded, but conservation assertions were
  bespoke. Pressure/restriction was also **needs small generalization**: pump
  condition and blocked-filter factors already governed all pump-driven routes,
  but their relationship was not exposed coherently. Heater/duty architecture
  was classified as **already sufficient as an extension point**: every routed
  heater already has canonical PV, SP, output and actual-flow context, while a
  true energy-duty balance would be a gameplay rebalance and is deferred.
- Added reusable `MaterialBalance` diagnostics for the invariant `before +
  boundary input - boundary output - defined loss = after`, with finite,
  non-negative inventory validation and a small floating-point tolerance. It is
  test/diagnostic architecture and never crashes live play or creates another
  persisted inventory.
- Defined the current canonical hold-ups explicitly: Pilot crude/light/diesel/
  heavy; every built tank; pending CI-101 delivery; and GF-101 generator fuel.
  Pipes, headers, pumps, treatment and process units intentionally have zero
  modeled hold-up. Reports, samples, processed totals, HUD text, tank meshes and
  flow visuals remain derived state rather than duplicate material truth.
- Audited all supported material mutations. No unexplained creation or
  destruction was found in normal gameplay, and existing yields were unchanged.
  Two boundary semantics were clarified: confirmed product disposal now reports
  an explicit defined loss, and contract/PD/secondary dispatch reports all
  physically removed material. In particular, a Heavy order removes and reports
  both its diesel and ordered heavy product while preserving the existing
  diesel-only `sold_volume_l` and economy behavior.
- Generalized the existing restriction calculation into derived pump hydraulic
  diagnostics: selected target × condition capability × filter restriction =
  achievable flow. A blocked filter exposes `ΔP HIGH`, 65% restriction and the
  resulting capacity in inspection/status feedback. Valve closure and unavailable
  destinations remain explicit binary route restrictions with zero flow. No
  pipe friction, head network, percentage valve, CFD or persisted pressure state
  was introduced.
- Left heater behavior unchanged after audit. The existing equipment-type loop,
  route lookup, PV/SP/output, actual-flow signal, IA fail-close and CW permissive
  provide a safe later insertion point for duty versus flow. Modeling inlet
  temperature, heat capacity and energy balance now would change established
  temperature/quality pacing and is post-graybox technical debt.
- Expanded shared conservation coverage across Pilot processing/dispatch,
  CI-101 partial transfer and save/load, tank-to-GF-101 transfer, deterministic
  generator consumption as a defined loss, tank → pump → valve → CDU, partial
  and fully blocked destinations, Product Routing Header, CDU/VDU/FCC atomic
  splits, disposal, Heavy contract output, PD-101 dispatch and mid-process Main
  save/load. Added deterministic restriction/repair diagnostics while retaining
  STOPPED, RUNNING/FLOW, RUNNING/BLOCKED-or-NO-FEED and TRIPPED semantics.
- Save format remains unchanged. Conservation totals and pump hydraulic
  diagnostics are recalculated from canonical v0.27/v0.28-compatible state;
  existing utility fuel, MCC, IA/CW, TIC fail-safe and deliberate trip recovery
  behavior is preserved.
- Established **PROCESS SCOPE FREEZE**. No new refinery process units, detailed
  hydraulics or detailed thermal simulation should be added before Graybox World
  and the existing loop receive physical, UX and progression depth.

**PROCESS FOUNDATION READY FOR GRAYBOX.**

## v0.28.1 — Stability & Operator Experience

- Fixed the playtest save failure `Materiale mangler en aktiv
  råoljekontrakt`. Physical CI-101 transfer placed contract provenance on the
  receiving source tank but the validator treated the single global active
  pointer as universal truth. Validation now requires a valid contract only on
  atmospheric routes whose source/product/report state depends on it. An empty
  global pointer is legitimate; a non-empty stale or unknown pointer and
  missing/unknown route provenance remain rejected. Physical intake also
  synchronizes the legacy global pointer for existing single-route UI paths.
- Fixed the Area 02 tank temperature/quality save failure. Repeated weighted
  diesel-quality updates could drift microscopically outside 0–100, while
  `IKKE ANALYSERT` existed only as presentation state. Quality is now clamped
  after every accumulation and tanks persist a canonical `empty`,
  `not_applicable`, `unanalyzed`, `on_spec` or `off_spec` state separately from
  numeric quality and formatted HUD text. Legacy v0.27/v0.28 representations
  are derived safely; NaN, infinity, invalid enums and broken references are
  still rejected.
- Fixed the remaining Pilot liquid visual issue at its source. Tank meshes were
  already volume-driven, but `sell_diesel()` credited the sale without
  consuming canonical Pilot diesel. A sale now zeroes the sold diesel volume,
  quality and status while preserving visible unsold light/heavy fractions.
  Restart and save/load rebuild all fills from canonical inventory only.
- Added canonical pump `trip_reason` and concise STOPPED, RUNNING/FLOW,
  RUNNING/BLOCKED-or-NO-FEED and TRIPPED feedback to field inspection and
  LS-201. Manual stop clears trip state; a successful deliberate start
  acknowledges it. Restoring the root utility or resetting MCC never restarts
  the pump or silently erases the recorded trip.
- Audited every automatic pump shutdown. Topology loss is `route_invalid`;
  source/output material conflict is `process_mismatch`; zero condition is
  `equipment_failure`; atmospheric/VDU/FCC batch depletion is protected
  `dry_run`; temperature guard is `temperature_guard`; IA/CW loss and
  MCC/power shutdown retain their distinct utility reason. Safe load restore
  remains STOPPED, successful PD dispatch intentionally completes with its
  sales pump STOPPED, and manual operator stops remain STOPPED rather than
  trips.
- Reclassified normal process waits so they no longer erase RUN: CI-101 no
  delivery/full receiving storage, PD-101 empty feed, closed manual valve,
  temporarily unavailable routing, paused treatment/product route and full
  VDU/FCC destination remain commanded RUNNING with zero flow. When the
  blockage clears, flow can resume without an arbitrary restart. Existing
  mass/capacity/material interlocks remain authoritative.
- Preserved v0.28.0 generator fuel exhaustion, MCC trip/reset, Instrument Air
  fail-closed behavior, Cooling Water permissive and deliberate post-trip
  restart. No process unit, utility type, map rebuild or new failure system was
  added.
- Added regressions for the real contract/tank save states, NaN/infinity and
  enum rejection, utility shutdown/recovery, Pilot completion/restart/save-load
  visuals, physical intake/dispatch blocked recovery, closed-valve flow
  recovery and exact trip causes for topology, temperature, IA, CW and MCC.

Human QA scenarios for release acceptance:

1. Run CI-101 → crude tank → CDU → products → LAB → PD-101 and observe clean
   autosaves during intake, processing, before/after analysis and after dispatch.
2. Close a valve while its pump is running; confirm RUNNING/BLOCKED, unchanged
   inventory and automatic safe flow recovery after reopening.
3. Cause real MCC/power loss; confirm TRIPPED, restore utilities/reset MCC and
   confirm the process remains stopped until deliberate restart.
4. Complete Pilot, save/load and start a new batch; confirm each visible level
   exactly matches remaining canonical crude/light/diesel/heavy inventory.

## v0.28.0 — Utilities Expansion

- Turned the fixed Utilities Yard into a functional dependency chain:
  Diesel → GF-101 → PG/PU generation → MCC-101 → IA-101/CWP-101 → CDU.
- Added one canonical 100 L generator day tank with 40 L starter fuel and
  bounded 25 L refills from real stored diesel. Refills reduce saleable tank
  inventory atomically; generators consume deterministic idle- and load-based
  fuel and stop visibly on exhaustion.
- Added canonical catalog fuel tunables to PG-101/PU-101. A blackout never
  requires an electric transfer pump, so stored diesel remains a valid recovery
  path without an electricity↔generator deadlock.
- Added fixed IA-101 (15 kW), CT-101 and CWP-101 (20 kW) using the existing
  `UtilityDistribution` trip/recovery lifecycle and canonical MCC load sum.
- Marked manual V-201 valves as independent of Instrument Air. TIC-201's
  automated heater/fuel actuator is metadata-driven `fail_closed`; IA loss
  removes heat demand/output, stops atmospheric flow and leaves manual valve
  position untouched.
- Made Cooling Water a CDU condensation permissive. CWP loss stops atmospheric
  flow, shows `NO COOLING WATER`, raises the existing alarm layer and requires
  deliberate utility/process restart without adding exchanger thermodynamics.
- Extended field prompts/statuses, PG fuel feedback, MCC active loads and the
  compact LS-201 block with fuel, Instrument Air and Cooling Water state.
  Root electrical loss suppresses redundant downstream utility alarms.
- Persisted only canonical fuel, utility machine and trip states; derived fuel
  rate, demand and visual strings are rebuilt. v0.27.x saves receive 40 L and
  safe inferred IA/CW state based on their previous generator state.
- Preserved early progression and prices. Fixed utilities cost 0, starter fuel
  supports commissioning, the first Standard delivery remains free, and one
  normal/Sour CDU train fits the 100 kW PG while expansion makes PU-101 useful.
- Added comprehensive fuel, IA, CW, cross-utility, failure/recovery, save-schema,
  legacy and Main-world regression coverage. Existing VDU/FCC implementation
  was left unchanged; Steam, boilers, Fuel Gas and utility piping/cabling remain
  out of scope.

## v0.27.3 — Gameplay Integrity & Dispatch Cleanup

- Kept tank liquid visuals derived from canonical stored volume and synchronised
  them immediately after a successful PD-101 transaction; no separate visual
  fill state is saved.
- Removed normal Area 02 sales from LAB-101 and tank interaction. LAB-101 now
  only analyzes diesel samples; product tanks only inspect/connect; PD-101 is
  the sole gameplay dispatch point through a tank → sales pump → typed PD route.
- Added the missing canonical diesel contract order to PD-101, including the
  active contract's target, price and bonus preview. The existing atomic sale
  transaction remains the authority for inventory, payment and commissioning.
- Restored the existing diesel batch report after a physical PD-101 dispatch.
- Added safe automatic player recovery below the level boundary, including
  position/orientation reset, velocity reset and a short cooldown. It does not
  mutate economy, inventory or progression.
- Expanded Main integration coverage for PD-only dispatch, LAB/tank no-sale,
  volume-driven tank fill, exact-once dispatch, existing free CI-101 batch flow,
  save/load and out-of-bounds recovery. No new gameplay units or utility systems
  were added.

## v0.27.2 — Free First Crude Batch Progression Fix

- CI-101 now applies the free Standard first-batch entitlement before the
  affordability check, so it can be claimed at 0 kr.
- The intake order UI clearly shows `FIRST BATCH FREE / 0 kr` while the
  entitlement is active.
- The entitlement is still consumed only by a successful order; later Standard
  batches retain the normal 300 kr price and affordability check.
- No process, economy or progression values changed.

## v0.27.1 — Power UX & Balance Pass

- Kept the v0.27 electricity architecture and power values intact after audit:
  one starter atmospheric train is 35 kW (45 kW after LAB-101/LS-201), below
  PG-101's 100 kW; a running PU-101 raises site generation to 200 kW.
- Added focused PG-101 context showing running/stopped state, current generator
  output, site load, bus state and direct start/stop action.
- Made MCC-101 the concise diagnostic point: normal inspection presents bus,
  generation, load, reserve and active loads; a trip presents cause, exact trip
  demand/generation and the recovery action.
- Reworded electrical interlocks as direct `START BLOCKED — NO POWER` or
  `MCC-101 TRIPPED` feedback. Looking at an unpowered pump, heater or treatment
  unit now explains its kW demand and whether to start PG-101 or reset MCC-101.
- Improved generator/trip/reset notifications and ensured reset feedback says
  that equipment remains stopped and must be restarted deliberately.
- Added a compact LS-201 POWER block with PG-101, PU-101, generation, load,
  reserve, bus and MCC status; no new electrical screen or utility type was
  added.
- Increased only the existing temporary bottom feedback bands so two-line power
  prompts and three-line MCC diagnostics remain separated at the 1280 × 720
  reference layout.
- Expanded regression coverage for contextual feedback, MCC diagnostics,
  no-bypass reset, no automatic equipment restart, PU-101 overview and the
  1280 × 720 UI bands. v0.26.2 and v0.27.0 save compatibility remains unchanged.

Human QA finding: automated layout and integration checks confirm the fixed
1280 × 720 geometry and copy paths, but a by-eye first-person pass remains
necessary for distance readability, aiming and subjective overload/reset pace.

## v0.27.0 — Power & Utilities Foundation

- Replaced passive starter capacity with a physical 100 kW PG-101 generator
  feeding a fixed MCC-101 site bus; new games begin with the generator stopped.
- Made pumps, heater auxiliaries, diesel treatment, LAB-101, LS-201 and existing
  VDU/FCC auxiliaries canonical electrical consumers without adding cable
  micromanagement or changing the material process network.
- Converted buildable PU-101 units into explicit stopped/running expansion
  generators. Placed-but-stopped units contribute no capacity.
- Added deterministic MCC overload and supply-loss trips. A trip stops pumps and
  treatment safely, removes heater output, raises the existing operator alarm,
  and requires sufficient generation plus an explicit MCC reset.
- Added local POWER availability/demand/source feedback, central generation,
  load, reserve, status and active-consumer feedback, plus powered LAB/LS guards.
- Added reusable `UtilityDistribution` trip/reset state so future utility buses
  can share the lifecycle without adding Steam, Cooling Water, Instrument Air
  or Fuel Gas in this release.
- Persisted generator and MCC trip state while recalculating derived load totals.
  Older v0.26.2 saves infer their former starter/PU capacity as running
  generation and remain valid without a format bump.
- Expanded automated coverage for no-power starts, summed loads, live power
  loss, deterministic overload, alarms, reset/recovery, Main-world feedback,
  save/load and legacy compatibility.

Human QA still required: PG-101/MCC-101 discoverability and readability at
1280 × 720, overload/reset pacing, and whether the added first-hour action feels
like useful physical operation rather than friction.

## v0.26.2 — Pilot Diesel Quality Save Bugfix

- Separated Pilot diesel quality (`diesel_quality_percent`) from its canonical
  spec status (`NO_DIESEL`, `UNKNOWN`, `ON_SPEC` or `OFF_SPEC`) in save data.
- Kept older format-v2 saves compatible by deriving the missing status on load.
- Clamped the running weighted-quality calculation to its canonical 0–100 %
  range and kept formatted Norwegian HUD labels out of persisted state.
- Added save regressions for pre-production, unknown, off-spec, on-spec and
  active mid-batch Pilot states.
- Kept gameplay, pacing and economy unchanged.

## v0.26.1 — First-person usability and starter-flow hardening

- Kept the v0.26 economy, process model and equipment roster unchanged.
- Audited the 1280 × 720 reference layout in code: objectives and alarms stay
  in the top band, field information stays at the sides, and interaction and
  temporary feedback retain separate bottom bands.
- Added concise, local onboarding labels to the existing CI-101 and PD-101
  terminals. CI-101 is marked only until the first intake delivery is received;
  PD-101 is marked only from first atmospheric production until the first
  physical dispatch. The markers are derived from existing saved progression,
  so no save-format change or marker state is persisted.
- Hardened pipe-mode targeting: the build ray now queries the dedicated port
  collision layer before it falls back to an equipment body. Normal field
  interaction remains body-first and is unchanged.
- Added regression coverage for the 1280 × 720 HUD bounds, CI/PD marker
  activation/deactivation, and the dedicated process-port selection layer.

Human QA still required: actual 1280 × 720 readability by eye, aiming feel,
CI/PD discoverability in a real playthrough, economy pacing, fun and
maintenance pacing. These were not claimed solved by automated tests.

## Session Review

- Inherited version 0.4 at checkpoint `0676b80`.
- The pilot loop and the complete player-built refinery loop are both present.
- Verified all five automated suites and a headless main-scene launch with Godot 4.7.1.
- Confirmed that the process network is the single topology authority and the
  built refinery model owns operating state by stable string IDs.
- The worktree began with three untracked Godot UID sidecars for files added
  overnight; no gameplay source changes were present.
- The largest current gameplay gap is the lack of durable completion and useful
  result feedback after the first successful Area 02 sale.

## Current Roadmap

1. **First flow/capacity choice — complete** — the built pump now offers a
   controllable throughput tradeoff with a measured quality consequence.
2. **Maintenance troubleshooting** — introduce one recoverable equipment fault
   that can be diagnosed from existing alarm and instrument feedback.
3. **New treatment decision** — consider one actual treatment unit and Sour
   crude only after the preceding loop is stable and hands-on tested.
4. **Hands-on usability pass** — verify port aiming, labels, valve feedback and
   modal readability at the target 1280 x 720 window before broadening scope.
5. **Product-value expansion** — add another useful product destination only
   after delivery orders and capacity decisions are proven enjoyable.

## Completed Work

- Added shared-source route discovery as a non-player-facing foundation. The
  process network exposes complete eligible trains by stable pump identity;
  the refinery model binds FeedAllocation to that discovery and persists an
  explicit stopped-only selection. Physical headers and selection UI remain
  intentionally out of scope.

- Milestone 10 completed:
  - Added fixed, catalog-driven Naphtha and heavy-residue deliveries to the
    existing Area 02 contract economy; no market simulation or second pricing
    system was introduced.
  - Renamed player-facing light/heavy inventory to Naphtha and Tung rest.
  - Diesel dispatch still requires the existing physical sample and LAB-101.
    It now consumes only its authorized diesel inventory; Heavy's established
    delivery also consumes its ordered heavy fraction.
  - Added a small LAB / SALG product-delivery modal for the remaining Naphtha
    and Tung rest, with volume requirement, price preview and one atomic
    inventory-consuming dispatch per product.
  - Preserved Sour crude: only Sour diesel needs HT-201; its Naphtha and Tung
    rest remain normal product outputs.

- Phase 1 repository, architecture, gameplay, QA, test, scene, and economy
  review completed without changing implementation code.
- Milestone 1 completed:
  - Added persistent Area 02 commissioning completion on the first approved
    built-refinery sale.
  - Added a pre-dispatch batch snapshot with actual crude processed, all three
    fraction volumes, volume-weighted diesel quality, average process
    temperature, revenue, proportional crude cost, and net result.
  - Added a readable 1280 x 720 report overlay which locks movement,
    interaction, and build controls until Enter or Escape dismisses it.
  - Added dynamic Area 02 guidance and an explicitly voluntary 95 percent
    quality challenge after commissioning.
  - Added revision-bound, four-second, two-step confirmation before product
    disposal; active production must be stopped first.
  - Scoped diesel readiness, sales, report inventory, temperature alarms, and
    column activity to the active process route.
  - Corrected the built pump so a second interaction actually stops it.
  - Updated player terminology from `commissioning batch` to `oppstartsbatch`.
- Milestone 2 completed:
  - Added a required player-built manual valve between the pump and heater.
  - Added a closed-by-default red/perpendicular valve handle which turns
    green/parallel when opened, with matching contextual prompt and status.
  - Added valve-aware topology validation, seven active route segments, and a
    clear rejection when the player tries to bypass the valve.
  - Added a real `LOW FLOW` troubleshooting state: the pump remains on, flow
    and transfer stay at zero, and opening the correct route valve resumes the
    same mass-conserving process.
  - Routed Area 02 alarms through the existing red alarm display and kept
    simultaneous high-temperature safety information visible.
  - Raised the minimum pilot contract to 3 000 kr so the required 2 600 kr
    starter refinery still leaves enough for one paid recovery batch.
  - Kept the original pilot plant behavior and interaction sequence unchanged.
- Milestone 3 completed:
  - Added one versioned local JSON autosave for pilot state, economy,
    progression, player transform, construction, directed topology, process
    inventory, controls, commissioning state, and batch-report accumulators.
  - Added a single Continue/New Game startup choice. New Game requires a second
    confirmation and archives the previous primary, backup, and corrupt file.
  - Added whitelist validation for every persisted section before live state is
    touched, including bounds/overlap, unit IDs, serials, port direction,
    process order, cycles, tank capacities, quality, money, and mass-balanced
    report data.
  - Rebuilt loaded connections through the existing authoritative
    `ProcessNetwork` rules and recreated all seven visual pipes from the same
    directed endpoints.
  - Restored partial-batch volume, temperature, quality, proportional crude
    cost and report tracking while always forcing pumps and derived flow off.
  - Added temporary-file replacement, one last-known-good backup, corrupt-file
    preservation and explicit feedback when an older backup is recovered.
  - Kept routine autosaves silent so process and troubleshooting messages are
    not overwritten; write failures remain prominent.
- Milestone 4 completed:
  - Added a small data-driven raw-oil contract catalog with Standard and Heavy
    feeds while preserving the pilot plant and the established Standard curve.
  - Added a modal post-commissioning delivery choice. Standard costs 300 kr and
    targets 200 °C; Heavy costs 180 kr, targets 230 °C, yields more residue and
    offers one 1 000 kr bonus for an approved delivery.
  - Locked process yield, quality, sale requirements and payout to the loaded
    batch so a cheaper feed cannot be changed into a higher-paying contract.
  - Blocked new contracts while any built tank contains process material or a
    pump is commanded on, including material disconnected from the active route.
  - Made alarms, objectives, tank inspection, readiness and batch reports use
    the active feed's temperature and quality requirements.
  - Upgraded persistence to format 2 and added strict format-1 migration to a
    Standard contract without a free batch or retroactive delivery bonus.
- Milestone 5 completed:
  - Added the fixed LS-201 local control station on the west side of Area 02,
    unlocked only after the player completes the refinery manually once.
  - Added active-route telemetry for source level, heater temperature and
    target, actual flow, product levels, pump command and manual-valve state.
  - Added remote start/stop for the active-route pump and remote cycling of the
    existing heater target without introducing a second process-state owner.
  - Added a remote-start temperature permissive and trip which uses the loaded
    Standard or Heavy contract range and stops before unsafe material transfer.
  - Kept field-start behavior unchanged and the manual valve field-only, so
    closed-valve LOW FLOW remains an intentional troubleshooting lesson.
  - Added a live modal panel, truthful idle/guard/alarm feedback, save-safe
    transient state, and an explicit unlock location in the batch report.
- Post-roadmap recovery fix completed:
  - Confirmed a real softlock after two failed commissioning batches left the
    player with only 100 kr and no affordable crude or refundable escape.
  - Restored the free Standard commissioning entitlement only after a failed
    pre-commission batch is completely and safely discarded.
  - Allowed repeated learning attempts, including across save/load, while the
    first approved sale permanently ends the subsidy and keeps later Standard
    and Heavy deliveries paid.
- Milestone 6 completed:
  - Added a physical post-commission diesel sample taken from the active
    route's product tank while all pumps are stopped.
  - Bound each transient sample to product-inventory revision, tank ID and
    contract ID; production, topology changes, loading, disposal, sale and
    save/load invalidate authorization safely.
  - Added LAB-101 analysis of actual volume, quality and average process
    temperature against the loaded Standard or Heavy contract.
  - Hid exact paid-batch quality in the Area 02 HUD, tank label and inspection
    until the correct tank's current sample has been analyzed.
  - Required a current, analyzed and approved sample before post-commission
    dispatch while preserving the original pilot and first commissioning sale.
  - Added a small view-only lab modal; approved Enter reuses the authoritative
    consuming sale, while OFF-SPEC keeps inventory, money and bonus unchanged.
  - Made running pumps block analysis/readiness even at zero flow, and canceled
    stale product-disposal confirmation when sampling or opening the lab.
- Milestone 7 completed:
  - Added explicit enumeration of complete routes while keeping the process
    network as the sole topology authority.
  - Rejects the final connection that would complete a second Area 02 line,
    atomically preserving the existing route, inventory and pipe visuals.
  - Treats manipulated or legacy two-route topology as invalid with no hidden
    first-route selection for flow, loading, sampling, sales or LS-201.
  - Added actionable build, HUD, objective and station feedback; disconnecting
    one pipe with `G` immediately restores the remaining complete line.
- Milestone 8 completed:
  - Turned the two existing crude choices into catalog-derived feed/order
    packages without adding separate mutable order state or a save migration.
  - Standard keeps the proven diesel target; Heavy now requires 600 L of active
    route heavy fraction plus 200 L diesel and a 90 percent diesel-quality test.
  - LAB, dynamic objectives and reports distinguish process quality from
    ordered product volume and explain recoverable shortfalls without urging
    the player to destroy a still-completable batch.
  - Continued production invalidates an early sample; a fresh qualifying sample
    dispatches once with exact proportional cost and the one-shot Heavy bonus.
  - Disconnected product now blocks dispatch instead of being silently erased;
    successful sale consumes only the three authorized active-route tanks.
  - New optional report fields are catalog-validated while older format-2
    reports without those fields remain valid.
- Flow/capacity milestone completed:
  - Added persistent 5, 10 and 15 L/s flow targets to the active built pump,
    unlocked only after the first Area 02 commissioning delivery.
  - Kept `E` as pump start/stop and added contextual field `Q` plus LS-201 key
    `3`; both use the same model-owned cycle and reject spare/invalid routes.
  - Preserved 10 L/s as the existing baseline. Low flow widens and high flow
    narrows the temperature margin used by quality, alarms and the LS-201
    remote-start permissive.
  - Kept actual flow distinct from target flow during closed-valve LOW FLOW,
    full-tank backpressure and source depletion.
  - Added volume-weighted average flow to physical samples, LAB-101 results and
    batch reports without revealing quality before analysis.
  - Persisted the pump target and accumulated report history while still
    restoring every pump stopped. Older format-2 states default safely to
    10 L/s without a format bump.
- Maintenance milestone completed:
  - Added the first recoverable Area 02 fault: sustained 15 L/s paid-batch
    operation can restrict the active pump's filter and reduce actual flow to
    35 percent of its selected target.
  - The symptom is deliberate: the pump remains commanded on, the valve is
    open and material still moves slowly, so the player must compare actual
    flow against the target, inspect the pump, stop it and then clean the
    filter with `F`.
  - Repair changes no material, money, contract or quality state. The one-time
    fault state survives save/load while normal load safety still forces pumps
    off; legacy saves receive a clean no-fault default.
- Sour-treatment milestone completed:
  - Added Sour raw oil as a low-cost feed whose diesel remains high in
    simplified sulfur even at the correct process temperature.
  - Added HT-201, a buildable diesel treatment unit with a real optional route:
    column diesel OUT → treatment IN → diesel tank.
  - Treatment keeps diesel mass-conserving while lowering sulfur to LAB-101's
    contract specification; direct Standard and Heavy routes remain unchanged.

## Validation

- Shared-source discovery and allocation tests: two complete routes from one
  structural source fixture are discovered deterministically; only the chosen
  train consumes material; switching is blocked while either source pump runs;
  model save/load preserves the valid chosen train.

- Pilot/economy suite: passed.
- Process-network suite: passed.
- Building-system suite: passed.
- Built-refinery model suite: passed.
- Main integration suite: passed.
- Main scene: started headlessly without parser, resource, or runtime errors.
- Final v0.12 maintenance regression:
  - pilot/economy, process-network, building, built-refinery, Main integration
    and save-system suites all passed;
  - the focused fault test covers high-flow restriction, LOW FLOW diagnosis,
    stop-before-service, mass preservation, repair recovery and safe save/load;
  - full headless editor/resource scan and `git diff --check` passed.
- No Codex app terminal session was available; Godot CLI output was used.
- Final Milestone 1 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 50 checks passed;
  - building system: 34 checks passed;
  - built refinery: 64 checks passed;
  - Main integration: 29 checks passed;
  - main scene and full headless editor/resource scan passed.
- Final Milestone 2 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 77 checks passed;
  - Main integration: 33 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Final Milestone 3 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 77 checks passed;
  - Main integration: 33 checks passed;
  - save system: 37 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Milestone 4 focused validation:
  - Standard at 200 °C retained 300/350/350 L output and 2 800 kr revenue;
  - Heavy at 230 °C produced 150/220/630 L at 100 percent quality and paid
    1 760 kr plus one 1 000 kr bonus;
  - Heavy at 200 °C produced only 180 L diesel at 64 percent quality and was
    rejected without consuming inventory or its pending bonus;
  - contract switching, repeated purchase/sale, disconnected inventory and
    v1-to-v2 migration received focused regression coverage.
- Final Milestone 4 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 100 checks passed;
  - Main integration: 41 checks passed;
  - save system: 45 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Milestone 5 focused validation:
  - LS-201 telemetry matched exact route state before, during and after flow;
  - a closed manual valve held flow and mass at zero after remote pump start;
  - remote temperature protection blocked cold starts and tripped before an
    out-of-range tick could transfer material;
  - spare equipment and invalid topology could not be controlled remotely;
  - the live panel blocked field/build input and preserved modal state as
    transient across saves.
- Recovery softlock validation:
  - three consecutive cold commissioning batches were rejected and safely
    discarded without revenue, bonus, or retained material;
  - every failed attempt restored exactly one free Standard retry;
  - the retry entitlement survived save/load;
  - the first approved retry completed commissioning once, and the following
    Standard batch again charged exactly 300 kr.
- Milestone 6 focused validation:
  - disconnected tanks and running pumps were rejected for sampling/analysis;
  - early analysis reported missing volume without consuming product;
  - new production and topology changes invalidated stale samples;
  - exact quality remained hidden on disconnected diesel after active analysis;
  - load preserved product but removed all transient sample authorization;
  - approved Standard and Heavy samples dispatched once with exact revenue and
    bonus, while OFF-SPEC Enter changed no material or money.
- Final Milestone 6 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 152 checks passed;
  - Main integration: 66 checks passed;
  - save system: 47 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Final Milestone 7 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 87 checks passed;
  - building system: 41 checks passed;
  - built refinery: 163 checks passed;
  - Main integration: 66 checks passed;
  - save system: 47 checks passed;
  - main scene and full editor/resource scan loaded successfully with no
    project parser, resource, runtime, or script errors. The sandboxed editor
    still reports its known inability to save global macOS editor settings.
- Final Milestone 8 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 87 checks passed;
  - building system: 41 checks passed;
  - built refinery: 178 checks passed;
  - Main integration: 67 checks passed;
  - save system: 51 checks passed;
  - main scene and full editor/resource scan loaded successfully with no
    project parser, resource, runtime, or script errors. Only the known
    sandboxed macOS certificate/editor-settings warnings remain.
- Final adjustable-flow regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 87 checks passed;
  - building system: 41 checks passed;
  - built refinery: 196 checks passed;
  - Main integration: 70 checks passed;
  - save system: 57 checks passed;
  - main scene and full editor/resource scan loaded successfully with no
    project parser, resource, runtime, or script errors.
  - Git checkpoint creation was attempted after validation, but the execution
    environment rejected repository writes because its approval/usage limit
    had been reached. All verified changes remain saved in the working tree.
- Final Milestone 5 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 116 checks passed;
  - Main integration: 53 checks passed;
  - save system: 46 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.

## Bugs Found

- Area 02 has no persistent completion state or batch result after a valid sale.
- Process alarms inspect every placed heater rather than the active route only.
- Spare columns glow when another route is flowing.
- A diesel tank can glow ready below the 200 L acceptance quantity.
- Product disposal is a destructive single-key action without confirmation.
- Multiple complete routes validate although only the first route operates.
- Physical 1280 x 720 port aiming and real input timing still need hands-on QA.
- Requiring the valve initially left only 200 kr after minimum pilot funding,
  which could soft-lock a player after an off-spec free batch.
- Area 02 process alarms were present in summary text but not in the prominent
  red alarm display.
- Initial persistence integration could partially mutate state if applied over
  an already populated refinery.
- Autosave confirmation reused the process notification and could hide useful
  LOW FLOW feedback.
- Backup recovery was technically successful but invisible to the player.
- An unbounded saved build counter could make the next generated save invalid.
- A concurrent parallel Godot run collided over the engine log and crashed;
  all authoritative validation was rerun sequentially with isolated log files
  and passed.
- The repeatable refinery had one fixed Standard feed and one 200 °C solution,
  so post-commissioning play did not require process adaptation.
- Early contract UI drafts could describe an overheated Heavy batch as ready,
  advertise a new purchase while old products remained, or show a fictitious
  0 °C process average before any production.
- Early LS-201 feedback showed a fictitious 0 °C target while idle and let a
  stale successful command hide a later LOW FLOW alarm.
- Two failed commissioning attempts could leave only 100 kr and permanently
  strand the player without crude, income, or enough refundable value.
- Quality was visible continuously, and LAB / SALG analyzed and sold in one
  interaction, so laboratory work was not an actual player action.
- Early lab integration could reveal disconnected tank quality, advertise
  dispatch while a pump ran, or preserve an old disposal confirmation.

## Bugs Fixed

- Fixed manual built-pump stop doing nothing.
- Fixed disconnected hot/cold heaters creating false alarms for the active line.
- Fixed spare columns glowing when another line was flowing.
- Fixed tiny high-quality diesel volumes looking sale-ready before 200 L.
- Fixed disconnected legacy diesel influencing active-line readiness and sale.
- Fixed Area 02 remaining permanently unfinished after an approved sale.
- Fixed single-key destruction of approved or off-spec product inventory.
- Fixed the recovery-batch economy soft-lock after constructing the required
  valve-inclusive refinery.
- Fixed built `LOW FLOW` and `HIGH TEMPERATURE` alarms being visually muted or
  one condition hiding the other.
- Restricted save restoration to the pristine startup scene, added rollback
  for unexpected construction failures, and tested repeated-load atomicity.
- Made routine autosave silent and preserved operational notifications.
- Added explicit last-known-good recovery feedback and canonical serial bounds.
- Added batch-locked Standard/Heavy provenance, exact single-charge/single-bonus
  transactions and material-empty switching rules across disconnected tanks.
- Made high/low temperature guidance, source prompts, empty-process sales and
  report-dismiss messages agree with the actual contract and inventory state.
- Made LS-201 idle state, remote-guard mode and alarm priority agree with the
  active batch and actual process condition.
- Made pre-commission learning retries repeatably subsidized only after all
  failed material is safely removed; approved commissioning ends the subsidy.
- Added tank-bound, revision-bound lab results; synchronized pump-stop and
  disposal safety with analysis and final dispatch.

## Current Stable State

- Version 0.20.0 is verified stable after the first refinery-operations milestone.
- Area 02 now discovers and runs multiple independent complete refinery trains;
  source contracts, temperatures, flow, capacity limits, sulfur treatment,
  pump-filter faults and route product storage remain local to each train.
- A buildable Crude Feed Header now makes the shared-source rule physical:
  one IN, two labelled outlets and an explicit stopped-only `A → B → NONE`
  selection. The selected branch alone may draw from the source; no automatic
  split or fallback is allowed.
- The original pilot loop and full player-built loop both pass regression.
- The first valid Area 02 sale now has a durable achievement and informative
  result, while later paid batches remain repeatable.
- The complete built process now teaches the intended sequence directly:
  tank → pump → valve → heater → distillation → product tanks.
- A player can now leave during a partial paid batch and safely continue with
  the same mass, process conditions, economy and construction on next launch.
- After commissioning, the same refinery now supports two economically and
  operationally distinct feed choices instead of repeating one 200 °C recipe.
- After proving manual operation, the player can monitor the active route from
  LS-201 and use limited remote control with a feed-aware temperature trip,
  while still walking into the plant to operate and troubleshoot the valve.
- Repeated off-spec commissioning mistakes no longer force a new game; the
  player can continue learning without creating post-commission free batches.
- Paid batches now end in an actual sample → analysis → conditional dispatch
  loop instead of exposing all quality data and selling in one interaction.
- Standard and Heavy now produce different player goals: a Heavy batch can have
  good diesel quality while still needing more ordered heavy fraction.
- After manual commissioning, the player can choose slower, normal or faster
  pumping and see the capacity-versus-quality-margin consequence in both field
  instruments and laboratory evidence.
- Sustained 15 L/s operation can now trigger one persistent pump filter
  restriction in paid Area 02 operation. It reduces actual flow without
  changing material balance or the selected target; the player must inspect the
  pump, stop it and use field service to restore capacity. Loading preserves the
  fault but stops the pump safely.
- Sour crude is now a genuine refinery-capability choice: its cheaper diesel
  is only sellable after the player builds, connects and starts HT-201.
- A processed barrel now leaves separate Naphtha, diesel and heavy-residue
  inventories. Diesel remains LAB-controlled, while stored by-products must be
  delivered through their own finite-volume product orders before the next feed
  can be chosen.

## Known Issues

- Multiple independent process trains and one manually selected shared-feed
  header are supported. General manifolds, split flow, recirculation, product
  headers and refinery-wide route selection remain deliberately out of scope.
- Hands-on aiming/interaction feel remains unverified by headless automation.
- Valve handle readability and central alarm prominence still need a hands-on
  check at the target 1280 x 720 window size.
- Report accounting covers material processed since the previous sale or
  disposal. After an early partial sale, the next report covers only the
  remaining material processed afterward and its proportional crude cost.
- Save format 1 is migrated explicitly to Standard; unknown older or future
  versions are still preserved and rejected rather than guessed.

## Roadmap Changes

- The overnight log suggested small port polish next. Current review showed that
  player motivation and closure after the built sale are higher value, so the
  first milestone is now the Area 02 commissioning result.
- Architecture review found the proposed 95 percent follow-up was not an
  enforceable contract. It is now explicitly labelled as a voluntary challenge
  and the normal load/heat/pump/deliver guidance remains active.
- After Milestone 1, the manual valve moved ahead of persistence because it
  completes the core tank–pump–valve–heater learning chain and creates the first
  player-readable troubleshooting event with little architectural risk.
- Persistence stayed deliberately local and single-slot. Cloud sync, multiple
  profiles and offline production would add complexity without improving the
  current refinery learning loop.
- Crude variety was limited to Standard and Heavy. Sour crude remains deferred
  because it would be a label without meaningful treatment equipment today.
- The completed five-milestone roadmap was reassessed from the actual 0.8.0
  loop. A QA-discovered commissioning softlock moved ahead of the planned lab
  milestone; the next content focus is now physical diesel sampling.
- Lab state remains transient by design: a loaded game preserves the product
  but requires the player to take a fresh sample, avoiding save-format churn
  and stale authorization.
- Independent complete process trains now coexist without an implicit route
  selector. Shared equipment, manifolds and branching remain deliberately out
  of scope until their material-routing rules can be made explicit.
- Delivery orders remain derived from the batch-locked crude contract. A new
  independent order market was deliberately avoided until two orders prove fun.
- Adjustable flow was added to the existing pump rather than introducing pump
  tiers or a second simulation owner. The quality calculation uses the selected
  operating point, so long frames and capacity-limited transfers cannot
  accidentally improve product quality.
- Shared-source routing is now staged deliberately: candidate discovery and
  stopped-only allocation were completed before the physical header was added.
  The header deliberately exposes only one selected outlet at a time.

## Next Best Action

- Perform the deferred hands-on 1280 x 720 playtest with special attention to
  header port targeting, A/B/NONE status readability and multi-train feedback.

## v0.16 — Physical Shared-Feed Routing

- Added the buildable Crude Feed Header (`IN`, `OUT A`, `OUT B`) to the normal
  Area 02 catalog, placement, rotation, port visualization, deletion and save
  validation paths.
- Extended route discovery to recognize `tank → header → pump` while retaining
  the direct `tank → pump` route for simple refinery trains.
- Connected the physical header to the existing FeedAllocation authority. `E`
  cycles A, B and no selected route; a selected branch cannot change while any
  pump fed by that source is running.
- Selected-branch deletion clears ownership instead of silently choosing the
  remaining branch. Header deletion clears its allocation and invalidates the
  associated routes.
- Confirmed source-volume conservation while switching a single Standard batch
  between two trains, plus Sour batch identity and treatment isolation through
  the selected branch.
- Validation performed: process model, process network, building system,
  built refinery model, Main integration and save system suites; headless
  editor scan and `git diff --check` are recorded with the checkpoint.

## v0.17 — Product Routing and Tank Farm

- Added the buildable Product Routing Header (`IN`, `OUT A`, `OUT B`) to the
  existing Area 02 placement, rotation, port, deletion and save-validation
  paths.
- Extended complete-route discovery for either a column product outlet or
  HT-201 diesel outlet feeding the optional header. Direct machine-to-tank
  routes remain fully valid.
- Added explicit `ProductAllocation`: `E` cycles A, B and NONE only while the
  producing train is stopped. The selected destination is the sole runtime
  owner of new material; no automatic split, fallback, blending or teleporting
  occurs.
- Product routing preserves product identity, diesel quality, sulfur and
  treatment state. Full, incompatible or unselected storage blocks the source
  transfer without consuming crude.
- Added focused graph, build, model and Main save/load coverage for destination
  discovery, switching, deletion, capacity behavior, treated Sour diesel and
  physical header restoration.

## v0.18 — Instrumentation and Automatic Temperature Control

- Added TIC-201 as an earned, per-heater control mode after Area 02
  commissioning. The existing heat state now stores PV, SP, MANUAL/AUTO mode
  and actual output percentage; no parallel heater simulation was introduced.
- `E` retains existing setpoint selection. Field `Q` switches the focused
  heater safely between MANUELL and AUTO, retaining a deterministic current
  output on transfer.
- AUTO applies bounded proportional output adjustment to the existing heater.
  It carries no artificial quality bonus: product quality still follows actual
  temperature and flow.
- A commanded pump against a closed manual valve creates the existing LOW FLOW
  symptom and blocks AUTO output. It does not restart pumps, open valves or
  change feed/product routing.
- LS-201 now presents TIC-201 mode and heater output alongside its established
  PV/SP, level and flow readings. Save/load persists mode, SP and output while
  retaining the existing pump-stop safety rule.

## v0.19 — Operator Alarms and Process Interlocks

- Added one lightweight, derived operator-alarm layer. It observes existing
  per-train route and equipment state instead of duplicating flow, temperature
  or tank simulation.
- LS-201 now lists active LOW FLOW, HIGH TEMPERATURE, HIGH LEVEL and TANK FULL
  alarms with equipment tags and simple HIGH/MEDIUM/LOW priority.
- Alarms name the operational symptom, not the hidden cause. For example a
  restricted filter produces LOW FLOW; field pump inspection still performs
  the diagnosis and repair.
- TIC-201 inspection now identifies the existing heat permissive as blocked by
  LOW FLOW. The interlock remains authoritative over AUTO output.
- Active alarms reconstruct from saved process state, so no stale event list is
  persisted after a repair or reload.

## v0.20 — Control Room and Refinery Operations

- Upgraded the physical LS-201 station into Refinery Operations. It discovers
  all complete process trains and presents concise overview, alarm and selected
  train operating detail without polling scene nodes.
- Operators use left/right to change only their console view. Pump, TIC setpoint
  and flow commands target the selected train through the same model APIs and
  interlocks used by existing remote controls.
- Field-only work remains physical: valve/header routing, sampling, LAB work,
  equipment inspection and filter repair are not exposed by the console.

## v0.21 Foundation 2 — Route Envelope and Typed Consumer Hardening

- Added a bounded ProcessNetwork route envelope: process type, stable route ID,
  source, primary pump and equipment-membership helpers. Atmospheric route
  discovery now supplies a stable `atmospheric:<pump-id>` route ID.
- Classified existing consumers deliberately. Process identity and topology
  cleanup remain shared; FeedAllocation/Crude Feed Header, product allocation,
  lab/dispatch, active-pipe visuals, alarms, LS-201 and atmospheric simulation
  now request atmospheric routes explicitly.
- Added safe atmospheric lookups for physical and remote interaction. A future
  route that does not define valve/heater/column/product fields is ignored by
  current atmospheric systems instead of being interpreted as a broken
  atmospheric process.
- Preserved current material behavior, validation and save data. This was an
  architecture-hardening change only: no VDU equipment, route discovery,
  vacuum material, runtime flow or player UI was added.
- Added synthetic sparse-vacuum tests covering the route envelope, type
  filtering, feed-access rejection, alarm safety, product-routing rejection
  and LS-201 atmospheric-only visibility.
- Validation: process model, process network, building system, built refinery,
  Main integration and save-system suites passed; headless main launch, editor
  resource scan and `git diff --check` passed.

## v0.21C — Vacuum Route Contract and Discovery

- Added the non-menu VDU-301 equipment skeleton with one Heavy Residue input
  and explicit VGO and Vacuum Residue outputs. It is deliberately not a
  purchasable/player-placeable machine yet.
- `ProcessNetwork` now discovers a bounded `vacuum_distillation` route when
  intended tank material forms Heavy Residue tank → pump → VDU → VGO tank and
  Vacuum Residue tank. Discovery is structural, so an empty source remains a
  valid planned route.
- Vacuum routes use their own compact payload (`vdu` and two outputs) plus the
  common route envelope. They do not inherit atmospheric valve/heater/column
  assumptions. Existing atmospheric consumers ignore them safely, and the
  runtime makes no VDU material transfer yet.
- Focused tests cover discovery, stable identity, empty-source intent,
  wrong-feed rejection, missing pump/VDU/output invalidation, mixed route
  families and no-op runtime handling. Existing generic saves remain valid.
- Validation: all six regression suites passed; headless main launch, editor
  resource scan and `git diff --check` passed.
- Known deliberate gap: intended tank material is currently runtime discovery
  metadata, not persisted save data. Do not expose VDU construction or atomic
  VDU processing until that metadata and transaction state are saved.

## v0.21D — Persisted Material Intent and Atomic VDU Processing

- Tanks now persist `material_intent` separately from actual contents. Empty
  tanks retain their intended material, and existing saves infer intent from
  non-empty known contents when the optional field is absent.
- Tank writes reject incompatible intended material. An unassigned tank adopts
  its first accepted material without changing existing atmospheric gameplay.
- Added isolated `_tick_vacuum_route()` dispatch. A running VDU feed pump
  processes actual Heavy Residue only, using a fixed 60% VGO / 40% Vacuum
  Residue split with no contracts, quality, LAB or HT-201 dependencies.
- VDU capacity is pre-calculated across both outputs before source mutation;
  partial capacity scales the complete transaction, while a full/incompatible
  destination consumes no feed and produces nothing.
- Headless integration proves atmospheric Heavy Residue in one physical tank
  can feed VDU, and that partial VDU construction/inventory/intents survive
  normal snapshot validation, reload and continued processing.
- Validation: all six regression suites passed; headless main launch, editor
  resource scan and `git diff --check` passed.

## Next Best Work

- Perform the deferred hands-on 1280×720 interaction pass, including VDU port
  labels, build-menu readability and the secondary-product delivery modal.

## v0.21.0 — Playable Vacuum Distillation

- Released VDU-301 through the normal Area 02 build menu with a 1,200 kr
  purchase cost, typed ports and ordinary field inspection.
- A Heavy Residue feed pump operates the existing atomic 60/40 transfer;
  feed depletion stops safely and running VDU pipes receive flow visuals.
- Added separate physical dispatch orders for Vacuum Gas Oil (4 kr/L) and
  Vacuum Residue (1 kr/L). Neither needs LAB approval; each consumes only its
  own tank inventory.
- Validation: all six Godot suites, headless main launch, editor resource scan
  and `git diff --check` passed. Human 1280×720 playtesting remains deferred.

## v0.22.0 — Electrical Utilities and Refinery Capacity

- Added the normal buildable PU-101 Power Unit. It contributes 100 kW to the
  Area 02 starter capacity, has no process ports and persists through existing
  construction/state snapshots without a new save schema.
- Added derived electrical load checks to ordinary pump and diesel-treatment
  start commands. A VDU feed pump correctly includes both pump and VDU load;
  a rejected command changes no running equipment or material state.
- Added a small `POWER` line to Refinery Operations and clear field inspection
  for PU-101. High load is informative only; it does not invent a blackout or
  override existing process safety rules.
- Validation: focused building/refinery/Main/save coverage plus full Godot
  regression, headless main/editor scans and `git diff --check` pending final
  checkpoint. Deferred: human 1280×720 interaction test.

## v0.22.1 — Stabilization, Save Reliability and Area 02 Expansion

- Preserved the existing player save and backup while investigating the reported
  first-batch save failure. The retained save validated successfully, and a new
  repeated autosave stress path now writes, reads and restores a commissioning
  batch at 100 L intervals, including the reported 400 L point.
- Hardened atomic saves: the temporary file is checked for write errors and
  fully validated before it can replace the previous primary/backup pair. Save
  feedback now includes the specific safe failure reason.
- Fixed a captured runtime crash when using `E` on a Heavy Residue tank. Product
  dispatch results do not include a crude-purchase `charge`; Main now treats it
  as an optional field and credits only the returned product revenue.
- Reworked the 1280×720 HUD hierarchy: yellow objective and alarms occupy a
  dedicated top band; HUD/help are below it; prompt and notification text wrap
  in separated bottom bands.
- Expanded Area 02 from 560 m² to 1,120 m². Ground, build pad, boundary markers,
  placement bounds and save-position validation now agree; existing coordinates
  remain valid.
- Added regressions for direct Heavy Residue tank dispatch, repeated first-batch
  autosaves through 400 L and atomic restoration, plus construction in the new
  Area 02 space.

## Next Best Work

- Perform the deferred human 1280×720 playtest: confirm the new HUD spacing,
  expanded build-pad readability, FCC port labels and long modal text in the
  actual running game.

## v0.23.0 — FCC-401 Catalytic Cracking and VGO Upgrading

- Added FCC-401 as the normal 2,200 kr Area 02 build-menu unit with one typed
  VGO input and Gasoline Blendstock, LPG and LCO outputs.
- Added a separate typed FCC route: VGO tank → pump → FCC-401 → three typed
  storage tanks. The running feed pump commits an atomic fixed 55/25/20 split;
  blocked or incompatible output storage leaves the VGO source untouched.
- Added physical dispatch orders worth 7 kr/L (Gasoline Blendstock), 5 kr/L
  (LPG) and 3 kr/L (LCO). Each dispatch consumes only its own storage tank.
- FCC adds 40 kW auxiliary demand to its running pump's normal 25 kW, so the
  existing electrical-capacity system now makes expansion a real constraint.
- Persisted FCC equipment, typed VGO/product tank intent, processed totals and
  partial material inventory through the standard snapshot system.
- Validation: test-first FCC route discovery, focused building/refinery/save
  tests and the full Godot regression/headless checks passed before checkpoint.

## v0.24.0 — Equipment Condition and Preventive Maintenance

- Introduced a small reusable pump-condition layer beside—not inside—the
  existing blocked-filter fault. New pumps begin at 100%; only successful
  material transfer reduces their condition.
- Condition deterministically reduces actual capacity at WORN/POOR thresholds,
  with high selected flow wearing faster. A fully depleted pump stops and
  cannot be restarted until serviced.
- Added physical F-key preventive maintenance for stopped pumps, with a 75 kr
  shared-economy cost. Filter cleaning remains free and only clears its own
  restriction; preventive service restores only condition.
- Applied condition-limited capacity to atmospheric, VDU and FCC feed pumps.
  It preserves their existing atomic material transactions and does not alter
  LS-201's scope.
- Saved/restored condition safely and validated its range; legacy saves without
  the optional field still load as 100% condition.
- Added focused model, Main economy and save-schema regression coverage.

## Next Best Work

- Perform the deferred human 1280×720 playtest, then tune pump-condition wear
  and the preventive-service price from observed player pacing before adding a
  broader maintenance system.

## Strategic Alignment Pass — v0.24

- After atmospheric processing, routing, treatment, VDU, FCC and electrical
  capacity, the project has sufficient process depth to change priority.
- Future work should primarily strengthen physical building, feedback,
  progression, troubleshooting, maintenance, player ownership and scalable
  refinery gameplay rather than add process units by default.
- The same normal-game systems must support a focused ~20-minute concept, a
  coherent 45–90 minute session and multi-hour sandbox expansion. The deferred
  hands-on playtest is therefore the next decision input, not a cosmetic task.

## v0.24.1 — Physical Refinery Feedback

- Extended built-tank liquid visuals to distinguish every material currently
  producible in Area 02: crude, the atmospheric fractions, VGO, vacuum residue,
  Gasoline Blendstock, LPG and Light Cycle Oil.
- Added a small local rotor to each player-built pump. It spins only while that
  pump is commanded on, making a running motor readable independently of the
  existing build/connection highlight.
- Validation: focused building/Main integration coverage passed. The remaining
 1280×720 first-person readability and interaction-feel check still needs a
 human playtest and is not claimed as complete.

## v0.24.2 — Route-Local Pipe Flow

- Corrected Area 02 flow markers to use each route's measured pump flow rather
  than one refinery-wide total. A stopped, blocked or full train now keeps its
  pipes still while another train can continue to show movement.
- Shared-feed branches retain their own intensity; a shared inlet reflects the
  combined moving branches. VDU and FCC pipes also stay still at zero flow.
- Validation: focused route-flow coverage plus the full regression gate passed.
  Human QA still needs to confirm marker readability at walking distance.

## v0.24.3 — Secondary-Train Safe Stops

- VDU and FCC feed pumps now reject starts with an empty/wrong feed or blocked
  output storage, avoiding an illuminated, power-consuming pump that cannot
  move material.
- If an already-running secondary train becomes blocked or runs out of feed,
  its pump stops safely, preserves material, releases its electrical load and
  requires an explicit restart after recovery.
- Validation: focused VDU/FCC guard coverage plus the full regression gate
  passed. Human QA still needs to assess whether the field status copy is clear
  at normal viewing distance.

## v0.24.4 — Local Operator Alarm Beacons

- Added a small independent emissive beacon to each player-built unit. It
  reflects the highest existing route-scoped operator alarm without replacing
  normal pump, valve, tank or rotor operating feedback.
- LOW FLOW now identifies the affected pump in-world, HIGH TEMPERATURE the
  heater, and HIGH LEVEL/TANK FULL the relevant product tank. Repairing or
  clearing the underlying condition clears the beacon automatically.
- Validation: focused beacon coverage plus the full regression gate passed.
  Human QA still needs to confirm beacon visibility and colour distinction at
  normal first-person viewing distance.

## v0.24.5 — Guided Process Connections

- Selecting an OUT port in construction mode now highlights only legal,
  currently available IN ports. The player still chooses and connects the pipe
  physically; no connection is created automatically.
- Extracted the existing connection checks into a read-only network preflight
  reused by real connection creation. Candidate discovery therefore cannot
  create pipes, assign typed tank intent or schedule a topology change.
- Validation: focused graph/build coverage plus the full regression gate passed.
  Human QA still needs to confirm the candidate highlights reduce aiming effort
  without visual clutter at 1280×720.

## v0.25.0 — Physical Feed-to-Cash Endpoints

- Added fixed CI-101 crude intake and PD-101 product dispatch endpoints to
  Area 02. They use normal build/process registration but cannot be sold or
  deleted.
- CI-101 receives the canonical crude order as a persisted pending 1,000 L
  delivery. A connected, powered player pump moves it into compatible crude
  storage; full or incompatible storage stops safely without losing material.
- PD-101 requires a physically connected compatible tank and running sales
  pump before it invokes the existing product/diesel dispatch transaction.
  Product identity, sulfur, LAB approval and revenue remain authoritative in
  the existing model; the endpoint adds no parallel economy or inventory.
- Save validation registers fixed endpoints while retaining the v2 schema and
  accepting legacy saves without logistics state.
- Added focused coverage for endpoint ports, canonical crude charge, transfer
  mass balance, pending-delivery persistence, full-tank safe stop, physical
  VGO dispatch and repeated-dispatch prevention.
- Validation: editor scan, focused logistics, save/load and Main loop passed.
  A human 1280×720 pass must still verify endpoint placement, port targeting
  and field-copy readability.

## v0.26.0 — First-Hour Progression and Starter Economy

- Replaced the broad Pilot instruction with short, authoritative objectives:
  set temperature, reach temperature, open V-101, start P-101, produce
  approved diesel and sell it. Actions completed early are recognized from
  actual process state.
- Area 02 now begins with CI-101: receive the protected free Standard delivery,
  build CI-101 → pump → crude tank, then build the atmospheric train. The
  objective updates from persisted physical material state, not interaction
  history.
- The build menu keeps basic refinery tools freely available and labels later
  equipment with process-based locks: commissioning for treatment, heavy
  residue for VDU-301 and VGO production for FCC-401. Existing equipment is
  never removed; legacy saves infer established progression from their plant.
- The first physical PD-101 delivery receives a concise one-time refinery
  operations acknowledgement. Its persisted milestone cannot create money or
  inventory by replaying it.
- Economy audit: the 3,000 kr Pilot minimum exactly funds the 3,000 kr physical
  starter line (four tanks, three pumps, valve, heater, column). The first
  CI-101 Standard delivery remains free; later Standard batches cost 300 kr.
  At target conditions, the 1,000 L Standard batch yields products worth about
  5,000 kr before feed cost. No values were changed because this already avoids
  an obvious early grind or money soft-lock; human pacing remains unverified.
- Added focused progression coverage for Pilot sequence, out-of-order state
  recognition, CI milestone persistence, legacy progression inference and
  explanatory locked build-menu entries.
