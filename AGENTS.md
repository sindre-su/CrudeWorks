# AGENTS.md — CrudeWorks

## Project overview

CrudeWorks is a 3D educational refinery game built in Godot.

The game is inspired by games such as Hydroneer: the player starts with a small, simple industrial setup and gradually unlocks more advanced equipment, larger areas, better crude oil inputs, automation, laboratory systems and more complex refinery processes.

The target audience is students in Norwegian upper-secondary education, especially Kjemi, prosess og laboratoriefag (VG2).

The game must be:
1. Fun enough that students actually want to play it.
2. Simple enough that a beginner developer can maintain it with AI assistance.
3. Educational through gameplay rather than long quizzes or walls of text.
4. Technically modular enough to expand over time.

---

# Core design principle

DO NOT build a highly realistic refinery simulator.

Build a simplified refinery game that teaches correct basic relationships.

The player should learn by operating the plant:

Tank -> Pump -> Valve -> Heater -> Process -> Product

The player should understand concepts such as:
- flow
- level
- temperature
- pressure
- tanks
- pumps
- valves
- pipes
- heating
- distillation
- product quality
- alarms
- troubleshooting
- laboratory testing
- basic process control
- HMS / safety

Gameplay comes first. Education should be embedded in gameplay.

Avoid quiz-style learning unless specifically requested.

---

# Development philosophy

The owner of this project does not have a professional game-development background.

Therefore:

- Prefer simple solutions over clever solutions.
- Prefer readable GDScript over complex abstractions.
- Avoid unnecessary design patterns.
- Avoid premature optimization.
- Do not introduce external dependencies unless they clearly solve a real problem.
- Do not refactor working systems without a concrete reason.
- Do not replace an existing architecture merely because another architecture is theoretically cleaner.
- Make one meaningful change at a time.
- Keep features small and testable.
- Preserve existing gameplay unless the task explicitly requires changing it.

When multiple solutions are possible, choose the one that is easiest for a beginner to understand and maintain.

---

# Godot rules

Use GDScript unless the existing project clearly uses another language for a specific reason.

Follow the Godot version configured in project.godot.

Never assume an API exists. When uncertain, verify against the Godot version being used.

Prefer:
- scenes for reusable game objects
- scripts with one clear responsibility
- signals for communication between loosely coupled systems
- exported variables for values that should be tunable in the Godot Inspector
- Resources for reusable data definitions when appropriate

Avoid:
- huge single scripts
- deeply nested inheritance
- global singletons for everything
- hard-coded node paths where a cleaner exported reference is possible
- magic numbers scattered throughout scripts

---

# Folder structure

Respect the existing project structure.

If the project does not yet have a clear structure, prefer something similar to:

res://
  scenes/
    player/
    world/
    machines/
    refinery/
    ui/
  scripts/
    core/
    machines/
    fluids/
    refinery/
    ui/
  resources/
    crude_oils/
    products/
    machines/
  assets/
    models/
    textures/
    audio/
  data/
  tests/

Do not reorganize the entire repository unless explicitly asked.

---

# Core gameplay architecture

CrudeWorks should be built from small modular systems.

Important object types may include:

## Tank

A Tank should initially only need concepts such as:
- capacity
- current volume
- fluid/product type
- temperature

Add more properties only when gameplay actually requires them.

Possible later properties:
- pressure
- composition
- contamination
- level transmitter

Do not implement these early unless needed.

## Pump

A Pump should initially support:
- on/off
- maximum flow
- actual flow
- source
- destination

Possible later systems:
- power consumption
- efficiency
- cavitation
- wear
- failure state

Do not simulate advanced pump physics unless specifically needed.

## Valve

A Valve should initially support:
- open/closed
or
- 0–100% opening

It should affect flow in a predictable and understandable way.

## Pipe

Pipes should primarily provide connectivity.

Do not build advanced fluid dynamics.

The player should be able to understand:
"this pipe connects this machine to that machine."

## Heater

A Heater should initially:
- accept fluid
- increase fluid temperature
- have a maximum heating rate
- consume simplified energy if required

## Distillation unit

The first distillation system should be intentionally simplified.

Input:
- crude oil
- temperature / process conditions

Output examples:
- light fraction
- middle fraction
- heavy fraction

Later versions can introduce:
- LPG
- naphtha
- kerosene
- gas oil / diesel fraction
- residue

Do not implement a rigorous chemical thermodynamics model unless explicitly requested.

---

# Crude oil system

Crude oils should be data-driven when practical.

