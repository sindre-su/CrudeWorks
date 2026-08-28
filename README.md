# CrudeWorks

**Prototypeversjon: 0.31.4 – Harbor Functional Migration**

CrudeWorks is a first-person refinery-builder prototype. The player starts with
a manual Pilot process, unlocks Area 02, builds directed refinery routes,
operates and diagnoses them physically, then dispatches real stored product.
The initial goal is still to process 1,000 L crude and sell at least 200 L of
approved diesel.

## Current phase

**v0.31.4 — HARBOR FUNCTIONAL MIGRATION.** Functional CI-101 and PD-101 now
exist once at their canonical Harbor zones with all ports, collision and
interactions oriented as complete units. Normal fresh-game progression continues
Pilot -> CI-101 -> Area 02; one concise CI sign supports the Pilot exit and the
approved Area 02 fork/gateway signs support the onward route. No other refinery
system moved.

Quick orientation:

- [Long-term vision](CRUDEWORKS_VISION.md) — refinery-builder fantasy, world
  scale, field/control-room philosophy and scope boundaries.
- [Graybox World brief](WORLD_DESIGN.md) — practical site geography, roads,
  accessibility, expansion and migration constraints.
- [Roadmap](ROADMAP.md) — current milestones and order.
- [Architecture](ARCHITECTURE.md) — current ownership, canonical state,
  utilities, dispatch and save rules.
- [Agent rules](AGENTS.md) — instructions for future Codex work.
- [Development log](DEVELOPMENT_LOG.md) — historical record.

## Status

Den første komplette «vertical slice»-en inneholder:

- førstepersons bevegelse og interaksjon
- råoljetank, pumpe, ventil og varmeenhet
- forenklet temperaturbasert destillasjon
- tre produkttanker
- dieselkvalitet, alarmer, laboratorium og salg
- kontrollert råoljelasting og sikker tømming av off-spec produkt
- hopping og huking
- synlige væskenivåer, flowmarkører og maskinbevegelse
- byggeområde som låses opp etter første godkjente salg
- lesbar plassering, rotasjon, fjerning og trygg refusjon av tomt utstyr
- retningsbestemte OUT-til-IN-rør med validering og frakobling
- flere uavhengige prosesslinjer: tank → pumpe → ventil → varme → kolonne → tre tanker
- operasjonelle bygde tanker, pumper, manuelle ventiler, varmeenheter og kolonner
- massebalanse, tankkapasitet, backpressure og dieselkvalitet
- subsidierte oppstartsforsøk fram til godkjenning, deretter betalte batcher
- varig fullføring av Område 02 og batchrapport med utbytte, kvalitet og økonomi
- totrinns bekreftelse før produkter sendes til avfallshåndtering
- diagnostiserbar `LOW FLOW` når en bygd pumpe arbeider mot stengt ventil
- versjonert autosave av penger, progresjon, bygg, rør og prosessbeholdning
- ett oppstartsvalg for å fortsette eller bekreftet starte et nytt spill
- valg mellom Standard og Tung råolje etter oppstartskontrakten
- råoljespesifikke temperaturmål, fraksjoner, kvalitet og kontraktøkonomi
- trygg automatisk migrering av eldre 0.6-lagringer til Standard-råolje
- LS-201 lokalstasjon med live nivå-, temperatur- og flowinstrumenter
- fjernstyrt pumpe og temperaturmål med temperaturvern ved fjernstart
- fysisk dieselprøve fra aktiv produkttank før betalte batcher kan sendes
- LAB-101-analyse med volum, kvalitet, prosessavvik og trygg utsending
- flere uavhengige prosesslinjer og en fysisk Crude Feed Header for én delt
  råoljetank: velg rute A, B eller ingen rute før drift
- to tydelige leveringsordrer: Standard prioriterer diesel, mens Tung krever
  både tungfraksjon og en godkjent dieselprøve
- tre pumpetrinn på 5, 10 og 15 L/s etter godkjent oppstart, med en synlig
  avveiing mellom produksjonstid og temperaturmargin
- første vedlikeholdshendelse: vedvarende høy flow kan gi en diagnostiserbar
  filterrestriksjon som må undersøkes og repareres i felt
