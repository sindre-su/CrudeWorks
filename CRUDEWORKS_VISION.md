# CrudeWorks — Long-Term Game Vision

## Purpose of this document

This document defines the long-term ideal for CrudeWorks. It is the project's **north star**.

It is **not** a milestone checklist and it is **not** permission to implement every system immediately. Codex should use this file to make better design decisions, judge whether new features fit the game, and keep development moving toward a coherent final experience.

For day-to-day implementation rules, also follow `AGENTS.md`. When there is tension between adding complexity and preserving a fun, understandable game, prefer the fun and understandable solution.

---

## One-sentence vision

**CrudeWorks is a first-person refinery-building game where the player starts with a tiny manual process setup and gradually designs, builds, operates, troubleshoots and expands a large refinery using real process principles with simplified mathematics.**

---

# Player fantasy: Refinery Builder

The primary player fantasy is **Builder**, not operator or tycoon.

The player is not mainly operating a refinery somebody else designed. The player builds it.

The player should feel:

> “This entire refinery exists because I designed it.”

The player chooses where equipment is placed, how it is connected, how products move through the plant, how the refinery expands, and how increasingly advanced process systems are integrated.

The refinery should become a physical record of the player's decisions. Two players should eventually be able to build noticeably different refineries while solving the same overall production problems.

---

# Core inspiration

The overall progression should have a similar sense of scale and satisfaction to a late-game Hydroneer operation:

- start extremely small
- operate equipment manually
- earn access to better technology
- expand into new areas
- gradually automate repetitive work
- build increasingly large systems
- eventually look back at a huge industrial operation that grew from almost nothing

CrudeWorks should **not** copy Hydroneer's mechanics directly. The important inspiration is the feeling of:

**small manual beginning → player-built industrial machine**

---

# Final scale

The endgame refinery should feel comparable to the scale of a late-game Hydroneer operation.

It does not need to reproduce a real refinery such as Mongstad at 1:1 scale. Instead, the endgame should be a compressed but visually impressive industrial complex containing enough equipment, piping, storage and logistics that the player's starting area feels tiny by comparison.

A mature refinery may eventually contain:

- crude receiving
- multiple crude storage tanks
- process feed systems
- pump networks
- valve networks
- heaters
- distillation systems
- treatment systems
- product storage
- large tank farms
- several parallel process routes
- utility systems where gameplay-relevant
- laboratory facilities
- control room
- loading/export area
- maintenance-access areas
- alarms and instrumentation
- automated process sections

The player should be able to walk through the refinery and recognize systems they personally built earlier in the game.

---

# Core gameplay loop

**Acquire crude**
↓
**Store crude**
↓
**Build a process**
↓
**Connect equipment**
↓
**Operate equipment**
↓
**Monitor process conditions**
↓
**Troubleshoot problems**
↓
**Separate / treat products**
↓
**Test product quality**
↓
**Store products**
↓
**Sell products**
↓
**Reinvest**
↓
**Expand refinery**
↓
**Unlock better process capability**

This loop should remain recognizable from early game to endgame. The scale and complexity increase, but the underlying logic remains understandable.

---

# Core design pillars

## 1. Free building

Refinery construction is a central gameplay system.

The player should be able to place individual equipment and create their own process layout, including:

- tanks
- pumps
- valves
- pipes
- heaters
- columns
- product tanks
- instruments
- later process units

The game should understand the logical process network created by the player.

The player should not simply place large prebuilt “refinery modules” that solve the process automatically. Large prefab structures may exist later for convenience, but the core fantasy should remain:

**I built the process.**

## 2. Real principles, simplified mathematics

CrudeWorks should teach correct relationships without becoming engineering software.

Principles that should remain meaningful include:

