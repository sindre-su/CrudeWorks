# CrudeWorks Architecture Map

This document describes the current implementation, not the full game vision.
For long-term design, Graybox direction and scope, see `CRUDEWORKS_VISION.md`,
`WORLD_DESIGN.md` and `ROADMAP.md`.

## Runtime ownership

- `scenes/main.tscn` / `scripts/main.gd`: first-person integration, functional
  prototype equipment, contextual field/UI feedback, progression and save
  coordination. It does not own macro-world geometry, bounds, Area 02 material
  or topology rules.
- `scripts/world_layout.gd`: sole authority for canonical world coordinates,
  area/road specifications, active placement bounds, spawn and player/save
  bounds.
- `scripts/world_builder.gd`: primitive macro terrain, platforms, roads,
  paths, boundaries, starter wayfinding, collision and retained prototype pads.
  It consumes `WorldLayout` and owns no gameplay or persisted process state.
- `scripts/process_model.gd`: fixed Pilot training process, economy and original
  progression loop.
- `scripts/built_refinery_model.gd`: Area 02 material, operations, contracts,
  quality, LAB authorization, canonical dispatch, maintenance, alarms, heater
  control, utilities integration and CDU/VDU/FCC simulation.
- `scripts/process_network.gd`: sole authority for directed material topology,
  ports, valid order, complete routes and optional crude/product headers.
- `scripts/material_balance.gd`: reusable test/diagnostic invariant for
  canonical material inventories; it does not own or persist inventory.
- `scripts/utility_distribution.gd`: reusable electrical/utility bus trip and
  reset lifecycle. Electricity is instantiated; Instrument Air and Cooling
  Water are modeled as dependent utility availability in the refinery model.
- `scripts/build_controller.gd`: placement, rotation, pipe selection and visual
  connection cache; never a second logical topology.
- `scripts/feed_allocation.gd` / `scripts/product_allocation.gd`: explicit,
  stopped-only ownership selection for shared crude and product headers.
- `scripts/equipment_catalog.gd` / `scripts/crude_contract_catalog.gd`:
  equipment, port, utility-demand and contract/order data.
- `scripts/save_system.gd`: validated versioned local persistence.
- `scripts/lab_analysis_panel.gd`: transient LAB-101 presentation/input;
  analysis is not a sales path.

## Current process and dispatch flows

Pilot: heat -> open valve -> start pump -> distill -> sell approved diesel ->
unlock Area 02.

Area 02: build directed route -> receive CI-101 delivery -> transfer to crude
storage -> establish generator/MCC/IA/CW availability -> heat -> open manual
valve -> pump -> CDU fractions -> optional HT-201 treatment and selected product
storage -> sample/analyse at LAB-101 where required -> send physical product
through sales pump -> PD-101 -> canonical inventory removal and payment.

VDU-301 and FCC-401 are implemented, purchasable typed secondary routes with
fixed simplified yields, capacity-bounded atomic transfers and dedicated product
dispatch. They are functional systems, not merely planned names; their world
placement and player-facing pacing still need Graybox validation.

## Canonical state and conservation

- `ProcessModel` owns Pilot crude/light/diesel/heavy inventory.
- `BuiltRefineryModel` owns Area 02 tank contents, pending CI-101 delivery and
  GF-101 generator fuel. Pipes, headers, pumps, treatment and process units
  currently have no modeled liquid hold-up.
- Tank fills, HUD text, samples, reports, flow visuals, total electrical demand
  and hydraulic diagnostics are derived views. They must not become duplicate
  inventory or saved UI truth.
- Quality's numeric value and its analysis/spec status are distinct canonical
  fields. UI strings are never canonical save data.
- The material invariant is `before + input - output - defined loss = after`,
  checked through `MaterialBalance` with a small float tolerance. Defined losses
  must be intentional and explicit; no transfer may silently delete material.
- Save validation rejects malformed data before live mutation, while accepting
  legitimate states such as empty tanks, unanalyzed product, no required active
  contract, a stopped pump or a normal blocked route.

## Operating state and interlocks

Pump command and material movement are separate:

- `STOPPED`: deliberately stopped by the operator.
- `RUNNING | FLOW`: commanded RUN with actual material movement.
- `RUNNING | BLOCKED` or `RUNNING | NO FEED`: a normal temporary process wait;
  the RUN command remains so flow can resume after the root condition clears.
