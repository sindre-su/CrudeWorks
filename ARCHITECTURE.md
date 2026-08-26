# CrudeWorks Architecture Map

## Runtime ownership

- `scenes/main.tscn` / `scripts/main.gd`: world assembly, UI, progression and
  integration. It coordinates systems but does not own built-refinery physics.
- `scripts/process_model.gd`: fixed pilot-plant process, economy and original
  training progression.
- `scripts/built_refinery_model.gd`: Area 02 material, operating state,
  contracts, sulfur-aware quality, lab authorization, dispatch, first
  recoverable pump filter fault/condition maintenance, TIC-201 heater control, derived operator alarms,
  electrical consumers/generation integration, operations snapshots and process simulation.
- `scripts/utility_distribution.gd`: reusable utility-bus trip/reset state and
  persistence. Electricity is the only instantiated utility in v0.27.
- `scripts/process_network.gd`: authoritative directed topology. It validates
  ports, equipment order and cycles, and discovers independent complete Area 02
  trains plus optional crude/product headers.
- `scripts/build_controller.gd`: placement, rotation, pipe selection and visual
  connection cache; never a second source of logical topology.
- `scripts/feed_allocation.gd` / `scripts/product_allocation.gd`: explicit,
  stopped-only ownership selections for shared crude sources and optional
  product-header destinations.
- `scripts/equipment_catalog.gd` / `scripts/crude_contract_catalog.gd`:
  equipment and feed/order data.
- `scripts/save_system.gd`: validated versioned local persistence.
- `scripts/lab_analysis_panel.gd`: transient LAB-101 presentation and input.
- `scripts/player.gd`, `interactive_unit.gd`, `buildable_unit.gd`,
  `process_port.gd`, `flow_visual.gd`: first-person interaction and world views.

## Core flows

Pilot: heat -> open valve -> start pump -> distill -> sell diesel -> unlock.

Area 02: build -> validate one or more trains -> receive contract -> start
PG-101 -> distribute through MCC-101 -> heat -> open manual valve -> pump ->
fractions -> optional diesel treatment -> optional product-header storage
choice -> sample -> powered lab -> conditional dispatch.

## Test map

- `tests/process_model_test.gd`: pilot process and economy.
- `tests/process_network_test.gd`: directed process graph.
- `tests/building_system_test.gd`: placement, ports and visuals.
- `tests/built_refinery_model_test.gd`: Area 02 simulation, mass, contracts,
  quality, lab and faults.
- `tests/main_built_loop_test.gd`: end-to-end world/UI integration.
- `tests/save_system_test.gd`: persistence, validation and migrations.

## Invariants

- Preserve the pilot loop unless a task explicitly changes it.
- `ProcessNetwork` is the sole topology authority.
- `BuiltRefineryModel` is the sole Area 02 operating/material authority.
- Electricity is a site-wide `UtilityDistribution`; `ProcessNetwork` remains a
  material topology and does not become an electrical cable graph.
- Electrical demand metadata lives in `EquipmentCatalog`; active demand and
  generation are derived from canonical equipment state. MCC trip state is
  persisted, while totals and UI strings are recalculated.
- Material transfer is capacity-bounded and mass-conserving.
- Each heater owns exactly one PV/SP/output state. AUTO adjusts that existing
  state, while field LOW FLOW safety can block AUTO output without routing or
  restarting equipment.
- Operator alarms are derived from route/equipment state per train. They do
  not persist independently, so cleared physical conditions cannot leave stale
  alarms after a load or repair.
- Refinery Operations is read-only projection plus commands through existing
  model APIs; it owns no material, topology or hidden maintenance state.
- A Product Routing Header sends each product only to its explicit selected tank;
  it never splits, blends or auto-switches storage.
- Sale consumes authorized inventory atomically; no free repeated value.
- Save/load validates before mutating live state, restores pumps stopped, and
  preserves generator/MCC state with v0.26.2 fallback generation.
