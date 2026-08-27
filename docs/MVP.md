# CrudeWorks – MVP 0.1

> Historical MVP record. It describes the early Pilot hypothesis, not the
> current v0.28.2 implementation or priority. Use `README.md`, `ROADMAP.md` and
> `AGENTS.md` for current guidance.

## Hypotesen vi tester

Det er morsomt og forståelig å betjene en synlig prosesslinje når hver handling
gir tydelig respons i maskiner, instrumenter og produktkvalitet.

## Spillerens løkke

```text
Inspiser → still inn varme → åpne ventil → start pumpe
    → observer flow og temperatur → vurder kvalitet → selg
```

## Avgrensning

Denne versjonen har en fast prosesslinje. Fri plassering av maskiner og kobling
av rør kommer først etter at denne løkken er testet. Første versjon bruker heller
ikke realistisk fluiddynamikk eller full kjemisk destillasjon.

## Spillregler

- Pumpen leverer maksimalt 10 L/s.
- Flow krever både aktiv pumpe, åpen ventil og råolje på tanken.
- Varmeenheten kan settes til av, 170, 200 eller 230 °C.
- Høyest dieselkvalitet oppnås rundt 200 °C.
- For lav temperatur gir mest tungolje og dårlig diesel.
- For høy temperatur gir mer lettprodukt og redusert dieselkvalitet.
- Minst 200 liter diesel og 90 % blandet kvalitet kreves for salg.

Verdiene er pedagogiske spillregler og ikke en fullstendig modell av et virkelig
raffineri.

## Godkjenningskriterier for 0.1

- Spilleren kan fullføre oppdraget uten en tekstbasert opplæring.
- Det er lett å se om pumpen, ventilen og varmen er aktive.
- En feil rekkefølge kan gi OFF-SPEC-produkt.
- Spilleren kan forklare hvorfor produktet ble godkjent eller avvist.
- En runde tar omtrent 10–20 minutter etter senere balansering.

## Neste avgjørelse etter spilltest

Hvis løkken fungerer, bygger vi modulær plassering og kobling av utstyr. Hvis den
ikke fungerer, forbedrer vi tempo, respons og feilsøking før prosjektet vokser.
