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

1. **Resilient commissioning retries** — remove the progression softlock after
   repeated off-spec learning attempts without granting free value later.
2. **Physical diesel sampling** — take a revision-bound sample, analyze it at
   LAB / SALG, and require a valid result before paid-batch dispatch.
3. **Explicit single active route** — make the current one-line limitation
   understandable before players invest in a second unusable process line.
4. **Delivery-order variety** — give multiple fractions and crude choices
   distinct order goals rather than one repeated diesel objective.
5. **First flow/capacity choice** — add one controllable throughput tradeoff
   with a clear quality consequence after sampling makes quality playable.

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
- Milestone 3 completed:
  - Added one versioned local JSON autosave for pilot state, economy,
    progression, player transform, construction, directed topology, process
    inventory, controls, commissioning state, and batch-report accumulators.
  - Added a single Continue/New Game startup choice. New Game requires a second
    confirmation and archives the previous primary, backup, and corrupt file.
  - Added whitelist validation for every persisted section before live state is
    touched, including bounds/overlap, unit IDs, serials, port direction,
    process order, cycles, tank capacities, quality, money, and mass-balanced
    report data.
  - Rebuilt loaded connections through the existing authoritative
    `ProcessNetwork` rules and recreated all seven visual pipes from the same
    directed endpoints.
  - Restored partial-batch volume, temperature, quality, proportional crude
    cost and report tracking while always forcing pumps and derived flow off.
  - Added temporary-file replacement, one last-known-good backup, corrupt-file
    preservation and explicit feedback when an older backup is recovered.
  - Kept routine autosaves silent so process and troubleshooting messages are
    not overwritten; write failures remain prominent.
- Milestone 4 completed:
  - Added a small data-driven raw-oil contract catalog with Standard and Heavy
    feeds while preserving the pilot plant and the established Standard curve.
  - Added a modal post-commissioning delivery choice. Standard costs 300 kr and
    targets 200 °C; Heavy costs 180 kr, targets 230 °C, yields more residue and
    offers one 1 000 kr bonus for an approved delivery.
  - Locked process yield, quality, sale requirements and payout to the loaded
    batch so a cheaper feed cannot be changed into a higher-paying contract.
  - Blocked new contracts while any built tank contains process material or a
    pump is commanded on, including material disconnected from the active route.
  - Made alarms, objectives, tank inspection, readiness and batch reports use
    the active feed's temperature and quality requirements.
  - Upgraded persistence to format 2 and added strict format-1 migration to a
    Standard contract without a free batch or retroactive delivery bonus.
- Milestone 5 completed:
  - Added the fixed LS-201 local control station on the west side of Area 02,
    unlocked only after the player completes the refinery manually once.
  - Added active-route telemetry for source level, heater temperature and
    target, actual flow, product levels, pump command and manual-valve state.
  - Added remote start/stop for the active-route pump and remote cycling of the
    existing heater target without introducing a second process-state owner.
  - Added a remote-start temperature permissive and trip which uses the loaded
    Standard or Heavy contract range and stops before unsafe material transfer.
  - Kept field-start behavior unchanged and the manual valve field-only, so
    closed-valve LOW FLOW remains an intentional troubleshooting lesson.
  - Added a live modal panel, truthful idle/guard/alarm feedback, save-safe
    transient state, and an explicit unlock location in the batch report.
- Post-roadmap recovery fix completed:
  - Confirmed a real softlock after two failed commissioning batches left the
    player with only 100 kr and no affordable crude or refundable escape.
  - Restored the free Standard commissioning entitlement only after a failed
    pre-commission batch is completely and safely discarded.
  - Allowed repeated learning attempts, including across save/load, while the
    first approved sale permanently ends the subsidy and keeps later Standard
    and Heavy deliveries paid.

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
- Final Milestone 3 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 77 checks passed;
  - Main integration: 33 checks passed;
  - save system: 37 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Milestone 4 focused validation:
  - Standard at 200 °C retained 300/350/350 L output and 2 800 kr revenue;
  - Heavy at 230 °C produced 150/220/630 L at 100 percent quality and paid
    1 760 kr plus one 1 000 kr bonus;
  - Heavy at 200 °C produced only 180 L diesel at 64 percent quality and was
    rejected without consuming inventory or its pending bonus;
  - contract switching, repeated purchase/sale, disconnected inventory and
    v1-to-v2 migration received focused regression coverage.
- Final Milestone 4 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 100 checks passed;
  - Main integration: 41 checks passed;
  - save system: 45 checks passed;
  - main scene and full headless editor/resource scan passed with no logged
    parser, resource, runtime, or script errors.