A crude-oil definition may eventually include:
- display name
- purchase price
- difficulty
- light fraction yield
- middle fraction yield
- heavy fraction yield
- sulfur level
- quality

Early game example:

Starter Crude
- forgiving
- easy to process
- clear separation
- low penalty for imperfect operation

Later crude types can include:

Light Sweet
- expensive
- higher valuable-product yield
- easier processing

Heavy Crude
- cheaper
- more residue
- requires better equipment

Sour Crude
- more sulfur
- requires additional treatment

Do not add many crude types before the basic refinery loop works.

---

# Product system

Products should also be data-driven when practical.

Each product may eventually have:
- name
- value
- quality
- storage requirements
- acceptable specification range

Examples:
- LPG
- naphtha
- kerosene
- diesel
- heavy fuel / residue

Early versions may use only:
- light fraction
- middle fraction
- heavy fraction

---

# Progression system

The game progresses in tiers.

The progression should feel physical and visible.

Suggested direction:

## Tier 1 — Pilot Plant
Teach:
- tanks
- pumps
- valves
- heating
- basic separation

Mostly manual operation.

## Tier 2 — Small Refinery
Unlock:
- larger tanks
- better pumps
- proper distillation
- more products
- more crude options

## Tier 3 — Product Quality
Unlock:
- laboratory
- sampling
- simple quality testing
- off-spec products
- reprocessing

## Tier 4 — Automation
Unlock:
- temperature transmitters
- pressure transmitters
- flow transmitters
- level transmitters
- control valves
- alarms
- simple control room

## Tier 5 — Integrated Refinery
Unlock:
- larger refinery area
- tank farm
- multiple process units
- more complex crude oils
- larger logistics
- improved automation

Do not implement all tiers at once.

Always focus on the currently requested milestone.

---

# First playable milestone

The first useful prototype should stay small.

Target loop:

1. Player receives crude oil.
2. Crude is stored in a tank.
3. Player starts a pump.
4. Player opens the correct valve.
5. Crude enters a heater.
6. Heated crude enters a simplified distillation unit.
7. Three fractions are produced.
8. Fractions enter separate product tanks.
9. Player sells a valid product.
10. Player earns money.

Suggested first objective:

"Process 1,000 L of crude oil and produce at least 200 L of approved middle distillate."

Do not add advanced refinery units before this loop works and is enjoyable.

---

# Economy

Keep the first economy simple.

Core loop:

Buy crude -> process crude -> produce products -> sell products -> buy better equipment

Possible variables:
- crude cost
- product sale value
- machine purchase price
- upgrade cost

Do not build a complex market simulation early.

---

# Educational design

Learning should emerge from actions.

Good example:
The player gets LOW FLOW and has to discover that a valve is closed.

Bad example:
A popup asks:
"What does flow mean?
A) ...
B) ...
C) ..."

Prefer:
- operating equipment
- troubleshooting
- interpreting gauges
- observing cause and effect
- taking samples
- fixing off-spec products

The player should become better at the game by understanding process concepts.

---

# Troubleshooting

Failures should be understandable.

Early examples:

LOW FLOW
Possible causes:
- pump off
- closed valve
- empty source tank

HIGH TEMPERATURE
Possible causes:
- heater setting too high
- low flow through heater

TANK FULL
Possible causes:
- destination tank full
- process still running

OFF-SPEC PRODUCT
Possible causes:
- wrong process temperature
- incorrect crude
- incorrect operating conditions

Avoid random failures with no player-readable cause.

---

# Safety / HMS

Safety should be present but simple.

Possible systems:
- PPE zones
- hot equipment
- leaks
- overfilled tanks
- high pressure alarms
- emergency shutdown

Safety consequences should support learning.

Avoid excessive punishment that makes the game frustrating.

---

# UI rules

The UI should communicate process state clearly.

Important values should be easy to read:
- volume
- flow
- temperature
- pressure
- machine status

Use clear units:
- L
- L/min
- °C
- bar
- %

Avoid cluttering the screen with advanced instrumentation before the player has learned the basics.

When adding a new value to the UI, ask:
"Does the player need this value to make a decision?"

If not, do not show it yet.

---

# Player experience

The player should preferably interact physically with equipment in the world.

Examples:
- walk to a pump and start it
- turn a valve
- inspect a gauge
- connect equipment
- collect a sample

Automation should be unlocked later so that progression feels meaningful.

---

# Visual scope

Do not block development waiting for perfect art.

During prototyping:
- use primitive meshes
- simple materials
- readable labels
- placeholder models

Gameplay systems should work before visual polish.

