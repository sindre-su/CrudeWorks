# CrudeWorks Roadmap

## Current stable baseline

Version 0.11 has a tested pilot plant and one player-built Area 02 refinery
line. The built loop covers construction, directed pipes, valve troubleshooting,
Standard/Heavy deliveries, physical diesel sampling, LAB-101, LS-201 and
5/10/15 L/s pump targets.

## Current priority

**Recoverable maintenance fault.** Add one understandable fault that uses the
existing LOW FLOW, tank, valve and LS-201 feedback. Keep the pilot plant and
current process/economy rules stable.

## Next milestones

1. Hands-on 1280 x 720 interaction pass: verify port aiming, valve readability,
   alarm visibility and modal layout in the running game.
2. One recoverable maintenance fault: diagnose and recover with existing process
   feedback; add focused regression tests.
3. Sour crude plus one meaningful treatment decision, only if the maintenance
   slice is stable and enjoyable.
4. Product-value expansion after delivery orders and storage choices have been
   playtested.

## Task context rules

- Read `AGENTS.md` for every implementation task.
- Read this file for normal roadmap work.
- Read `ARCHITECTURE.md` before touching a cross-system integration.
- Read `CRUDEWORKS_VISION.md` only for design or roadmap decisions.
- Read development logs for audits, historical investigation or unresolved
  regressions.