- Milestone 5 focused validation:
  - LS-201 telemetry matched exact route state before, during and after flow;
  - a closed manual valve held flow and mass at zero after remote pump start;
  - remote temperature protection blocked cold starts and tripped before an
    out-of-range tick could transfer material;
  - spare equipment and invalid topology could not be controlled remotely;
  - the live panel blocked field/build input and preserved modal state as
    transient across saves.
- Recovery softlock validation:
  - three consecutive cold commissioning batches were rejected and safely
    discarded without revenue, bonus, or retained material;
  - every failed attempt restored exactly one free Standard retry;
  - the retry entitlement survived save/load;
  - the first approved retry completed commissioning once, and the following
    Standard batch again charged exactly 300 kr.
- Final Milestone 5 regression with isolated log files:
  - pilot/economy: 23 checks passed;
  - process network: 59 checks passed;
  - building system: 41 checks passed;
  - built refinery: 116 checks passed;
  - Main integration: 53 checks passed;
  - save system: 46 checks passed;
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
- Initial persistence integration could partially mutate state if applied over
  an already populated refinery.
- Autosave confirmation reused the process notification and could hide useful
  LOW FLOW feedback.
- Backup recovery was technically successful but invisible to the player.
- An unbounded saved build counter could make the next generated save invalid.
- A concurrent parallel Godot run collided over the engine log and crashed;
  all authoritative validation was rerun sequentially with isolated log files
  and passed.
- The repeatable refinery had one fixed Standard feed and one 200 °C solution,
  so post-commissioning play did not require process adaptation.
- Early contract UI drafts could describe an overheated Heavy batch as ready,
  advertise a new purchase while old products remained, or show a fictitious
  0 °C process average before any production.
- Early LS-201 feedback showed a fictitious 0 °C target while idle and let a
  stale successful command hide a later LOW FLOW alarm.
- Two failed commissioning attempts could leave only 100 kr and permanently
  strand the player without crude, income, or enough refundable value.

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
- Restricted save restoration to the pristine startup scene, added rollback
  for unexpected construction failures, and tested repeated-load atomicity.
- Made routine autosave silent and preserved operational notifications.
- Added explicit last-known-good recovery feedback and canonical serial bounds.
- Added batch-locked Standard/Heavy provenance, exact single-charge/single-bonus
  transactions and material-empty switching rules across disconnected tanks.
- Made high/low temperature guidance, source prompts, empty-process sales and
  report-dismiss messages agree with the actual contract and inventory state.
- Made LS-201 idle state, remote-guard mode and alarm priority agree with the
  active batch and actual process condition.
- Made pre-commission learning retries repeatably subsidized only after all
  failed material is safely removed; approved commissioning ends the subsidy.

## Current Stable State

- Version 0.8.1 is verified stable after the commissioning-recovery fix.
- The original pilot loop and full player-built loop both pass regression.
- The first valid Area 02 sale now has a durable achievement and informative
  result, while later paid batches remain repeatable.
- The complete built process now teaches the intended sequence directly:
  tank → pump → valve → heater → distillation → product tanks.
- A player can now leave during a partial paid batch and safely continue with
  the same mass, process conditions, economy and construction on next launch.
- After commissioning, the same refinery now supports two economically and
  operationally distinct feed choices instead of repeating one 200 °C recipe.
- After proving manual operation, the player can monitor the active route from
  LS-201 and use limited remote control with a feed-aware temperature trip,
  while still walking into the plant to operate and troubleshoot the valve.
- Repeated off-spec commissioning mistakes no longer force a new game; the
  player can continue learning without creating post-commission free batches.

## Known Issues

- Multi-route operation is intentionally not part of the first vertical slice,
  but the limitation needs clearer feedback before multiple lines are exposed.
- Hands-on aiming/interaction feel remains unverified by headless automation.
- Valve handle readability and central alarm prominence still need a hands-on
  check at the target 1280 x 720 window size.
- Report accounting covers material processed since the previous sale or
  disposal. After an early partial sale, the next report covers only the
  remaining material processed afterward and its proportional crude cost.
- Save format 1 is migrated explicitly to Standard; unknown older or future
  versions are still preserved and rejected rather than guessed.

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
- Persistence stayed deliberately local and single-slot. Cloud sync, multiple
  profiles and offline production would add complexity without improving the
  current refinery learning loop.
- Crude variety was limited to Standard and Heavy. Sour crude remains deferred
  because it would be a label without meaningful treatment equipment today.
- The completed five-milestone roadmap was reassessed from the actual 0.8.0
  loop. A QA-discovered commissioning softlock moved ahead of the planned lab
  milestone; the next content focus is now physical diesel sampling.

## Next Best Action

- Add the small paid-batch laboratory loop: take a diesel sample at the active
  product tank, analyze it at LAB / SALG, and require a current approved result
  before dispatch. Keep the sample transient and revision-bound so save/load or
  new production can never reuse stale authorization.
