# CrudeWorks Roadmap

## Current stable baseline

Version 0.24.0 has a tested pilot plant and multiple independent player-built
Area 02 refinery trains. The built loop covers construction, directed pipes, valve troubleshooting,
Sour-diesel treatment, physical diesel sampling, LAB-101, LS-201, 5/10/15 L/s
pump targets and separate Naphtha/heavy-residue deliveries.

Every built pump now carries a persistent condition value. Condition wears only
when material moves, with a modest extra penalty at high flow targets; local
field status exposes GOOD/WORN/POOR state, while stopped pumps can receive
paid preventive maintenance. This remains separate from the inspectable,
recoverable blocked-filter fault.

The v0.21 architectural foundation tags every discovered atmospheric route
explicitly. Its small route-envelope API separates shared identity/ownership
lookups from atmospheric-only consumers, so a future secondary process family
can be introduced without making the current LS-201, alarms, feed headers,
product routing or simulation assume its equipment fields.

One source can now physically feed two complete trains through a buildable
Crude Feed Header. Feed allocation keeps an explicit player-selected branch;
it never auto-splits or falls back to another train.

One column or HT-201 product output can now physically feed two compatible
storage tanks through a Product Routing Header. Product allocation keeps one
explicit selected destination; it never blends, splits or auto-switches.

Each built heater now keeps one authoritative PV/SP/output state. After
commissioning, TIC-201 AUTO adjusts that existing heater output independently
per train; the manual valve and all existing safety behavior remain authoritative.

LS-201 now derives per-train operator alarms from actual process state. LOW
FLOW, HIGH TEMPERATURE, HIGH LEVEL and TANK FULL identify where to inspect;
they do not expose the maintenance diagnosis automatically.

LS-201 Refinery Operations discovers every complete train from the same model
state, provides an overview plus selected-train detail, and routes limited pump,
temperature and flow commands through existing safety-checked APIs.

Area 02 now has a small refinery-wide electrical-capacity layer. The starter
utility provides 100 kW; buildable PU-101 Power Units add 100 kW each. Pumps,
HT-201 and the VDU auxiliary load consume capacity only while operating, so new
starts are rejected safely when the available capacity is insufficient.

FCC-401 is the first VGO upgrading route: a typed VGO tank → pump → FCC route
atomically produces Gasoline Blendstock, LPG and Light Cycle Oil. It remains
separate from atmospheric control systems and the VDU route, while using the
same tank intent, material identity, electrical capacity and save/load rules.

Area 02 construction space is now approximately twice its original footprint.
The original pilot plant and starter positions remain unchanged; the added pad
space supports larger layouts without introducing a new process system.

## Current priority

**Hands-on 1280 x 720 usability pass.** Verify VDU, FCC-401 and PU-101 placement,
build-menu readability, valve readability, power feedback, the expanded Area 02
boundary and terminal layout in the running game. Headless tests cannot replace
this check.

## Architecture preparation

- Keep `ProcessNetwork` route discovery additive. Atmospheric distillation is
  executable today; v0.21C also discovers a structural vacuum route using
  explicit tank intent: Heavy Residue source → pump → VDU → VGO and Vacuum
  Residue storage.
- Keep FeedAllocation, Crude Feed Header, Product Routing Header, LAB-101,
  operator alarms and LS-201 explicitly atmospheric until an additional
  process family supplies its own routing and operating semantics.
- VDU-301 is now build-menu item 9. Its feed pump is the sole field control,
  while its typed outlets establish empty VGO/Vacuum Residue tank intent and
  use the existing atomic 60/40 transfer. It must not inherit atmospheric
  valve, heater, column, quality or LAB assumptions.
- FCC-401 is build-menu item `-`. Its VGO feed pump is the sole field control;
  it requires three typed product tanks and atomically applies the fixed
  55/25/20 Gasoline Blendstock/LPG/LCO split. Its 40 kW auxiliary load is
  added to the running feed pump's normal 25 kW demand.

## Next milestones

1. Hands-on 1280 x 720 interaction pass: verify port aiming, PU-101 placement,
   valve readability, alarm visibility and modal layout in the running game.
2. Playtest both header types, TIC-201/alarm readability and multi-train
   product-value balance before expanding into broader manifolds.
3. Consider the next constrained routing decision only after the header's
   manual selection and source ownership are proven understandable in play.
4. Playtest the VDU → FCC capital chain, product values and 65 kW FCC load
   before adding more secondary units, product headers or automation.
5. Playtest pump condition pacing, the 75 kr preventive-service cost and the
   physical distinction between worn capacity and the blocked-filter fault.

## Task context rules

- Read `AGENTS.md` for every implementation task.
- Read this file for normal roadmap work.
- Read `ARCHITECTURE.md` before touching a cross-system integration.
- Read `CRUDEWORKS_VISION.md` only for design or roadmap decisions.
- Read development logs for audits, historical investigation or unresolved
  regressions.