- tanks have finite volume
- fluids have direction
- pumps create or enable flow
- valves control flow paths
- equipment has inputs and outputs
- process order matters
- heating affects process conditions
- crude oils produce different product distributions
- equipment has operating limits
- product quality depends on process conditions
- matter should not obviously duplicate
- storage capacity matters
- automation requires instrumentation
- poor process design causes operational problems

Avoid engineering-grade CFD, rigorous thermodynamics, advanced reaction kinetics and detailed hydraulic modelling. A simplified model is acceptable when the cause-and-effect remains educationally correct.

## 3. Physical operator gameplay

The player should spend significant time physically interacting with the refinery.

Early game should be heavily manual. The player should walk to pumps, start equipment, open valves, inspect gauges, check tank levels, collect samples, reset equipment and investigate alarms.

Automation should reduce repetitive work later, but should never completely remove the player from the plant.

## 4. Troubleshooting is game-defining

Troubleshooting should become one of the defining features of CrudeWorks.

A player who understands their refinery should outperform a player who only knows which buttons to press.

Problems should have logical causes.

Examples:

### Low flow
- pump stopped
- closed valve
- reversed pump
- empty source tank
- blocked process route
- full downstream tank

### High temperature
- excessive heater output
- insufficient flow
- incorrect process configuration

### No product output
- incorrect process order
- missing connection
- wrong operating conditions
- destination unavailable

### Off-spec product
- incorrect process temperature
- unsuitable crude
- contamination
- incorrect blending
- process instability

### Equipment trip
- unsafe operating condition
- full destination
- high pressure
- process fault

The game should usually give the player enough information to diagnose the problem without simply revealing the answer.

---

# Failure philosophy

Failures should be:

- understandable
- diagnosable
- recoverable
- educational
- sometimes costly
- rarely arbitrary

Avoid random failures that provide no useful gameplay. Randomized events are acceptable when the underlying problem can still be investigated.

Early versions should keep failure systems simple.

---

# Process network

The player-built refinery should use a lightweight logical process network.

The network should understand:

**equipment port → connection → equipment port**

It should be able to validate relevant rules such as:

- missing required connection
- wrong flow direction
- duplicate connection
- incompatible connection
- invalid equipment sequence
- forbidden circular path
- output connected to output
- required product output missing

Errors should be presented in player-friendly language.

Bad:

`PROCESS_GRAPH_ERR_16`

Good:

`The pump outlet is not connected to a valid downstream machine.`

The process network is a gameplay system, not an engineering simulation.

---

# Long-term progression

Progression should be gradual and physical. The player should repeatedly gain new capability, new equipment, new problems, new opportunities for automation and more physical space.

## Stage 1 — Pilot Operation

Very small process area. Mostly existing equipment.

Learn:
- tanks
- heat
- valves
- pumps
- basic distillation
- product quality
- selling

The purpose is to teach the player's first complete process loop.

## Stage 2 — First Self-Built Refinery

The player gains a construction area and begins building their own process.

Learn:
- equipment placement
- pipe connections
- process order
- direction
- capacities
- simple validation

This is the transition from tutorial to true CrudeWorks gameplay.

## Stage 3 — Small Commercial Refinery

The player expands capacity.

Unlock:
- larger tanks
- stronger pumps
- better heaters
- improved distillation
- additional crude options
- more meaningful economics

The refinery begins feeling like an industrial operation.

## Stage 4 — Product Quality and Laboratory

Production alone is no longer enough. Products must meet specifications.

Introduce:
- sampling
- quality testing
- off-spec batches
- reprocessing
- simple blending
- additional product characteristics

The laboratory should support gameplay rather than become a disconnected minigame.

## Stage 5 — Instrumentation

Manual operation becomes increasingly difficult.

Unlock:
- level indication
- flow indication
- temperature indication
- pressure indication
- alarms
- basic transmitters
- improved equipment inspection

The player starts learning to read the refinery rather than constantly checking every machine manually.

## Stage 6 — Automation

The player can automate repetitive tasks.

