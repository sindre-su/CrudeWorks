# CrudeWorks

**Prototypeversjon: 0.5 – manuell flowkontroll og feilsøking**

En liten 3D-prototype der spilleren driver et forenklet pilotraffineri. Første mål
er å behandle 1 000 liter råolje og selge minst 200 liter diesel med 90 % eller
bedre kvalitet.

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
- en logisk prosesslinje: tank → pumpe → ventil → varme → kolonne → tre tanker
- operasjonelle bygde tanker, pumper, manuelle ventiler, varmeenheter og kolonner
- massebalanse, tankkapasitet, backpressure og dieselkvalitet
- gratis oppstartsbatch, betalte råoljebatcher og salg som tømmer produktet
- varig fullføring av Område 02 og batchrapport med utbytte, kvalitet og økonomi
- totrinns bekreftelse før produkter sendes til avfallshåndtering
- diagnostiserbar `LOW FLOW` når en bygd pumpe arbeider mot stengt ventil

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
godot --headless --path . --script res://tests/main_built_loop_test.gd
```

## Styring

| Tast | Handling |
| --- | --- |
| WASD | Gå |
| Mus | Se |
| Shift | Løp |
| Space | Hopp |
| Ctrl eller C | Hold inne for å huke |
| E | Bruk eller inspiser utstyr |
| R | Pilot: ny batch. Område 02: trykk to ganger for sikker produkttømming |
| Enter | Lukk batchrapport |
| Esc | Frigjør musepekeren |

### Byggemodus

Byggemodus låses opp når den første dieselbatchen er solgt.

| Tast | Handling |
| --- | --- |
| B | Åpne eller lukke byggemodus |
| 1–4 | Velg tank, pumpe, varmeenhet eller destillasjonskolonne |
| 5 | Velg manuell ventil |
| Q / E | Roter forhåndsvisningen |
| Venstreklikk | Plasser eller bekreft valgt handling |
| X | Bytt til fjerningsmodus; fjerning gir full refusjon |
| F | Velg utløp og deretter innløp for å lage prosessrør |
| G | Fjern røret på porten du ser på |
| V | Valider prosesslinjen og vis første feil |
| Høyreklikk | Avbryt gjeldende byggehandling |

## Første produksjonsrunde

1. Gå til varmeenheten og trykk `E` til temperaturmålet er 200 °C.
2. Vent til anlegget nærmer seg riktig temperatur.
3. Åpne mateventilen.
4. Start pumpen.
5. Følg med på dieselvolum og kvalitet.
6. Stopp pumpen når du ønsker, eller behandle hele batchen.
7. Gå til LAB / SALG og trykk `E` når minst 200 liter diesel er godkjent.

Hvis man starter flowen før anlegget er varmt, blandes dårlig diesel inn i
tanken. Det er tilsiktet: spilleren lærer sammenhengen mellom temperatur,
utbytte og kvalitet gjennom handling.

Væskenivåene i tankene og de lysende markørene i rørene viser nå prosessen
direkte i 3D. Pumpens rotor og ventilhåndtak beveger seg når utstyret brukes.

## Første selvbygde raffineri

1. Selg godkjent pilotdiesel. Treningskontrakten garanterer minst 3 000 kr, slik
   at spilleren kan finansiere startanlegget og har råd til én recovery-batch
   dersom den gratis oppstartsbatchen blir off-spec.
2. Trykk `B` og plasser fire tanker, én pumpe, én manuell ventil, én varmeenhet
   og én kolonne.
3. Koble `tank OUT → pumpe IN`, `pumpe OUT → ventil IN`,
   `ventil OUT → varme IN` og `varme OUT → kolonne IN`.
4. Koble kolonnens `LETT`, `DIESEL` og `TUNG` til hver sin tank. Trykk `V` for
   en konkret valideringsmelding. Feil rør kan fjernes med `G`.
5. Trykk `B` for å avslutte bygging, og `E` på kildetanken for å laste den ene
   gratis oppstartsbatchen.
6. Sett varmeenheten til 200 °C, vent til den er varm, og start pumpen. Ventilen
   er stengt som standard, så pumpen gir `LOW FLOW` til spilleren finner og
   åpner ventilen.
7. Følg væskenivå, flow og kvalitet. Ventilen kan stenge eller gjenopprette flow
   uten at væske skapes eller forsvinner. Stopp pumpen og selg godkjent diesel ved
   `LAB / SALG`. Salget sender produktbatchen ut og viser en batchrapport med
   faktisk råolje behandlet, fraksjoner, kvalitet, inntekt, kostnad og resultat.

Senere råoljebatcher koster 300 kr. Hvis en batch blir off-spec, forklarer
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
    ├── equipment_catalog.gd
    ├── interactive_unit.gd
    ├── main.gd
    ├── player.gd
    ├── process_model.gd
    ├── process_network.gd
    └── process_port.gd
└── tests/
    ├── built_refinery_model_test.gd
    ├── building_system_test.gd
    ├── main_built_loop_test.gd
    ├── process_model_test.gd
    └── process_network_test.gd
```
