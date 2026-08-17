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
- Added an independent Area 02 refinery model with explicit tank contents,
  volume, capacity and temperature; pump state/actual flow; heater setpoint and
  temperature; and column throughput.
- A complete built line can now load one clearly labelled free commissioning
  batch, warm to a chosen setpoint, process crude at a bounded flow rate,
  separate light/diesel/heavy fractions, and store each fraction in its routed
  tank.
- Built transfer is capacity-limited and mass-conserving. A limiting product
  tank scales the whole transfer, and a full tank stops all outputs without
  consuming crude.
- Built diesel quality is volume-weighted. Approved diesel can be sold at the
  existing terminal; sale consumes the inventory before awarding revenue.
- Later crude batches cost 300 kr. The current pilot-reset shortcut is disabled
  after progression unlock, closing the repeatable free-crude/money exploit.
- Added visible built-tank liquid levels and moving markers in built pipes while
  process flow is active. Built equipment labels now show operating state.
- Players can remove a mistaken pipe with G. Non-empty tanks and running/process
  equipment cannot be removed for a refund, and registration ownership guards
  against repeated same-frame refunds.
- After the pilot sale, the obsolete completion overlay and pilot objective are
  replaced by the Area 02 refinery objective and status HUD.

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
- New built-refinery suite passes 28 focused checks for disconnected startup,
  commissioning/paid batches, heating, mass balance, fraction yields, weighted
  quality, capacity backpressure, consuming sale, and repeated-sale rejection.
- Building suite now passes 31 checks including visible tank fill and logical +
  visual pipe disconnection.
- After full gameplay integration, the main scene, built-refinery suite,
  process-network suite, building suite, and unchanged 22-check pilot suite all
  ran successfully. A transient typed-inference parser error in the disconnect
  helper was fixed before this stable state.

## Bugs Found and Fixed

- Fixed unreadable placement orientation. The ghost previously created only an
  equipment body; it now uses the same catalog-backed port offsets as placed
  equipment so preview and final orientation cannot drift apart.
- Fixed the structural one-output limitation on the built column.
- Fixed logical acceptance of duplicate, reverse, occupied, out-of-order and
  cyclic process connections.
- Fixed stale connection state ownership: connection labels no longer replace
  an equipment unit's operational status, and graph edges are cleared by ID.
- Fixed the free post-sale pilot reset exploit by reserving new batches for the
  controlled Area 02 loader after unlock.
- Fixed repeated built-diesel sale by atomically emptying sold inventory.
- Fixed potential repeated removal refunds by checking controller registration
  ownership before refunding.

## Current Stable State

- The 0.3 pilot loop remains unchanged and its model tests pass.
- Visual building still works, now with readable direction before placement.
- A player can construct and validate the complete logical topology
  tank → pump → heater → column → three product tanks, run a complete batch,
  inspect live state, and sell approved diesel.

## Known Issues

### Confirmed bugs

- Port selection depends on aiming at small labelled ports when a unit has more
  than one outlet; this needs hands-on usability testing in the editor.

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
- `scripts/built_refinery_model.gd`: operational state, commissioning/paid
  batches, heating, mass-conserving separation, quality and consuming sales.
- `scripts/main.gd`: isolated Area 02 model integration, contextual HUD,
  interactions, economy credit and reset-exploit prevention.
- `scripts/buildable_unit.gd`: live operating labels and tank liquid visuals.
- `scripts/build_controller.gd`: disconnect action and moving built-flow
  markers.
- `tests/built_refinery_model_test.gd`: operational/mass/economy regression
  coverage.

## Next Best Work

- Add an integration test that constructs the full route through Main's
  placement hooks, then perform a focused hands-on/UX hardening pass on port
  selection, status feedback and the end-to-end unlock-to-sale path.
