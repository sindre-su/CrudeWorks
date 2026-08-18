# CrudeWorks Development Log

## Session Review

- Inherited version 0.4 at checkpoint `0676b80`.
- The pilot loop and the complete player-built refinery loop are both present.
- Verified all five automated suites and a headless main-scene launch with Godot 4.7.1.
- Confirmed that the process network is the single topology authority and the
  built refinery model owns operating state by stable string IDs.
- The worktree began with three untracked Godot UID sidecars for files added
  overnight; no gameplay source changes were present.
- The largest current gameplay gap is the lack of durable completion and useful
  result feedback after the first successful Area 02 sale.

## Current Roadmap

1. **Area 02 commissioning contract and batch report** — make the first built
   sale a clear achievement, explain yield/quality/economy, make product
   disposal safe, and correct route-unaware feedback.
2. **Persistent player refinery** — save and restore construction, connections,
   process inventory, economy, and progression safely.
3. **Manual valve and low-flow troubleshooting** — add one understandable
   operating fault and a recovery task without complex fluid physics.
4. **Crude and laboratory contracts** — add a small number of meaningful feed
   choices and quality targets that vary the repeat loop.
5. **Starter instrumentation and automation** — introduce useful measurements
   and limited remote control after manual operation is proven.

## Completed Work

- Phase 1 repository, architecture, gameplay, QA, test, scene, and economy
  review completed without changing implementation code.
- Milestone 1 completed:
  - Added persistent Area 02 commissioning completion on the first approved
    built-refinery sale.
  - Added a pre-dispatch batch snapshot with actual crude processed, all three
    fraction volumes, volume-weighted diesel quality, average process
    temperature, revenue, proportional crude cost, and net result.
  - Added a readable 1280 x 720 report overlay which locks movement,
    interaction, and build controls until Enter or Escape dismisses it.
  - Added dynamic Area 02 guidance and an explicitly voluntary 95 percent
    quality challenge after commissioning.
  - Added revision-bound, four-second, two-step confirmation before product
    disposal; active production must be stopped first.
  - Scoped diesel readiness, sales, report inventory, temperature alarms, and
    column activity to the active process route.
  - Corrected the built pump so a second interaction actually stops it.
  - Updated player terminology from `commissioning batch` to `oppstartsbatch`.

## Validation

- Pilot/economy suite: passed.
- Process-network suite: passed.
- Building-system suite: passed.
- Built-refinery model suite: passed.
- Main integration suite: passed.
- Main scene: started headlessly without parser, resource, or runtime errors.
- No Codex app terminal session was available; Godot CLI output was used.
- Final Milestone 1 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 50 checks passed;
  - building system: 34 checks passed;
  - built refinery: 64 checks passed;
  - Main integration: 29 checks passed;
  - main scene and full headless editor/resource scan passed.

## Bugs Found

- Area 02 has no persistent completion state or batch result after a valid sale.
- Process alarms inspect every placed heater rather than the active route only.
- Spare columns glow when another route is flowing.
- A diesel tank can glow ready below the 200 L acceptance quantity.
- Product disposal is a destructive single-key action without confirmation.
- Multiple complete routes validate although only the first route operates.
- Physical 1280 x 720 port aiming and real input timing still need hands-on QA.
- A concurrent parallel Godot run collided over the engine log and crashed;
  all authoritative validation was rerun sequentially with isolated log files
  and passed.

## Bugs Fixed

- Fixed manual built-pump stop doing nothing.
- Fixed disconnected hot/cold heaters creating false alarms for the active line.
- Fixed spare columns glowing when another line was flowing.
- Fixed tiny high-quality diesel volumes looking sale-ready before 200 L.
- Fixed disconnected legacy diesel influencing active-line readiness and sale.
- Fixed Area 02 remaining permanently unfinished after an approved sale.
- Fixed single-key destruction of approved or off-spec product inventory.

## Current Stable State

- Version 0.4.1 is verified stable after Milestone 1.
- The original pilot loop and full player-built loop both pass regression.
- The first valid Area 02 sale now has a durable achievement and informative
  result, while later paid batches remain repeatable.

## Known Issues

- Multi-route operation is intentionally not part of the first vertical slice,
  but the limitation needs clearer feedback before multiple lines are exposed.
- Hands-on aiming/interaction feel remains unverified by headless automation.
- Report accounting covers material processed since the previous sale or
  disposal. After an early partial sale, the next report covers only the
  remaining material processed afterward and its proportional crude cost.

## Roadmap Changes

- The overnight log suggested small port polish next. Current review showed that
  player motivation and closure after the built sale are higher value, so the
  first milestone is now the Area 02 commissioning result.
- Architecture review found the proposed 95 percent follow-up was not an
  enforceable contract. It is now explicitly labelled as a voluntary challenge
  and the normal load/heat/pump/deliver guidance remains active.

## Next Best Action

- Reassess whether persistence remains the next highest-value milestone, then
  implement a small versioned save format for construction, topology, process
  state, economy, and progression without changing simulation ownership.