When making temporary industrial assets, prioritize readable silhouettes:
- tank looks like a tank
- pump looks like a pump
- valve is easy to identify
- heater looks different from a storage vessel

---

# AI coding rules

Before making a meaningful change:

1. Inspect the relevant existing files.
2. Understand the current implementation.
3. Reuse existing systems where reasonable.
4. Identify the smallest safe change.
5. Implement it.
6. Check for parser errors and broken references.
7. Run the project or relevant tests if possible.
8. Report what changed.

Never invent files, nodes, classes or APIs that have not been verified.

If a requested feature requires major architectural work, explain the impact before rewriting large parts of the project.

---

# Refactoring rules

Refactor only when:
- current code prevents the requested feature
- there is clear duplicated logic causing problems
- a script has become genuinely difficult to maintain
- the user explicitly requests cleanup

Before a large refactor:
- preserve current behavior
- minimize file movement
- keep public interfaces stable where possible

Do not perform unrelated cleanup during a feature task.

---

# Debugging rules

When fixing a bug:

1. Reproduce or identify the failure.
2. Read the error output.
3. Find the smallest likely root cause.
4. Fix the root cause rather than hiding the symptom.
5. Test again.
6. Do not rewrite unrelated systems.

If the cause is uncertain, add temporary logging rather than guessing.

---

# Testing

For every meaningful gameplay system, prefer a quick test scenario.

Examples:
- Tank can fill but cannot exceed capacity.
- Pump moves fluid only when powered/on.
- Closed valve prevents flow.
- Heater increases temperature.
- Distillation conserves total input volume within the simplified model.
- Product tanks receive the correct fractions.

Whenever possible, ensure:

input volume ~= total output volume

Small simplifications are acceptable, but unexplained creation or disappearance of large amounts of fluid should not occur.

---

# Performance

Do not optimize prematurely.

However:
- avoid creating unnecessary nodes every frame
- avoid expensive searches through the entire scene tree every frame
- avoid per-frame logic when signals, timers or slower updates are sufficient

Refinery simulation does not need to update every variable every rendered frame.

---

# Naming

Use clear English code names.

Examples:
- CrudeTank
- TransferPump
- ManualValve
- CrudeHeater
- DistillationUnit
- ProductTank

Variables:
- current_volume_l
- capacity_l
- flow_rate_lpm
- temperature_c
- valve_open_percent

Prefer explicit names over abbreviations.

Industrial tag numbers such as P-101, TK-101 and TT-101 may be shown to the player later, but internal code should remain readable.

---

# Comments and documentation

Comment WHY, not obvious WHAT.

Good:
# Prevent selling the tank contents while the process is still running.

Bad:
# Set running to false.
running = false

Add short documentation to reusable systems.

Do not create excessive documentation for tiny scripts.

---

# Changes that require caution

Do not do these without explicit instruction:

- switch game engine
- convert the project to C#
- add multiplayer
- add networking
- add backend services
- add procedural world generation
- add realistic CFD/fluid simulation
- add complex chemical thermodynamics
- replace all placeholder art
- rewrite the entire UI framework
- reorganize the entire repository
- add large third-party frameworks

---

# When the user asks for a new feature

Use this order:

1. Define the minimum playable version.
2. Build the smallest functional implementation.
3. Verify it works.
4. Make it understandable.
5. Only then add realism/polish.

Example:

User: "Add pumps."

Do NOT immediately build:
- pump curves
- NPSH
- cavitation simulation
- motor wear
- vibration
- maintenance schedules
- power-factor modelling

Start with:
- source
- destination
- on/off
- flow rate

Expand later.

---

# Current project priority

Until explicitly changed, prioritize:

1. Core refinery gameplay loop
2. Reliable fluid transfer between equipment
3. Tank / pump / valve interaction
4. Heating
5. Simple distillation
6. Product storage and selling
7. Clear UI
8. Progression
9. Basic lab / quality
10. Automation
11. Polish

Do not skip ahead to advanced refinery systems before the basic loop is solid.

---

# Definition of done

A feature is not complete merely because the code exists.

A gameplay feature is done when:
- it runs without obvious errors
- it can be understood by the player
- it connects correctly to the existing gameplay loop
- it is reasonably easy for a beginner to maintain
- it does not unnecessarily break existing systems

---

# Final instruction to Codex

Act as a disciplined game-development partner, not an autonomous rewrite engine.

CrudeWorks should grow gradually.

Protect working systems.
Keep code understandable.
Build one layer at a time.
Prefer playable simplicity over theoretical realism.
