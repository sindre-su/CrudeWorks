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

## Bugs Found and Fixed

- Fixed unreadable placement orientation. The ghost previously created only an
  equipment body; it now uses the same catalog-backed port offsets as placed
  equipment so preview and final orientation cannot drift apart.

## Current Stable State

- The 0.3 pilot loop remains unchanged and its model tests pass.
- Visual building still works, now with readable direction before placement.

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

## Next Best Work

- Establish a tested lightweight process network and player-readable
  connection validation without changing the pilot model.