- Sour råolje med høy svovelstatus og en byggbar dieselbehandler som gjør
  off-spec diesel salgbar uten å endre materialmengden
- separate produktleveranser: Naphtha gir 5 kr/L, diesel beholder LAB-kravet,
  og tung rest gir 2 kr/L; hver levering tømmer bare riktig produkttank
- fysisk Product Routing Header for én produktstrøm: velg lagring A, B eller
  ingen rute før drift; valgt tank fylles alene og fullt lager stopper prosessen
- TIC-201 temperaturkontroll etter commissioning: velg MANUELL eller AUTO og
  la eksisterende varmeenhet holde et valgt temperaturmål
- operatøralarmer i LS-201: LOW FLOW, HIGH TEMPERATURE, HIGH LEVEL og TANK
  FULL peker på relevant utstyr uten å avsløre underliggende vedlikeholdsårsak
- LS-201 Refinery Operations: oversikt over alle komplette tog, sentraliserte
  alarmer og sikker fjernstyring av valgt pumpes temperaturmål og flowmål
- fysisk PG-101-generator og MCC-101-fordeling: pumper, heater-auxiliaries,
  LAB-101 og LS-201 krever tilgjengelig strøm, og faktisk last summeres i kW
- deterministisk MCC-overlast og supply-loss trip som stopper elektrisk utstyr
  sikkert; spilleren må gjenopprette generasjon og resette MCC før omstart
- byggbare PU-101-enheter fungerer som av/på-ekspansjonsgeneratorer i stedet
  for passiv kapasitet, uten individuelle kabler til hvert prosessobjekt
- kontekstuell strømfeedback: PG-101 viser generasjon, last og busstilstand;
  MCC-101 viser energisert/trippet buss, reserve og aktive laster; LS-201 viser
  PG/PU-status, generasjon, last, reserve og MCC-status uten et nytt panel
- fysisk Utilities Yard med `GF-101` dieseldagtank, `IA-101`
  instrumentluftkompressor, `CT-101` kjøletårn og `CWP-101` kjølevannspumpe
- deterministisk generatorforbruk basert på tomgang og elektrisk last; samme
  dieselbeholdning kan beholdes som strømbrensel eller sendes fra PD-101 for salg
- kanonisk dagtankoverføring som trekker inntil 25 L fra lagret diesel uten å
  duplisere produkt, og 40 L startbrensel som hindrer tidlig blackout-softlock
- instrumentluft og kjølevann som reelle 15/20 kW MCC-laster: TIC-201 sitt
  pneumatiske aktuatorsignal feiler stengt ved lufttap, mens manuelle ventiler
  beholder stillingen; CDU-produksjon blokkeres uten aktiv kjølevannssirkulasjon
- utility-alarmer, lokale statuser og en kompakt LS-201-oversikt som viser
  drivstoff, Instrument Air og Cooling Water sammen med eksisterende kraftdata
- funksjonelle CI-101 og PD-101 ved Harbor, med ett lokalt CI-skilt og reduserte
  onboarding-markører uten et permanent waypoint-system
- byggemodus prioriterer eksplisitte prosessporter foran maskinkroppen når
  spilleren sikter på en markert port
- eksplisitte pumpetilstander skiller `STOPPED`, `RUNNING | FLOW`,
  `RUNNING | BLOCKED/NO FEED` og kanoniske safety trips; normale blokkeringer
  beholder operatørens RUN-kommando og kan gjenoppta flow uten en kunstig restart
- Area 02-lagring godtar legitime route-eide kontrakter, tomme/uanalyserte/
  analyserte tanktilstander og utility recovery, samtidig som ukjente referanser,
  ugyldige enumverdier, NaN og infinity fortsatt avvises
- Pilot-tanknivåer bygges direkte fra kanonisk råolje- og produktbeholdning;
  salg bruker opp dieselbeholdningen uten å skjule usolgt lett/tung fraksjon
- én felles, toleransebasert massebalansediagnostikk verifiserer kanonisk
  beholdning, eksplisitte systemgrenser og definerte tap på tvers av Pilot,
  Area 02, CI/PD, CDU, VDU/FCC og generatorbrensel
