# CrudeWorks Roadmap

## Current stable baseline

Version 0.15 has a tested pilot plant and multiple independent player-built
Area 02 refinery trains. The built loop covers construction, directed pipes, valve troubleshooting,
Sour-diesel treatment, physical diesel sampling, LAB-101, LS-201, 5/10/15 L/s
pump targets and separate Naphtha/heavy-residue deliveries.

The shared-source foundation can now discover multiple complete eligible trains
from one source without relying on route order. Feed allocation keeps an
explicit selected train, but no physical header/manifold or player-facing
selection control exists yet.

## Current priority

**Hands-on 1280 x 720 usability pass.** Verify port aiming, valve readability,
alarm visibility, treatment readability, product-delivery modal layout and
terminal feedback in the running game.
Headless tests cannot replace this check.

## Next milestones

1. Hands-on 1280 x 720 interaction pass: verify port aiming, valve readability,
   alarm visibility and modal layout in the running game.
2. Design and playtest a physical shared-source header that uses the existing
   feed-allocation foundation; do not add arbitrary branching or auto-routing.
3. Playtest multi-train product-value balance and storage pressure before
   expanding into broader manifolds.

## Task context rules

- Read `AGENTS.md` for every implementation task.
- Read this file for normal roadmap work.
- Read `ARCHITECTURE.md` before touching a cross-system integration.
- Read `CRUDEWORKS_VISION.md` only for design or roadmap decisions.
- Read development logs for audits, historical investigation or unresolved
  regressions.
