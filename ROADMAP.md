# CrudeWorks Roadmap

## Current stable baseline

Version 0.17 has a tested pilot plant and multiple independent player-built
Area 02 refinery trains. The built loop covers construction, directed pipes, valve troubleshooting,
Sour-diesel treatment, physical diesel sampling, LAB-101, LS-201, 5/10/15 L/s
pump targets and separate Naphtha/heavy-residue deliveries.

One source can now physically feed two complete trains through a buildable
Crude Feed Header. Feed allocation keeps an explicit player-selected branch;
it never auto-splits or falls back to another train.

One column or HT-201 product output can now physically feed two compatible
storage tanks through a Product Routing Header. Product allocation keeps one
explicit selected destination; it never blends, splits or auto-switches.

## Current priority

**Hands-on 1280 x 720 usability pass.** Verify port aiming, valve readability,
alarm visibility, treatment readability, product-delivery modal layout and
terminal feedback in the running game.
Headless tests cannot replace this check.

## Next milestones

1. Hands-on 1280 x 720 interaction pass: verify port aiming, valve readability,
   alarm visibility and modal layout in the running game.
2. Playtest both header types, tank-capacity feedback and multi-train
   product-value balance before expanding into broader manifolds.
3. Consider the next constrained routing decision only after the header's
   manual selection and source ownership are proven understandable in play.

## Task context rules

- Read `AGENTS.md` for every implementation task.
- Read this file for normal roadmap work.
- Read `ARCHITECTURE.md` before touching a cross-system integration.
- Read `CRUDEWORKS_VISION.md` only for design or roadmap decisions.
- Read development logs for audits, historical investigation or unresolved
  regressions.