- filterrestriksjon uttrykkes som avledet pumpekapabilitet, restriksjon/ΔP og
  oppnåelig flow; ingen avledet hydraulikk eller duplikatbeholdning lagres
- kanonisk Graybox World med 214 x 264 m spillbart land, Harbor/quay, naturlig
  0–10,5 m innlandsstigning, lokalt flate prosesspads, én hovedvei, korte
  servicegrener, tydelig shoreline recovery og live debug-koordinater
- fysisk integrert Pilot-start med kort ganglinje, monterte retnings-/prosesskilt,
  åpen overgang mot det senere hovedraffineriet og testet fresh-save
  produksjon, salg, bygging og reload/resume
- ett sammenhengende graybox-terreng uten koplanare gulvlag, gjenbrukbare
  fysiske skilt, tydelig materialhierarki og ikke-funksjonelle
  distriktslandemerker for menneskelig navigasjonstest

Alle objekter er foreløpig bygget av Godots primitive 3D-former. Det gjør at vi
kan teste gameplay før vi bruker tid på modeller og grafikk.

## Krav og oppstart

1. Installer Godot 4.7.1 stable eller en kompatibel nyere Godot 4-versjon.
2. Åpne Godot Project Manager.
3. Velg **Import** og åpne `project.godot` i denne mappen.
4. Trykk **F6/F5** eller knappen **Run Project**.

Prosjektet bruker Compatibility-rendereren og krever ingen eksterne pakker.

### Automatisert test

Alle kjernesystemene kan testes uten å åpne spillvinduet:

```sh
godot --headless --path . --script res://tests/process_model_test.gd
godot --headless --path . --script res://tests/process_network_test.gd
godot --headless --path . --script res://tests/building_system_test.gd
godot --headless --path . --script res://tests/built_refinery_model_test.gd
godot --headless --path . --script res://tests/physical_logistics_test.gd
godot --headless --path . --script res://tests/progression_test.gd
godot --headless --path . --script res://tests/main_built_loop_test.gd
godot --headless --path . --script res://tests/save_system_test.gd
godot --headless --path . --script res://tests/world_layout_test.gd
godot --headless --path . --script res://tests/pilot_world_integration_test.gd
```

## Lagring

Spillet bruker én lokal autosave. Viktige handlinger lagres etter en kort
forsinkelse, og en stille prosess-snapshot tas omtrent hvert tolvte sekund. Ved
neste oppstart kan spilleren velge `Enter` for å fortsette eller `N` for nytt
spill. Nytt spill må bekreftes og den gamle filen arkiveres før den erstattes.

Bygninger, rotasjon, rør, tankinnhold, temperatur, valgt pumpeflow, numerisk
kvalitet, eksplisitt analysestatus, kanonisk pumpetrip, penger, progresjon,
generatorbrensel, generatorstatus, MCC-trip og kanonisk IA/CW-maskin- og
tripstatus gjenopprettes. Pumper og faktisk
flow stoppes alltid ved lasting, slik at ingen prosess starter uten en bevisst
handling. Elektriske lastsummer beregnes på nytt fra kanonisk utstyrstilstand.
En siste kjent god backup beholdes, og
ukjent eller skadet lagringsdata avvises før den kan endre spillet.
Lagringer fra versjon 0.6 oppgraderes til dagens format og beholder eksisterende
batch som Standard-råolje uten å gi en ny batch eller bonus.
Utviklingslagringer der alle spillerbygg fortsatt ligger på den gamle v0.30.2-
flaten, flyttes samlet og deterministisk til den kanoniske Area 02-plattformen.
Relative posisjoner, rotasjoner, rør og stabile ID-er bevares; spilleren flyttes
ikke av denne Area 02-migreringen, og save-formatet er fortsatt versjon 2.
Spillerposisjoner som var gyldige i den gamle 600 x 400 m-verdenen eller den
større v0.31.0-verdenen, men ligger utenfor v0.31.1, flyttes trygt til Harbor
uten at prosess, økonomi eller konstruksjon forkastes.
CI/PD-transformer lagres ikke separat. Eldre format-2-lagringer gjenoppretter
derfor stabile prosess-ID-er og koblinger, men bygger nøyaktig én CI og PD ved de
nye Harbor-ankrene. Spillerbygget utstyr flyttes ikke; gamle koblinger får nye
rørvisualer fra Harbor-portene og kan fremstå som lange rette gråboksrør til de
kobles om.