Unlock concepts such as:
- control valves
- automatic pump control
- level control
- temperature control
- simple interlocks
- automatic shutdown conditions

Automation should feel powerful because the player previously performed these tasks manually.

## Stage 7 — Integrated Refinery

Multiple process systems operate together.

The player manages:
- several crude types
- several products
- more complex routing
- larger tank farms
- multiple storage requirements
- concurrent production
- increasingly important process stability

The refinery becomes a network rather than a single production line.

## Stage 8 — Large Refinery / Endgame

The player operates a large self-built industrial complex.

The challenge shifts from:

> “Can I make diesel?”

To:

> “Can I design and operate a reliable refinery?”

The player may simultaneously manage crude supply, storage, multiple process lines, product quality, product grades, automation, throughput, bottlenecks, maintenance, alarms, energy where gameplay-relevant, profitability and expansion.

---

# Product progression

The long-term core product families are:

## Refinery Gas / LPG
A light refinery output and useful secondary product.

## Naphtha / Gasoline Components
Valuable lighter fractions. Later systems may allow improved processing or blending.

## Kerosene / Jet Fuel
A valuable middle fraction whose quality requirements can become more important later.

## Diesel / Gas Oil
A major core product and suitable as one of the earliest fully implemented sale products.

## Heavy Products / Residue
Initially lower-value output. Later progression should create opportunities to improve the value of heavy fractions.

This creates a natural motivation for advanced technology:

> “Previously this was cheap residue. Now my refinery can turn it into something valuable.”

---

# Crude oil progression

Crude oil should not have a simple “better = more expensive = more profit” hierarchy.

Different crude types should create different design and economic challenges.

## Starter Crude
Forgiving and designed for learning.

## Light Sweet Crude
- expensive
- high valuable-product yield
- easier treatment
- lower sulfur

## Medium Crude
Balanced cost and product distribution.

## Heavy Crude
- cheaper
- higher heavy-fraction yield
- more difficult to use efficiently

Becomes more attractive once the refinery has advanced equipment.

## Sour Crude
- potentially cheaper
- higher sulfur
- requires additional treatment

A capable refinery should be able to profit from difficult crude.

Important endgame principle:

**The most profitable crude is not automatically the easiest crude.**

---

# Economy

The economy should support refinery building rather than dominate the game.

Core loop:

**buy/receive crude → create products → sell products → reinvest**

Money is used for:

- machines
- refinery expansion
- tanks
- piping
- upgraded equipment
- instrumentation
- automation
- laboratory capability
- process improvements

Economic decisions should matter. Take inspiration from industrial/oil empire games where useful, but avoid turning CrudeWorks into a spreadsheet-heavy management simulator.

The player fantasy is **building a refinery**, not managing financial dashboards.

## Construction economics

The player may need to choose between:

- buying a larger crude tank
- adding another pump
- upgrading distillation
- expanding product storage
- buying access to new land
- adding laboratory equipment
- automating an existing process

There should often be several reasonable ways to invest. Avoid one obvious upgrade path where every player buys exactly the same equipment in the same order.

---

# Automation philosophy

Automation should be earned.

Early game:

**Player operates equipment manually.**

Midgame:

**Player gains instruments and local controls.**

Late game:

**Player builds automated control.**

This creates meaningful progression because the player understands the manual process before automating it.

Automation should not turn CrudeWorks into an idle game. Even an automated refinery should occasionally require the player to investigate alarms, inspect equipment, troubleshoot problems, modify process routes, recover from trips, improve bottlenecks and expand the plant.

---

# Control room vision

A control room is an important long-term progression reward.

The player should eventually be able to see major process values remotely:

- tank levels
- pump status
- flow
- temperature
- pressure
- alarms
- product routing
- process status

The control room should not initially provide perfect control over everything. Its capability should grow through progression.

The player should still need to visit the physical plant when appropriate.

---

# Laboratory vision

