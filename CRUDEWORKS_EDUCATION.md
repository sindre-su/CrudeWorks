# CrudeWorks — Educational Alignment

## Educational Purpose

CrudeWorks is first a first-person refinery-building game. It is not a
curriculum simulator, laboratory course or replacement for teaching. Its useful
educational role is as a short, practical supplement to selected parts of Vg2
kjemiprosess- og laboratoriefag: students act on a process, see consequences,
and then discuss the real principle with a teacher.

This document maps natural connections to **KPL02-01**. The authoritative
source is [Utdanningsdirektoratet's curriculum](https://www.udir.no/lk20/kpl02-01).
It does not claim full curriculum coverage or assessment validity.

Design rule:

> Never add a feature solely to increase curriculum coverage if it weakens
> CrudeWorks as a refinery-building game.

## Educational use at three scales

Education emerges from normal play, not a separate curriculum-first game.

- **Demonstration (~10–20 min):** a teacher or student uses a prepared or
  quickly reached normal-game state to experience one relationship, such as
  valve state and LOW FLOW, a temperature target, sulfur treatment, capacity or
  pump condition.
- **Class session (~45–90 min):** students operate the pilot, build/operate a
  first refinery, diagnose an operational problem and discuss the result with a
  teacher.
- **Extended project (multiple lessons or optional free play):** students use
  the same building, operating and troubleshooting systems to design,
  expand and optimise a larger refinery.

These are not three different games. A pump that demonstrates flow in a short
lesson later becomes a power consumer, condition object, capacity bottleneck and
automation target. Optional Training/Classroom Mode should eventually load
focused normal-game scenarios; sandbox systems remain authoritative.

## Current Coverage

### Currently implemented and playable

- A fixed pilot process: heat -> open valve -> start pump -> separate crude ->
  inspect quality -> sell diesel.
- A player-built, directed process line: tank -> pump -> manual valve -> heater
  -> distillation column -> three product tanks.
- Multiple independent process trains, shared crude-feed selection and optional
  product-header storage routing with explicit player-owned destinations.
- Visible IN/OUT ports, logical process order, pipe direction, blocked reverse
  connections and incomplete-line feedback.
- Tank capacity, bounded transfer, product backpressure and a shared canonical
  material-balance invariant.
- Temperature-dependent fractions and diesel quality; Standard, Heavy and Sour
  crude have different targets, yields, treatment needs and delivery choices.
- Field operation of pumps, manual valves and heater targets; 5/10/15 L/s pump
  targets, pump condition and a recoverable blocked-filter restriction with
  derived `ΔP HIGH` diagnostics.
- Troubleshooting feedback including LOW FLOW, HIGH TEMPERATURE and full product
  storage. A closed valve, restricted filter or worn pump can leave a commanded
  pump below normal flow.
- Physical diesel sampling, LAB-101 analysis, off-spec retention/disposal and
  revision-bound dispatch authorization.
- LS-201 local station with live level, temperature and flow telemetry; limited
  remote pump/heater control and a feed-aware temperature trip.
- HT-201 treatment, VDU-301 and FCC-401 secondary processing, electricity/
  PU-101 capacity, product-specific dispatch, economy and persistent reports.

### Partially implemented

- Start/stop behavior is meaningful, but there is no explicit procedure,
  checklist or safe shutdown lesson.
- Instrumentation is readable and actionable, but has no calibration, error,
  uncertainty or general numeric pressure measurement; the current filter ΔP is
  a qualitative troubleshooting diagnostic.
- Automation is limited to remote commands and a temperature permissive/trip;
  there is no closed-loop regulation or configurable interlock logic.
- Laboratory work uses a real sample/action/result loop, but the analysis is a
  simplified quality result rather than a method, apparatus or uncertainty task.
- Product disposal and temperature trips introduce safety thinking, but PPE,
  risk assessment, leaks, pressure hazards and environmental consequences are
  not gameplay systems.
- Batch reports demonstrate accounting and process data, but are not formal
  operator logs, P&IDs, data sheets or student documentation.

### Planned, not current coverage

- More expressive physical feedback, visual/audio cues and hands-on usability.
- Better short-session scenario setup and medium-term progression pacing.
- Detailed pressure/pressure-loss systems, energy balances, P&ID views, broader
  control loops, calibration and broader safety systems.
- Additional quality/operations depth only where it improves the refinery game.

## Strong Curriculum Connections

KPL02-01 emphasizes process/laboratory technology, explaining production from
raw material to product, flow diagrams, calculations, monitoring, quality and
safe practice. CrudeWorks has its strongest fit where students learn a process
relationship by operating or repairing it, not by answering a question.

| Curriculum concept | Relevance | Current game coverage | Potential future coverage | Natural gameplay example | Educational value | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| Unit operations and equipment function | CORE FIT | Tank, pump, valve, heater, column and product storage are distinct usable units | More treatment/storage units | Explain what each placed unit contributes to a working line | Strong concrete vocabulary and systems thinking | A |
| Logical process sequence | CORE FIT | Directed network requires tank -> pump -> valve -> heater -> column -> tanks | Optional simplified flowsheet view | A wrong order or missing pipe is rejected with an actionable reason | Students experience dependency instead of memorising order | A |
| Pumps, valves and flow | CORE FIT | Pump command, actual flow, valve state and LOW FLOW are playable | Flow restriction/fault variety | Start the pump against a closed valve, see 0 L/s, then open it | Clear cause-and-effect and troubleshooting | A |
| Tanks, level and capacity | CORE FIT | Finite source/product capacity and backpressure are modelled | Level alarms and tank farm | A full product tank stops the whole balanced process | Connects storage constraint to production | A |
| Temperature as a process condition | CORE FIT | Heating, temperature target, temperature alarms and feed-specific quality windows | Heat-transfer/energy choices | Run Heavy near 230 °C rather than Standard near 200 °C | Shows that setpoint affects result | A |
| Simplified separation/distillation | CORE FIT | Column creates light/diesel/heavy fractions from feed with bounded total volume | More fractions and treatment | Compare fractions at cold, target and hot operation | Useful intuitive introduction, if labelled simplified | A |
| Mass balance | CORE FIT | Tests and model conserve processed input across three outputs | Player-facing batch balance | Compare 1,000 L input with fraction total in a report | Supports classroom calculation and catches magical thinking | A |
| Product quality and specification | CORE FIT | Weighted diesel quality, contract criteria, off-spec retention and dispatch gate | Additional properties/specifications | A batch can meet volume but fail quality | Links operating condition to product acceptance | A |
| Sampling and analysis | CORE FIT | Player takes a physical diesel sample, brings it to LAB-101, analyses before dispatch | More tests and sample plans | Production invalidates an old sample; a new sample is required | Strong quality-assurance loop without quiz gameplay | A |
| Process monitoring/instrumentation | CORE FIT | LS-201 shows level, temperature, actual/target flow, valve and pump state | More transmitters and alarms | Distinguish commanded pump from actual 0 L/s flow | Builds instrument-reading habits | A |
| Startup, shutdown and trips | STRONG OPTIONAL FIT | Warming before flow, pump stop requirement for sampling/disposal, remote temperature trip | Explicit procedures and ESD | Remote start is blocked outside an approved temperature range | Good bridge to operating procedures | A |
| Fault finding and deviations | CORE FIT | Closed valve, empty source, wrong topology, full tank, off-spec and ambiguous lines produce messages | Maintenance fault and richer fault isolation | Diagnose LOW FLOW from actual plant state | Strong transfer to structured troubleshooting | A |
| Screen-based control systems | STRONG OPTIONAL FIT | LS-201 is a small local HMI with limited commands | Control room and trend/history | Start/stop route pump remotely while valve remains field-only | Demonstrates purpose and limits of HMI control | B |
| Interlocks and regulation | STRONG OPTIONAL FIT | Temperature permissive/trip exists; no automatic control loop | Simple permissive matrix, level/temperature control | Pump trips before remote operation processes an unsafe-temperature batch | Useful progression after manual learning | B |
| Flow diagrams and technical diagrams | STRONG OPTIONAL FIT | Spatial pipes, ports and validation make a physical flow representation | Optional PFD/P&ID overlay | Reconstruct a built line on a simple flow diagram after play | High classroom transfer; should remain optional | B |
| Optimisation and throughput | STRONG OPTIONAL FIT | 5/10/15 L/s affects time and temperature margin; Standard/Heavy affect economy | Bottlenecks, energy/capacity tradeoffs | Choose lower flow for tolerance or high flow for throughput | A meaningful production decision, not spreadsheet work | B |
| Measurement equipment faults | INCIDENTAL FIT | Process faults are diagnosed; measurements themselves are assumed correct | Sensor drift, failed transmitter, calibration | Compare a faulty level/temperature display with physical symptoms | Worth adding only with maintenance gameplay | B |
| Energy and heat balance | INCIDENTAL FIT | Heating has a target and time response, but no energy accounting | Simple energy cost/heat-loss choice | Compare warm-up time or heating demand | Use teacher calculation outside game first | B |
| Pipe pressure loss | INCIDENTAL FIT | Simplified filter restriction exposes `ΔP HIGH`; pipes still have no hydraulic network | More restriction/fouling only when diagnostically useful | Reduced flow due to a blocked filter, not generic pipe physics | Only useful if it creates good diagnosis | B |
| Sustainable production and waste | STRONG OPTIONAL FIT | Mass conservation, reuse of equipment economy and safe product disposal exist | Emissions/waste/value tradeoffs | Choose a delivery/process that avoids off-spec disposal | Natural only when tied to player decisions | B |
| Documentation and reporting | INCIDENTAL FIT | Batch report and lab result communicate process data | Exportable teacher worksheet or run summary | Use report values in a short classroom calculation | Good classroom bridge; not a core in-game task | B |
| Technical terminology | INCIDENTAL FIT | Norwegian industrial names/tags and labels appear in context | Optional English/technical terminology toggle | Identify P-201, V-201, TT-201 and LT-201 after use | Best reinforced in teacher discussion | B |
| HMS, risk assessment and safe handling | STRONG OPTIONAL FIT | Temperature trip, stop-before-sample/disposal and warning text exist | PPE, hot zones, leaks, risk cards | Stop pump before analysing or disposing products | Needs gradual, gameplay-relevant expansion | B |
| Calibration and measurement uncertainty | POOR FIT now | Not modelled | Classroom material may discuss it alongside game data | Teacher introduces uncertainty after a deterministic game run | A full calibration minigame would be disconnected | C |
| Stoichiometry and chemical reactions | POOR FIT | Refinery is a simplified physical separation; no reaction chemistry | Only if a later unit genuinely has reaction gameplay | Use the game as context, not as reaction calculator | Do not force reaction equations into the core loop | C |
| Microbiology/environment tests | POOR FIT | Not represented | None recommended for core game | None | Outside refinery-builder fantasy | C |
| Labour rights, workplace collaboration and formal standards | POOR FIT in gameplay | No multiplayer/team workflow or formal standard system | Teacher-led reflection only | Discuss after a group task, outside normal play | Belongs in teaching context, not a solo refinery loop | C |

## Strongest Learning-by-Doing Opportunities

1. **Follow a material path.** Building a valid line teaches that units have
   inputs, outputs and an order.
2. **Move material with a pump.** The player sees that a pump command alone is
   not enough; flow needs a source, a route and an open valve.
3. **Use valves as process decisions.** A manual valve changes whether the
   process can run and creates a diagnosable LOW FLOW fault.
4. **Read actual flow rather than assume it.** LS-201 distinguishes target
   throughput, pump command and actual L/s.
5. **Respect finite storage.** A full product tank stops process transfer
   without consuming feed.
6. **Operate to a condition, not a button.** Heating toward the chosen crude's
   target changes yield and quality.
7. **Understand separation as distribution.** The three fractions share the
   same bounded input mass.
8. **Use a mass balance.** Product totals can be compared with crude processed
   in the batch report.
9. **Treat quality as evidence.** Paid batches require sampling and LAB-101
   analysis before dispatch.
10. **See why a sample goes stale.** New production, rerouting, disposal and
    save/load invalidate a previous authorization.
11. **Troubleshoot a deviation.** Messages identify missing connections, wrong
    direction, empty source, closed valve, high temperature and tank-full
    conditions.
12. **Choose throughput deliberately.** 5/10/15 L/s makes a concrete tradeoff
    between production time and temperature margin.
13. **Compare feed choices.** Standard and Heavy have different targets,
    fractions, volume requirements and economics.
14. **Experience a simple permissive/trip.** Remote pump control is blocked or
    stopped by a feed-aware temperature range.
15. **Separate process quality from order completion.** Heavy can have a good
    diesel sample yet still lack enough heavy fraction for delivery.

## Accidental Learning Already Present

| Player action | Principle encountered | Likely understanding | Tiny clarification with high value |
| --- | --- | --- | --- |
| Rotate/place equipment and follow coloured ports | Direction and equipment interfaces matter | A pipe is not interchangeable at both ends | Keep IN/OUT colours and port labels visible in build mode |
| Connect an invalid order | Process sequence is constrained | Heating after the column is not equivalent to heating feed | Preserve the player-readable reason, not an error code |
| Start pump with valve closed | Commanded equipment can still have zero process flow | “Pump on” is not the same as “material moves” | Keep actual flow and valve state together in LS-201 |
| Fill a product tank | Downstream capacity constrains upstream production | Storage is part of the process, not decoration | Name the limiting product tank in the alarm |
| Sample then continue production | Analysis authorization depends on representative current material | Old information can become invalid | Keep the current revision/stale-sample feedback |
| Use Standard and Heavy | Feed properties change operating target and yield | Raw materials require different operation | Keep the contract target beside the active feed name |
| Use 5/10/15 L/s | Operating point changes quality margin and batch duration | Throughput can trade against robustness | Keep the LAB report's average flow beside temperature |
| Remote-start through LS-201 | Instruments and permissives support, but do not replace, field work | Automation has limits; valve stays manual | Preserve the explicit “V-201 — FELT” label |

## Misconceptions to Avoid

| Simplification or risk | Classification | Safeguard / clarification |
| --- | --- | --- |
| Fractions sum to processed crude and tanks have capacity | ACCEPTABLE SIMPLIFICATION | Preserve mass-conserving transfer and show processed/product totals in reports |
| Temperature changes simple fraction yields and diesel quality | ACCEPTABLE SIMPLIFICATION | Describe it as a simplified process rule, not a complete refinery model |
| One tank state represents a mixed stream and quality is volume-weighted | ACCEPTABLE SIMPLIFICATION | Keep quality tied to material, not a final setpoint alone |
| Distillation appears to depend only on temperature | NEEDS CLARIFICATION | A short optional teacher note or inspection text should say that real separation also depends on pressure, composition, column design and reflux |
| “Crude” behaves like one named material | NEEDS CLARIFICATION | Keep Standard/Heavy framing as simplified feed profiles, not pure substances |
| Pump target and actual flow may be confused | NEEDS CLARIFICATION | Continue displaying both, especially at closed valve/full tank |
| Filter ΔP may be mistaken for a full pressure model | NEEDS CLARIFICATION | Explain it as a simplified restriction diagnostic; do not show fictitious plant pressure values |
| Pilot can be run too hot/cold with primarily quality/economic consequences | NEEDS CLARIFICATION | Future safety feedback should distinguish product quality from operating safety without making early play punitive |
| LAB result is deterministic and has no method, calibration or uncertainty | NEEDS CLARIFICATION | Present LAB-101 as a simplified quality check; classroom work can add method/uncertainty |
| Product disposal is “safe” by a button without a waste system | NEEDS CLARIFICATION | Call it controlled/simplified disposal and avoid implying this models real waste handling |
| Pumping creates products if the process is valid | SHOULD BE CORRECTED if it ever occurs | Retain the current source-decrement/output-increment tests; never allow outputs without consumed crude |
| Reversed or disconnected equipment moves material | SHOULD BE CORRECTED if it ever occurs | Retain directed-network validation and route-scoped simulation |
| Treating pressure loss, heat balance or reaction chemistry as already taught | SHOULD BE CORRECTED in documentation | Mark these as classroom extensions or future systems, not current coverage |

## Educational Improvements

### A — High value, low disruption

1. **Hands-on readability pass at 1280 x 720.** Verify that ports, valve state,
   alarms and instrument units are readable before adding concepts.
2. **Keep maintenance diagnosis physical.** The implemented blocked filter and
   pump condition should create distinct reduced-flow patterns, with local
   inspection and preventive service rather than an automatic repair answer.
3. **Optional simple flow diagram after a successful build.** Reuse the actual
   route; show no quiz and no separate simulator.
4. **Batch mass-balance line in report/inspection.** Show crude processed and
   total fractions explicitly, then let classroom work do the calculation.
5. **Explicit start/stop state language.** Keep “pump commanded” separate from
   “actual flow” and add short orderly shutdown feedback where useful.
6. **Alarm cause hierarchy.** Continue naming the actual limiting condition
   (valve closed, source empty, tank full) rather than merely saying LOW FLOW.
7. **Short optional simplification note.** One teacher-facing note that the
   column is temperature-based gameplay, not industrial thermodynamics.
8. **Product/waste consequence in economy.** If disposal remains, make the
   lost material and cost visible in reports rather than adding punishment.
9. **Unit/tag consistency.** Continue clear L, L/s and °C labels; retain tags
   such as P-201, V-201, LT-201 and TT-201.
10. **Teacher scenario seeds later.** Save/reuse normal game states for low
    flow, full tank and off-spec diagnosis instead of creating quiz levels.

### B — Useful later

- Optional PFD/P&ID view derived from the real network.
- Trend/history view at LS-201, only after players already read live values.
- One simple level or temperature control loop after manual control is learned.
- Instrument drift/calibration only as part of a good maintenance fault.
- Extend Sour treatment only when the additional choice affects quality, waste
  or value in a way the player can observe and act on.
- Simple energy/heat-use comparison tied to a meaningful operating choice.
- Gradual HMS: hot zones, safe sampling position, minor process trip or ESD.

### C — Do not build solely for education

- Separate quizzes for every term or competence aim.
- Formal laboratory-method, calibration or uncertainty minigames without a
  matching refinery decision.
- Microbiology, microscopy and environmental-testing modules.
- Full stoichiometry/reaction calculator for an otherwise separation-focused
  loop.
- Labour-law, standards or workplace-rights systems inside ordinary gameplay.
- Engineering-grade pressure/energy/thermodynamic simulation.

## Classroom Use

These are short modules; the teacher supplies explanation, discussion and any
calculation. CrudeWorks is the shared practical example, not the assessment.

| Scenario | Curriculum connection | Student activity | Time | Teacher discussion | Extra material |
| --- | --- | --- | --- | --- |
| Pilot start-up | Start/stop, flow, temperature | Warm, open valve, pump and make acceptable diesel | 15–25 min | Why sequence matters; source/valve/pump dependencies | Optional one-page procedure |
| LOW FLOW investigation | Fault finding, instrumentation | Start against a closed valve; diagnose from plant/LS-201 | 10–15 min | Pump command vs actual flow; possible real causes | No |
| Build the line | Unit operations and flow diagrams | Build/connect a valid Area 02 line and validate it | 20–35 min | Inputs/outputs, process order and block diagram | Simple blank flowsheet optional |
| Mass balance | Calculations and production | Process a known crude amount; read fractions/report | 15–25 min | Sum fractions, compare input/output and discuss measurement limits | Calculator/worksheet |
| Standard versus Heavy | Process conditions and optimisation | Run or compare two contracts at their targets | 20–35 min | Feed properties, yields, quality, order constraints and economics | Comparison table optional |
| Off-spec recovery | Quality and deviations | Produce off-spec product, sample/analyse, decide whether to continue or dispose | 20–30 min | Quality versus volume; representative sample; corrective action | Brief reflection prompt |
| Sampling chain | Analysis/documentation | Take a sample, analyse it, then invalidate it with new production | 10–20 min | Why a stale sample cannot authorize a changed batch | No |
| Local station | Measurement/control/automation | Compare field control with LS-201 remote pump/heater controls | 15–25 min | LT/TT/FT tags, permissives, manual valve and automation limits | Instrument tag handout optional |
| Throughput tradeoff | Optimisation and process condition | Compare 5/10/15 L/s at controlled temperature | 20–30 min | Throughput, robustness, quality margin and evidence in LAB report | Data table optional |
| Pump condition / filter fault | Maintenance, deviations and procedures | Diagnose/restore one reduced-flow fault with normal tools | 15–30 min | Symptom, evidence, safe stop, correction and prevention | Short fault report optional |

## Optional Training / Classroom Mode

**Recommendation: valuable later, not a current implementation priority.**

It becomes worthwhile only after the normal loop has received hands-on playtest
and the first maintenance fault is enjoyable. The mode should load controlled
normal-game scenarios, not create separate quiz minigames. Appropriate scenarios
would be: low flow from a closed valve, correct start-up, invalid process line,
full product tank, off-spec batch, one temperature trip and a simple mass-balance
report.

Useful design constraints:

- Reuse `BuiltRefineryModel`, `ProcessNetwork`, LAB-101 and LS-201 unchanged.
- Seed a known world/batch and optionally limit available equipment.
- Let students solve by walking, building, reading and operating.
- Give a compact outcome report for teacher discussion, not a grade.
- Keep the normal game fully playable without classroom mode.

## Out of Scope

CrudeWorks should not claim to teach or assess the full KPL02-01 curriculum. In
particular, it should not attempt to cover microbiological preparation,
microscopy, comprehensive chemical analysis methods, calibration practice,
measurement uncertainty, formal risk assessments, data-sheet literacy, labour
rights, collaboration models, formal standards/regulatory compliance or detailed
energy/pressure calculations through disconnected gameplay systems.

These topics may be supported by a teacher around the game, but they are not
reasons to broaden the core refinery loop.

## Roadmap Impact

### Already aligned

- Graybox World now protects the physical scale, navigation and area readability
  needed for process learning before new simulation depth is considered.
- Recoverable pump filter faults and pump condition directly support troubleshooting,
  instrumentation, procedures and maintenance without changing the game genre.
- Sour crude with HT-201 treatment supports unit-operation relationships,
  quality and sustainable production when the treatment choice is real.
- Existing product routing/value systems strengthen storage, capacity and optimisation.

### Small opportunities

- Add a concise mass-balance line to existing batch reporting.
- Preserve explicit actual-versus-target flow and route-specific alarm reasons.
- Consider an optional route diagram only after the physical build loop is
  validated in real play.

### Do not prioritise for curriculum reasons

- Calibration, uncertainty, reaction calculations, full P&ID authoring,
  pressure modelling, formal documentation workflows and broad HMS modules.

The long-term vision remains the design north star. Educational value is strongest
when better gameplay, a truer process relationship and useful classroom transfer
all point in the same direction.
