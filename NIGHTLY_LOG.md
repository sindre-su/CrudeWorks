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

- Baseline inspection completed. No gameplay changes made yet.

## Validation Performed

- Full project scene started headlessly in Godot 4.7.1 without parser or
  runtime errors.
- Existing process/economy suite: 22 checks passed.
- Existing building-system suite: 18 checks passed.

## Bugs Found and Fixed

- No fixes yet. Confirmed that preview ports are absent because the ghost only
  creates the equipment body; ProcessPort nodes are created after placement.

## Current Stable State

- Confirmed stable 0.3 baseline. Pilot plant and visual building system work.

## Known Issues

### Confirmed bugs

- IN/OUT orientation cannot be read from the placement preview.
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

## Next Best Work

- Add readable IN/OUT orientation to the placement preview, then establish a
  tested lightweight process network without changing the pilot model.