The laboratory connects Kjemi, prosess og laboratoriefag directly to gameplay.

The player should be able to collect samples and determine whether products meet requirements.

Long-term tests may include simplified representations of:

- density
- viscosity
- water content
- sulfur
- flash point
- distillation characteristics

Not every test needs a detailed minigame. The important gameplay question is:

> “Is my product on specification, and if not, what caused the problem?”

The laboratory should help the player diagnose the process.

---

# Education philosophy

CrudeWorks should have a balanced relationship with the school curriculum.

The game should teach useful concepts, but should not feel like homework.

Education should exist primarily through:

- cause and effect
- operation
- troubleshooting
- process design
- equipment behavior
- quality control
- experimentation

Avoid constant quizzes, large textbook popups and requiring terminology before the player has experienced the concept.

Where possible:

**experience first → terminology second**

Over time, CrudeWorks can naturally reinforce concepts such as:

- process flow
- tanks
- pumps
- valves
- pipes
- flow
- pressure
- temperature
- level
- heating
- separation
- distillation
- sampling
- product quality
- basic chemistry
- instrumentation
- regulation/control
- alarms
- process safety
- HMS
- troubleshooting
- process diagrams
- mass balance
- documentation

Not every curriculum item needs to become gameplay. Only include concepts that create useful or enjoyable interactions.

---

# HMS and process safety

Safety should matter, but remain gameplay-friendly.

Possible long-term systems include:

- PPE requirements
- hot equipment
- overfilled tanks
- leaks
- unsafe pressure
- process trips
- emergency shutdown
- restricted areas
- unsafe operating states

Safety systems should teach **why the safe behavior matters** rather than merely punishing the player for forgetting a checkbox.

The focus is industrial process safety, not graphic injury simulation.

---

# Maintenance

Maintenance can become a later-game system after the core refinery works well.

Possible concepts:

- equipment wear
- pump condition
- filter blockage
- reduced performance
- warning signs
- preventive maintenance

Maintenance should support troubleshooting and should not become repetitive busywork.

A well-operated refinery should require less emergency maintenance than a poorly operated one.

---

# Building philosophy

The building system should encourage creativity while preserving process logic.

Players should be able to create:

- compact refineries
- spread-out refineries
- parallel lines
- centralized tank farms
- different routing strategies

Layout choices should have understandable consequences. The game does not need realistic pipe-pressure simulation to make layout meaningful.

Meaning can come from:

- available land
- connection distance/cost
- accessibility
- capacity
- bottlenecks
- ease of troubleshooting
- future expansion space

---

# Visual identity

The refinery should feel:

- industrial
- mechanical
- functional
- increasingly impressive
- readable

Early game can feel rough and small. Late game should feel like a proper industrial complex.

Visual realism should support gameplay readability. The player should quickly recognize tanks, pumps, valves, heaters, columns, product lines and instruments.

Avoid visual complexity that makes important process information hard to read.

---

# UI philosophy

The world itself should communicate as much information as possible.

Prefer:

- visible gauges
- equipment indicators
- status lights
- labels
- contextual inspection
- alarms
- physical controls

over a giant permanent HUD.

When the player inspects equipment, relevant information can appear.

### Tank
- contents
- current volume
- capacity
- temperature

### Pump
- running/stopped
- direction
- current flow
- capacity

### Heater
- operating state
- process temperature
- target temperature

### Product
- type
- quantity
- quality
- sale state

The UI should tell the player enough to make decisions without overwhelming them.

---

# Endgame experience

The final CrudeWorks experience should allow a skilled player to build a large, mostly self-designed refinery capable of:

- receiving different crude oils
- storing them correctly
- routing them through player-built process systems
- heating feed
- separating multiple products
- treating or improving products where required
- testing product quality
- storing several products
- selling products
- managing bottlenecks
- handling alarms
- troubleshooting failures
- using instrumentation
- automating repetitive operations
- expanding throughput
- keeping the plant stable
- maintaining profitability

