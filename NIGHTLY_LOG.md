# CrudeWorks Nightly Development Log

## Starting State

- Version 0.3 has a confirmed working pilot loop:
  heat crude, open the valve, start the pump, distill, check quality, sell
  diesel, and unlock the building area.
- The building area supports placement, 90-degree rotation, removal with full
  refund, and visual OUT-to-IN pipe connections.
- Player-built equipment is not yet connected to a logical process network and
  does not process fluid.
- The placement preview does not show IN/OUT orientation before placement.
- The project uses Godot 4.7.1 with the Compatibility renderer and has no
  external dependencies.
- No Git repository existed when the nightly run began.

## Development Progress

- Baseline inspection completed before gameplay changes.
- Placement previews now reuse the final equipment port positions and show
  labelled blue IN and orange OUT ports.
- Placement previews now include a top-mounted flow-direction arrow, while the
  build HUD reports the exact 0/90/180/270-degree orientation.
- Added a separate directed process network for Area 02. It owns stable unit
  and port IDs, rejects wrong direction/order, occupied ports, duplicates and
  directed cycles, and removes incident edges when equipment is removed.
- The column now has distinct LETT, DIESEL and TUNG outlets. Placed equipment
  and previews both derive all ports from the same catalog definitions.
- Visual pipe creation now asks the logical network for permission first.
  Build mode exposes the first actionable network fault and a manual V
  validation command without overwriting equipment operating status.

## Validation Performed

- Full project scene started headlessly in Godot 4.7.1 without parser or
  runtime errors.
- Existing process/economy suite: 22 checks passed.
- Existing building-system baseline: 18 checks passed.
- Updated building-system suite: 23 checks passed, including preview ports,
  direction marker, and orientation feedback.
- Full project scene was started again after the orientation change without
  parser, scene-loading, or runtime errors.
- The process/economy suite was rerun after the change: all 22 checks passed.
- New process-network suite passes its 49 checks, covering a complete
  six-connection topology, port rules, invalid order, cycles, removal cleanup,
  and actionable incomplete-route feedback.
- Updated building-system suite passes 27 checks after graph integration.
- All three suites and the main scene were run after integration; no parser,
  scene-loading, or runtime errors were reported.

## Bugs Found and Fixed

- Fixed unreadable placement orientation. The ghost previously created only an
  equipment body; it now uses the same catalog-backed port offsets as placed
  equipment so preview and final orientation cannot drift apart.
- Fixed the structural one-output limitation on the built column.
- Fixed logical acceptance of duplicate, reverse, occupied, out-of-order and
  cyclic process connections.
- Fixed stale connection state ownership: connection labels no longer replace
  an equipment unit's operational status, and graph edges are cleared by ID.

## Current Stable State

- The 0.3 pilot loop remains unchanged and its model tests pass.
- Visual building still works, now with readable direction before placement.
- A player can construct and validate the complete logical topology
  tank → pump → heater → column → three product tanks. It does not process
  material yet.

## Known Issues

### Confirmed bugs

- Interacting with player-built equipment advertises an inspection action but
  produces no useful response.
- Repeated pilot reset grants free crude while preserving money.

### Untested behavior

- No end-to-end test currently exercises unlock, construction, operation, and
  sale in one flow.

### Future improvements

- Lightweight process graph, player-readable validation, operational built
  equipment, built distillation/product storage, and controlled crude batches.

## Significant Files Changed

- `NIGHTLY_LOG.md`: created for this autonomous development run.
- `scripts/equipment_catalog.gd`: central port-position helper shared by
  previews and final equipment.
- `scripts/build_controller.gd`: labelled preview ports, flow arrow, and
  orientation HUD.
- `scripts/buildable_unit.gd`: uses shared port positions.
- `tests/building_system_test.gd`: protects preview direction feedback.
- `scripts/process_network.gd`: authoritative lightweight Area 02 topology and
  player-readable validation.
- `scripts/process_port.gd`: stable port ID/material metadata and selectable
  port collision.
- `tests/process_network_test.gd`: focused graph rule and route tests.

## Next Best Work

- Add an independent built-refinery state model on top of the validated graph,
  starting with explicit tank/pump/heater state and mass-conserving transfer.