## Styring

| Tast | Handling |
| --- | --- |
| WASD | Gå |
| Mus | Se |
| Shift | Løp |
| Space | Hopp |
| Ctrl eller C | Hold inne for å huke |
| E | Bruk eller inspiser utstyr; fyll GF-101, start/stopp generator og utilities, eller reset MCC |
| Q | Område 02: endre flowmål på pumpen du ser på |
| F | Område 02: undersøk eller rens en pumpe med driftsavvik |
| R | Pilot: ny batch. Område 02: trykk to ganger for sikker produkttømming |
| Enter | Send godkjent labbatch eller lukk batchrapport |
| 1 / 2 / 3 | Velg Standard, Tung eller Sour råolje når leveransevinduet er åpent |
| 1 / 2 / 3 | LS-201: start/stopp pumpe, endre temperaturmål eller flowmål |
| Esc | Frigjør musepekeren |
| F7 | Utvikling: vis/skjul koordinater, aktivt område og world bounds |
| F8 | Utvikling: vis/skjul fjerne graybox-arealmerker |

### Byggemodus

Byggemodus låses opp når den første dieselbatchen er solgt.

| Tast | Handling |
| --- | --- |
| B | Åpne eller lukke byggemodus |
| 1 / 2 / 3 / 4 / 5 | Velg tank, pumpe, manuell ventil, varmeenhet eller destillasjonskolonne |
| 6 | Velg dieselbehandler |
| 7 / 8 / 9 | Første linje: VDU-301, PU-101 og FCC-401 når de er synlige/ulåste |
| 7 / 8 / 9 / 0 / - | Etter første atmosfæriske produksjon: Crude Feed Header, Product Routing Header, VDU-301, PU-101 og FCC-401 |
| Q / E | Roter forhåndsvisningen |
| Venstreklikk | Plasser eller bekreft valgt handling |
| X | Bytt til fjerningsmodus; fjerning gir full refusjon |
| F | Velg utløp og deretter innløp for å lage prosessrør |
| G | Fjern røret på porten du ser på |
| V | Valider prosesslinjen og vis første feil |
| Høyreklikk | Avbryt gjeldende byggehandling |

Etter godkjent commissioning kan spilleren se på en varmeenhet og trykke `Q`
for å veksle mellom **MANUELL** og **AUTO**. `E` beholder det kjente
temperaturmålet. I AUTO sammenligner TIC-201 målt temperatur (PV) med målet
(SP) og justerer heater-utgangen. LS-201 viser PV, SP, modus og utgang; en
lukket feltventil gir fortsatt LOW FLOW og blokkerer automatisk varmeutgang.
LS-201 samler aktive alarmer fra hver komplette prosesslinje. Alarmen viser
symptom og utstyrstag; feltinspeksjon brukes fortsatt til å finne årsaken.

## Første produksjonsrunde

1. Gå til varmeenheten og trykk `E` til temperaturmålet er 200 °C.
2. Vent til anlegget nærmer seg riktig temperatur.
3. Åpne mateventilen.
4. Start pumpen.
5. Følg med på dieselvolum og kvalitet.
6. Stopp pumpen når du ønsker, eller behandle hele batchen.
7. Gå til pilottankens salgsterminal og trykk `E` når minst 200 liter diesel er godkjent.

Hvis man starter flowen før anlegget er varmt, blandes dårlig diesel inn i
tanken. Det er tilsiktet: spilleren lærer sammenhengen mellom temperatur,
utbytte og kvalitet gjennom handling.

Væskenivåene i tankene og de lysende markørene i rørene viser nå prosessen
direkte i 3D. Pumpens rotor og ventilhåndtak beveger seg når utstyret brukes.

## Første selvbygde raffineri