- `TRIPPED`: a genuine protection event, including route loss, power/MCC loss,
  Instrument Air/Cooling Water loss, temperature guard, equipment failure,
  material mismatch or protected dry run. Recovery never auto-restarts the
  equipment; the player must deliberately restart it.

The current resistance abstraction is diagnostic rather than a hydraulic solver:
`flow target × pump capability × restriction = achievable flow`. Pump condition
reduces capability and a blocked filter yields a derived `ΔP HIGH` restriction.
Valves and unavailable destinations remain explicit route conditions. Do not add
pipe-friction networks, CFD, transient pressure simulation or persisted derived
pressure state without an explicitly approved gameplay case.

Heaters own one PV/SP/output state and use route/actual-flow context. TIC-201
AUTO adjusts that state, while field LOW FLOW and Instrument Air fail-close can
block output. A full energy/duty balance is deliberately not implemented.

## Utilities and alarms

The implemented dependency chain is Diesel -> GF-101 -> PG-101/PU-101
generation -> MCC-101 electricity -> IA-101 and CWP-101 -> CDU availability.
Generator fuel is canonical material; generation, load totals, reserve, UI and
derived utility diagnostics are recalculated from equipment state. MCC and pump
trip states are persisted where necessary for safe recovery.

Utilities and alarms must provide visible, deterministic and recoverable cause
and effect. Root electrical loss should not create redundant downstream alarm
spam. Manual valves remain field devices; pneumatic heater control fails closed
on Instrument Air loss, and Cooling Water is a CDU condensation permissive.

## LAB and product dispatch

LAB-101 samples and analyses product, exposes specification/quality evidence and
authorizes eligible dispatch. It does not sell material. Product tanks store and
route canonical inventory but do not create a parallel economy. PD-101 is the
normal Area 02 sales boundary: dispatch removes authorized canonical inventory
atomically and pays once through the established value path.

## Persistence and world migration

Save/load persists canonical construction, material, selected operating state,
utility/trip state and stable identifiers; it rebuilds derived state and restores
pumps stopped. Existing v0.27/v0.28-compatible saves remain supported through
validated migration/fallback paths.

The 600 x 400 m world was enlarged around the old prototype coordinates.
Absolute player and construction positions are therefore retained without a
coordinate migration. `BuildController` and `SaveSystem` consume the same
active placement bounds from `WorldLayout`; player save validation and
out-of-bounds recovery consume its canonical world/spawn values. The active
construction footprint remains the original Area 02 pad until functional
migration deliberately changes it.

Graybox relocation must preserve stable IDs/semantics where saves and process
routes depend on them, retain process-network ports and interactions, and avoid
placing visual duplicate equipment that looks functional but has no model state.

## Scope boundary

The v0.28.2 process foundation remains frozen in v0.30.0. The existing fixed
Pilot is now verified as one complete fresh-save world loop without relocating
its stable IDs or absolute coordinates. Main CDU, VDU, FCC, HT-201, routing,
storage, LAB, PD-101, utilities, controls, alarms and maintenance are still
functionally located in the compact prototype neighborhood and await deliberate
migration. New major process families, detailed hydraulics and detailed thermal
simulation require an explicit post-Graybox gameplay decision.

## Test map

- `tests/process_model_test.gd`: Pilot process, economy and material diagnostics.
- `tests/process_network_test.gd`: directed process graph and typed routes.
- `tests/building_system_test.gd`: placement, ports and visual connection rules.
- `tests/built_refinery_model_test.gd`: Area 02 simulation, conservation,
  contracts, quality, LAB, dispatch, VDU/FCC, maintenance and utilities.
- `tests/physical_logistics_test.gd`: CI-101/PD-101 physical material paths.
- `tests/progression_test.gd`: unlock and first-hour progression gates.
- `tests/main_built_loop_test.gd`: end-to-end world/UI integration.
- `tests/save_system_test.gd`: persistence, validation and migrations.
- `tests/world_layout_test.gd`: canonical bounds, target footprints, legacy
  coordinates, world-builder output, ramps and non-duplicated bounds authority.
- `tests/pilot_world_integration_test.gd`: fresh southwest spawn, physical
  starter context, Pilot troubleshooting/production/sale, post-sale building,
  disk persistence and deliberate resume after reload.