The player should still occasionally need to leave the control room and physically enter the refinery.

---

# Ideal final challenge

A strong final challenge for CrudeWorks is:

> **Design and operate a large integrated refinery capable of processing difficult crude reliably while producing several on-spec products simultaneously with strong throughput, sensible automation, safe operation and sustainable profitability.**

There does not need to be a traditional final boss.

The refinery itself is the challenge.

Mastery means the player has built a system they understand deeply enough to keep operating under increasingly difficult conditions.

---

# What makes a player good at CrudeWorks?

A good player should **not** simply be someone who has unlocked the most expensive equipment.

A good player:

- understands process flow
- recognizes bottlenecks
- builds logical process routes
- notices incorrect equipment states
- interprets alarms
- diagnoses failures
- manages storage
- understands product quality
- chooses suitable crude
- makes sensible upgrades
- automates processes they understand
- designs for future expansion

Knowledge and good design should create advantage.

---

# Desired emotional progression

## Beginning
> “I finally got the oil through the pipe.”

## Early game
> “I built my first working refinery.”

## Midgame
> “I understand why this process keeps failing.”

## Later game
> “I redesigned the line and doubled production.”

## Automation
> “I used to operate all of this manually. Now the system does it for me.”

## Endgame
> “I built this entire refinery.”

That last feeling is the core fantasy of CrudeWorks.

---

# Non-goals

CrudeWorks should **not** become:

- professional engineering software
- a realistic CFD simulator
- a rigorous chemical-process simulator
- primarily a quiz game
- primarily a financial spreadsheet
- an idle factory game
- a fully automated game where the player stops interacting
- a 1:1 replica of Mongstad
- a game that requires professional refinery knowledge to begin
- a collection of disconnected educational minigames

---

# Feature decision test

Before adding a major feature, ask:

## 1. Does it strengthen the refinery-builder fantasy?
If no, reconsider it.

## 2. Does it create meaningful player decisions?
If no, it may not need to exist.

## 3. Can the player understand cause and effect?
If no, simplify it.

## 4. Does it create gameplay, learning, progression or satisfying feedback?
If none, do not prioritize it.

## 5. Can the feature be implemented incrementally?
If no, find a smaller version first.

## 6. Does it risk making CrudeWorks feel like engineering software instead of a game?
If yes, simplify it.

---

# Codex guidance

Codex must treat this document as a **LONG-TERM VISION**.

Do **not** attempt to implement the entire vision in one session.

Development should remain incremental:

**inspect current game**
↓
**identify biggest gameplay bottleneck**
↓
**choose a small milestone**
↓
**implement**
↓
**test**
↓
**playability review**
↓
**checkpoint**
↓
**repeat**

The current implementation may be far from the final vision. That is expected.

Every milestone should leave the game more playable than before.

---

# Relationship between vision and roadmap

This document answers:

> “Where should CrudeWorks eventually go?”

The development roadmap answers:

> “What is the best next step from where CrudeWorks is today?”

Never confuse the two.

Do not build an endgame system merely because it is described here. Build it when the current game has reached the point where that system creates meaningful value.

---

# Priority hierarchy

When choosing between competing features, prioritize approximately:

1. Core playable refinery loops
2. Free building
3. Understandable process behavior
4. Troubleshooting
5. Player feedback
6. Progression
7. Process variety
8. Economy
9. Instrumentation
10. Automation
11. Laboratory depth
12. Maintenance
13. Visual polish
14. Endgame complexity

This order may change when current development needs justify it.

---

# Final north star

CrudeWorks succeeds if a player can begin knowing little about process industry and, through playing, eventually build and operate a large refinery that they genuinely understand.

The ideal player reaction is:

> **“I started with one tank and a pump. Now I've built this entire refinery, I know what everything does, and when something stops working I can figure out why.”**

That is CrudeWorks.
