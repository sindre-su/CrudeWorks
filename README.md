# CrudeWorks

**Prototypeversjon: 0.3 – første byggesystem**

En liten 3D-prototype der spilleren driver et forenklet pilotraffineri. Første mål
er å behandle 1 000 liter råolje og selge minst 200 liter diesel med 90 % eller
bedre kvalitet.

## Status

Første spillbare «vertical slice» er under bygging. Prototypen inneholder:

- førstepersons bevegelse og interaksjon
- råoljetank, pumpe, ventil og varmeenhet
- forenklet temperaturbasert destillasjon
- tre produkttanker
- dieselkvalitet, alarmer, laboratorium og salg
- omstart av batch uten å starte spillet på nytt
- hopping og huking
- synlige væskenivåer, flowmarkører og maskinbevegelse
- byggeområde som låses opp etter første godkjente salg
- plassering, rotasjon, fjerning og full refusjon av utstyr
- manuelle OUT-til-IN-rør mellom bygde maskiner

Alle objekter er foreløpig bygget av Godots primitive 3D-former. Det gjør at vi
kan teste gameplay før vi bruker tid på modeller og grafikk.

## Krav og oppstart

1. Installer Godot 4.7.1 stable eller en kompatibel nyere Godot 4-versjon.
2. Åpne Godot Project Manager.
3. Velg **Import** og åpne `project.godot` i denne mappen.
4. Trykk **F6/F5** eller knappen **Run Project**.

Prosjektet bruker Compatibility-rendereren og krever ingen eksterne pakker.

### Automatisert test

Prosessmodellen kan testes uten å åpne spillvinduet:

```sh
godot --headless --path . --script res://tests/process_model_test.gd
godot --headless --path . --script res://tests/building_system_test.gd
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
| R | Nullstill og last en ny batch |
| Esc | Frigjør musepekeren |

### Byggemodus

Byggemodus låses opp når den første dieselbatchen er solgt.

| Tast | Handling |
| --- | --- |
| B | Åpne eller lukke byggemodus |
| 1–4 | Velg tank, pumpe, varmeenhet eller destillasjonskolonne |
| Q / E | Roter forhåndsvisningen |
| Venstreklikk | Plasser eller bekreft valgt handling |
| X | Bytt til fjerningsmodus; fjerning gir full refusjon |
| F | Velg utløp og deretter innløp for å lage prosessrør |
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

## Prosjektstruktur

```text
CrudeWorks/
├── project.godot
├── scenes/
│   └── main.tscn
└── scripts/
    ├── interactive_unit.gd
    ├── main.gd
    ├── player.gd
    └── process_model.gd
└── tests/
    ├── building_system_test.gd
    └── process_model_test.gd
```
