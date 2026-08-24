# CrudeWorks Architecture Map

## Runtime ownership

- `scenes/main.tscn` / `scripts/main.gd`: world assembly, UI, progression and
  integration. It coordinates systems but does not own built-refinery physics.
- `scripts/process_model.gd`: fixed pilot-plant process, economy and original
  training progression.
- `scripts/built_refinery_model.gd`: Area 02 material, operating state,
  contracts, sulfur-aware quality, lab authorization, dispatch, first
  recoverable pump fault and process simulation.
- `scripts/process_network.gd`: authoritative directed topology. It validates
  ports, equipment order, cycles and the single complete Area 02 route.
- `scripts/build_controller.gd`: placement, rotation, pipe selection and visual
  connection cache; never a second source of logical topology.
- `scripts/equipment_catalog.gd` / `scripts/crude_contract_catalog.gd`:
  equipment and feed/order data.
- `scripts/save_system.gd`: validated versioned local persistence.
- `scripts/lab_analysis_panel.gd`: transient LAB-101 presentation and input.
- `scripts/player.gd`, `interactive_unit.gd`, `buildable_unit.gd`,
  `process_port.gd`, `flow_visual.gd`: first-person interaction and world views.

## Core flows

Pilot: heat -> open valve -> start pump -> distill -> sell diesel -> unlock.

Area 02: build -> validate one route -> load contract -> heat -> open manual
valve -> pump -> fractions -> optional diesel treatment -> sample -> lab ->
conditional dispatch.

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
- Material transfer is capacity-bounded and mass-conserving.
- Sale consumes authorized inventory atomically; no free repeated value.
- Save/load validates before mutating live state and restores pumps stopped.