1. Selg godkjent pilotdiesel. Treningskontrakten garanterer minst 3 000 kr, slik
   at spilleren kan finansiere startanlegget og beholde litt driftskapital.
2. Trykk `B` og plasser fire tanker, tre pumper (inntak, prosess og dispatch),
   én manuell ventil, én varmeenhet og én kolonne.
3. Koble `tank OUT → pumpe IN`, `pumpe OUT → ventil IN`,
   `ventil OUT → varme IN` og `varme OUT → kolonne IN`.
4. Koble kolonnens `LETT`, `DIESEL` og `TUNG` til hver sin tank. Trykk `V` for
   en konkret valideringsmelding. Feil rør kan fjernes med `G`.
5. Trykk `B` for å avslutte bygging, motta råolje ved CI-101 og bygg fysisk
   inntak til kildetanken.
6. Prøv pumpen med PG-101 av. Den forklarer `START BLOCKED — NO POWER`; kontroller
   brensel i GF-101, start PG-101 og les last/reserve ved MCC-101.
7. Start IA-101 og CWP-101. De legger henholdsvis 15 og 20 kW til MCC-lasten.
   Deretter kan varmeenheten settes til 200 °C og prosesspumpen startes. Ventilen
   er stengt som standard, så pumpen gir `LOW FLOW` til spilleren finner og
   åpner ventilen.
8. Hvis IA-101 stopper, feiler TIC-201-aktuatoren stengt uten å flytte den
   manuelle ventilen. Hvis CWP-101 stopper, blokkeres CDU-kondensering. Begge
   krever bevisst utility- og prosessomstart.
9. Hvis MCC-101 tripper, les tripplast og årsak ved MCC-101. Reduser lasten
   eller start ekstra PU-101-generasjon, reset MCC-101 og start prosessutstyret
   bevisst igjen.
10. En subsidiert oppstartsbatch kan prøves igjen uten kostnad fram til første
   godkjente levering dersom produktet blir off-spec og tømmes sikkert.
11. Følg væskenivå, flow og kvalitet. Behold noe diesel og fyll GF-101, eller
   send produktet via PD-101; dette er nå en faktisk driftsøkonomisk avveiing.
   Ventilen kan stenge eller gjenopprette flow
   uten at væske skapes eller forsvinner. Stopp pumpen, ta dieselprøve ved tanken,
   analyser den ved `LAB-101`, og bruk produkttank → salgspumpe → PD-101 for fysisk
   dispatch. Salget sender produktbatchen ut og viser en batchrapport med
   faktisk råolje behandlet, fraksjoner, kvalitet, inntekt, kostnad og resultat.

Etter godkjent oppstart åpner `E` på en tom kildetank leveransevalget. Valget
bestemmer både råoljen og leveringsordren:

- **Dieselleveranse / Standard** koster 300 kr, har mål rundt 200 °C og krever
  minst 200 liter diesel med minst 90 % kvalitet.
- **Tung leveranse / Tung** koster 180 kr, har mål rundt 230 °C og krever minst
  600 liter tungfraksjon, minst 200 liter diesel og minst 90 % dieselkvalitet.
  En godkjent ordre gir en engangsbonus på 1 000 kr.

Råoljetypen låses til batchen. En ny type kan først velges når alle bygde tanker
er tomme og pumpen er stoppet. Batchrapporten viser valgt råolje, faktisk
snittemperatur, temperaturmål, dieselsalg, eventuell bonus, kostnad og resultat.

Alle Område 02-leveranser går fysisk via `PD-101`; LAB-101 brukes kun til
analyse. Spilleren må stoppe pumpen og trykke `E` på dieseltanken i den aktive
linjen for å ta en prøve. Før analyse vises
produktkvaliteten som `IKKE ANALYSERT`; en prøve fra en frakoblet tank kan ikke
brukes. Ved `LAB-101` vises faktisk dieselvolum og kvalitet mot
kontraktskravet, samt gjennomsnittlig prosesstemperatur og pumpeflow.
For Tung viser analysen dieselkvaliteten og tungfraksjonsmålet som to separate
krav. En god dieselprøve kan derfor være godkjent selv om ordren ennå trenger
mer tungfraksjon; videre produksjon krever deretter en ny prøve.

