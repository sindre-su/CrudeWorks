# CrudeWorks Roadmap

## Current baseline

Version 0.24.4 has a tested pilot plant and a substantial Area 02 refinery
slice: free building, directed process networks, multiple independent trains,
shared-feed/product routing, Standard/Heavy/Sour crude, diesel treatment,
quality/LAB dispatch, VDU-301, FCC-401, electrical capacity, controls, alarms,
pump condition/filter repair, economy and validated save/load.

The core conclusion is deliberate: **process depth is no longer the primary
bottleneck.** Further process-unit expansion is lower priority until existing
systems feel physical, understandable, rewarding and scalable in real play.

## Current priority

**Hands-on 1280 × 720 usability and game-feel pass.** Validate port aiming,
pipe/valve readability, equipment interaction, alarms, tank levels, LAB-101,
LS-201, power feedback, VDU/FCC placement and pump-condition pacing in the
running game. Headless tests protect logic; they cannot replace human play.

## Development phases

### Phase A — Foundation

Mostly complete: pilot loop, free building, directed topology, atmospheric
distillation, material conservation, economy, progression gate and save/load.

### Phase B — Refinery depth

Largely established: multiple trains, feed/product routing, Sour treatment,
quality/LAB, storage choices, VDU/FCC secondary processing and electrical
capacity. Add another major unit only when it unlocks a clear new player
decision rather than extending a machine checklist.

### Phase C — Make the refinery feel alive

High priority now. Choose small, tested improvements such as:

- physical process animation, readable tank level and local status cues;
- clearer pipe, port, valve, pump and alarm feedback;
- sound/status feedback that makes operation legible and satisfying;
- hands-on building and interaction improvements;
- condition/maintenance pacing and visible recovery.

### Phase D — Progression and game loop

High priority. Strengthen the first 20 minutes, the first 45–90 minute session,
and the reasons to keep expanding:

- compelling pilot-to-Area-02 transition;
- equipment/economy unlock pacing and reinvestment choices;
- storage, power, maintenance and layout as expansion decisions;
- clearer medium-term goals that are not simply "buy the next machine";
- scenario/save-preset foundations only when they reuse normal sandbox systems.

### Phase E — Quality and operations

Later depth: broader specifications, quality-dependent value, blending, richer
operator diagnosis and carefully expanded maintenance. Each addition must
produce a visible process decision or recovery path.

### Phase F — Automation and scale

Later progression: additional instruments, earned remote control, controlled
routing, scalable monitoring and simple automation. Automation must reduce a
manual task the player already understands; it must not turn CrudeWorks into an
idle game.

### Phase G — Large integrated refinery

Long-term focus: integration, reliability, throughput, quality, profitability,
utilities, tank farms and player-designed layouts—not the raw number of units.

## Play-scale guardrails

- **Micro session (~20 min):** one concept can be demonstrated quickly through
  normal physical systems, eventually supported by scenario/preset loading.
- **Standard session (45–90 min):** pilot → build → operate → diagnose →
  reinvest forms a coherent session arc.
- **Sandbox (hours):** the same pumps, tanks, routing and maintenance systems
  gain depth as the refinery grows.

## Decision rule

After every meaningful milestone, **reassess**. Do not blindly implement the
next listed idea. Ask: *what currently prevents CrudeWorks from becoming a more
fun, physical refinery-builder game?* Choose the smallest change that removes
that bottleneck and preserves both short-session usefulness and long-form value.

## Architecture guardrails

- `ProcessNetwork` remains the sole topology authority.
- `BuiltRefineryModel` remains the Area 02 material/operation authority.
- Keep material transfers capacity-bounded, product identity-preserving and
  mass-conserving.
- Reuse manual interaction before adding remote/automatic control.
- Do not introduce process physics, utilities or new units without a clear
  player-facing decision.

## Deferred work

- Human playtesting at 1280 × 720, including expanded Area 02 layout.
- Economy balancing for multi-train, VDU/FCC, electricity and maintenance.
- Larger storage/manifolds, advanced automation, pressure/energy systems,
  logistics and additional process families only after a demonstrated gameplay
  need.
