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
2. **Manual valve and low-flow troubleshooting** — add one understandable
   operating fault and a recovery task without complex fluid physics.
3. **Persistent player refinery** — save and restore construction, connections,
   process inventory, economy, and progression safely.
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
- Milestone 2 completed:
  - Added a required player-built manual valve between the pump and heater.
  - Added a closed-by-default red/perpendicular valve handle which turns
    green/parallel when opened, with matching contextual prompt and status.
  - Added valve-aware topology validation, seven active route segments, and a
    clear rejection when the player tries to bypass the valve.
  - Added a real `LOW FLOW` troubleshooting state: the pump remains on, flow
    and transfer stay at zero, and opening the correct route valve resumes the
    same mass-conserving process.
  - Routed Area 02 alarms through the existing red alarm display and kept
    simultaneous high-temperature safety information visible.
  - Raised the minimum pilot contract to 3 000 kr so the required 2 600 kr
    starter refinery still leaves enough for one paid recovery batch.
  - Kept the original pilot plant behavior and interaction sequence unchanged.

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
- Final Milestone 2 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 77 checks passed;
  - Main integration: 33 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.

## Bugs Found

- Area 02 has no persistent completion state or batch result after a valid sale.
- Process alarms inspect every placed heater rather than the active route only.
- Spare columns glow when another route is flowing.
- A diesel tank can glow ready below the 200 L acceptance quantity.
- Product disposal is a destructive single-key action without confirmation.
- Multiple complete routes validate although only the first route operates.
- Physical 1280 x 720 port aiming and real input timing still need hands-on QA.
- Requiring the valve initially left only 200 kr after minimum pilot funding,
  which could soft-lock a player after an off-spec free batch.
- Area 02 process alarms were present in summary text but not in the prominent
  red alarm display.
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
- Fixed the recovery-batch economy soft-lock after constructing the required
  valve-inclusive refinery.
- Fixed built `LOW FLOW` and `HIGH TEMPERATURE` alarms being visually muted or
  one condition hiding the other.

## Current Stable State

- Version 0.5.0 is verified stable after Milestone 2.
- The original pilot loop and full player-built loop both pass regression.
- The first valid Area 02 sale now has a durable achievement and informative
  result, while later paid batches remain repeatable.
- The complete built process now teaches the intended sequence directly:
  tank → pump → valve → heater → distillation → product tanks.

## Known Issues

- Multi-route operation is intentionally not part of the first vertical slice,
  but the limitation needs clearer feedback before multiple lines are exposed.
- Hands-on aiming/interaction feel remains unverified by headless automation.
- Valve handle readability and central alarm prominence still need a hands-on
  check at the target 1280 x 720 window size.
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
- After Milestone 1, the manual valve moved ahead of persistence because it
  completes the core tank–pump–valve–heater learning chain and creates the first
  player-readable troubleshooting event with little architectural risk.

## Next Best Action

- Implement a small versioned save format for construction, topology, process
  state, economy, and progression without changing simulation ownership or
  destabilizing the now-complete manual refinery loop.
