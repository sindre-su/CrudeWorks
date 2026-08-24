# CrudeWorks Roadmap

## Current stable baseline

Version 0.21 has a tested pilot plant and multiple independent player-built
Area 02 refinery trains. The built loop covers construction, directed pipes, valve troubleshooting,
Sour-diesel treatment, physical diesel sampling, LAB-101, LS-201, 5/10/15 L/s
pump targets and separate Naphtha/heavy-residue deliveries.

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

## Current priority

**Hands-on 1280 x 720 usability pass.** Verify VDU port aiming, the ninth
build-menu slot, valve readability, secondary-product delivery layout and
terminal feedback in the running game. Headless tests cannot replace this
check.

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

## Next milestones

1. Hands-on 1280 x 720 interaction pass: verify port aiming, valve readability,
   alarm visibility and modal layout in the running game.
2. Playtest both header types, TIC-201/alarm readability and multi-train
   product-value balance before expanding into broader manifolds.
3. Consider the next constrained routing decision only after the header's
   manual selection and source ownership are proven understandable in play.
4. Playtest VDU capital cost and VGO/Vacuum Residue value before adding more
   secondary units, product headers or automation.

## Task context rules

- Read `AGENTS.md` for every implementation task.
- Read this file for normal roadmap work.
- Read `ARCHITECTURE.md` before touching a cross-system integration.
- Read `CRUDEWORKS_VISION.md` only for design or roadmap decisions.
- Read development logs for audits, historical investigation or unresolved
  regressions.
