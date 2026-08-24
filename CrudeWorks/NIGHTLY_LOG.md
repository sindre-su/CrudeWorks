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
- Hardened progression after adversarial review: the pilot training contract
  now guarantees at least 2 800 kr, so selling at the stated 200 L minimum can
  always fund the 2 400 kr starter refinery.
- `R` in Area 02 is now an explicit zero-revenue product-disposal action. This
  clears off-spec/light/heavy storage without granting crude or money, so a bad
  commissioning run and normal repeated batches cannot permanently soft-lock
  the refinery.
- Every topology mutation immediately stops built pumps and clears flow. A
  disconnected spare pump cannot start merely because another route is valid,
  and only pipes on the active route animate.
- Area 02 guidance now follows the actual action order: load source → heat to
  about 200 °C → start pump. Tank prompts identify source and fraction roles,
  and the LAB / SALG ready light now reflects built diesel after unlock.
- Connected ports retain their own check-mark state. Port labels are visible in
  build mode and hidden during operation to reduce label clutter.
- Process-port hit targets are larger than their visible markers, and G can
  disconnect the only pipe on a looked-at machine without requiring a precise
  hit on its incoming sphere. Multi-pipe units still require an explicit port.
- Build UI moved to the upper-left with wrapping while the pilot/operation HUD
  is hidden during construction, avoiding the previous 720p notification
  overlap.
- README and project metadata now describe the completed 0.4 vertical slice,
  recovery controls, tests and full built-refinery sequence.

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
- Added a Main-level end-to-end suite that performs unlock, purchases all seven
  units, creates six visual/logical connections, loads, heats, processes, sells,
  rejects repeat sale/free reset, and guards one-time refund. It passes.
- Final hardening regression passed: pilot/economy, process network, building,
  built-refinery and Main integration suites, followed by a clean headless main
  scene launch. New checks cover minimum construction funding, off-spec
  recovery, topology-stop behavior, spare pumps, product dispatch, contextual
  guidance, terminal readiness and per-port state.
- Main integration was extended through purchase/loading of a second 1 000 L
  batch: exactly 300 kr is deducted, product disposal leaves source crude
  untouched, and a fresh headless main launch still succeeds.

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
- Fixed the minimum-objective economy soft-lock with a guaranteed pilot
  contract payout.
- Fixed the off-spec and accumulated byproduct soft-lock with safe product
  disposal and full product dispatch on successful sale.
- Fixed pumps staying logically active after a live pipe was disconnected.
- Fixed unrelated/spare pumps and pipes falsely appearing active.
- Fixed LAB / SALG remaining green because of already-sold pilot diesel.
- Fixed guidance that told the player to start an empty/cold built line before
  loading and heating it.
- Fixed outdated post-unlock R help and build-panel/UI overlap.

## Current Stable State

- Version 0.4 preserves the 0.3 pilot loop and its model tests pass.
- Visual building still works, now with readable direction before placement.
- A player can construct and validate the complete logical topology
  tank → pump → heater → column → three product tanks, run a complete batch,
  inspect live state, and sell approved diesel.

## Known Issues

### Confirmed bugs

- No newly introduced critical bug is confirmed after the final automated
  regression pass.

### Untested behavior

- The exact mouse aiming feel and readability of the three closely spaced
  column outlets still need a hands-on editor playtest.

### Future improvements

- Improve port hit targets or add target cycling if manual playtesting finds
  the column outlets too difficult to select.
- Consider routed pipe elbows and dedicated light/heavy sale values after the
  greybox vertical slice is proven fun.

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
- `tests/main_built_loop_test.gd`: unlock-to-sale integration and exploit
  regression coverage through Main.
- `README.md` and `project.godot`: version 0.4 instructions and metadata.

## Next Best Work

- Perform a hands-on 1280×720 playtest of the full physical interaction path,
  focusing on column-port aiming and pipe readability. If it feels good, the
  next development slice should be small usability polish rather than another
  refinery tier.