`Enter` lukker kun analyseresultatet; den godkjente tanken sendes fra `PD-101`.
OFF-SPEC-produkt beholdes og gir ingen inntekt. Ny produksjon, endret rørnett, tømming, salg eller
lasting gjør prøven ugyldig, og save/load krever alltid en ny fysisk prøve.

Etter den første godkjente Område 02-leveransen låses **LS-201** opp på
vestsiden av byggeområdet. Lokalstasjonen viser den aktive linjens kildenivå,
temperatur, faktisk flow, flowmål, dieselvolum, pumpe og ventil i sanntid. Tast
`1` fjernstarter eller stopper pumpen, `2` endrer varmeenhetens temperaturmål,
og `3` velger neste pumpetrinn.
Ved fjernstart sperres en kald eller overopphetet prosess, og temperaturvernet
stopper pumpen før mer materiale behandles dersom temperaturen forlater det
godkjente området. Ventilen er fortsatt feltbetjent, slik at `LOW FLOW` må
diagnostiseres og rettes ute i anlegget.

Etter den første godkjente Område 02-leveransen kan spilleren også se på den
bygde pumpen og trykke `Q` for å sykle `10 → 15 → 5 → 10 L/s`. Lav flow bruker
lengre tid, men tåler et større temperaturavvik. Høy flow produserer raskere,
men krever at temperaturen holdes nærmere råoljens mål. LAB-101 og
batchrapporten viser volumvektet gjennomsnittsflow, slik at et kvalitetsavvik kan
knyttes til både temperatur og valgt kapasitet. Første oppstart og pilotanlegget
beholder fast 10 L/s.

Område 02 kan drive flere uavhengige prosesslinjer. Når én råoljetank skal
mate to komplette tog, kobler spilleren tanken til en **Crude Feed Header** og
kobler `OUT A` og `OUT B` til hver sin pumpe. Trykk `E` på headeren for å velge
`A → B → ingen rute`. Valgt pumpevei får all råolje; bytte er blokkert mens en
pumpe fra samme kilde går. Headeren deler aldri flow automatisk og velger aldri
en reservevei på egen hånd. Headeren vises først etter den første atmosfæriske
produksjonen, når flere tog faktisk kan være et forståelig behov.

For utvidet produktlagring kan et kolonneutløp eller HT-201 kobles til en
**Product Routing Header**. Koble `OUT A` og `OUT B` til kompatible tanker og
trykk `E` på headeren for å velge `A → B → ingen tank`. Bytte krever at den
aktuelle pumpen er stoppet. Bare valgt tank mottar nytt produkt; et fullt valgt
lager stopper prosessen i stedet for å flytte eller duplisere materialet.
Den vises på samme sene routing-steg som Crude Feed Header.

Hvis en batch blir off-spec, forklarer
terminalen at `R` kan sende bygde produkter til sikker avfallshåndtering uten
betaling. Spilleren må stoppe pumpen og trykke `R` to ganger innen fire
sekunder. Dette gir en gjenopprettingsvei uten gratis råolje eller penger, men
beskytter en godkjent batch mot ett utilsiktet tastetrykk.

## Prosjektstruktur

```text
CrudeWorks/
├── project.godot
├── scenes/
│   └── main.tscn
├── scripts/
    ├── built_refinery_model.gd
    ├── build_controller.gd
    ├── buildable_unit.gd
    ├── crude_contract_catalog.gd
    ├── equipment_catalog.gd
    ├── graybox_sign.gd
    ├── interactive_unit.gd
    ├── lab_analysis_panel.gd
    ├── main.gd
    ├── player.gd
    ├── process_model.gd
    ├── process_network.gd
    ├── process_port.gd
    ├── save_system.gd
    ├── world_builder.gd
    └── world_layout.gd
└── tests/
    ├── built_refinery_model_test.gd
    ├── building_system_test.gd
    ├── main_built_loop_test.gd
    ├── process_model_test.gd
    ├── process_network_test.gd
    ├── pilot_world_integration_test.gd
    ├── save_system_test.gd
    └── world_layout_test.gd
```
