# CrudeWorks – byggesystem 0.3

> Historical implementation record. The directed process network and functional
> Area 02 simulation are now implemented; use `ARCHITECTURE.md`, `ROADMAP.md`
> and `AGENTS.md` for current behavior and Graybox priorities.

**Status: implementert og klar for spilltest**

## Mål

Spilleren skal kunne plassere en liten prosesslinje selv og forstå om utstyret er
riktig koblet før produksjonen starter. Systemet skal fortsatt være enkelt nok
til at en feil kan finnes ved å følge røret fra tank til tank.

## Første omfang

Byggemodus skal støtte:

- `B` for å åpne og lukke byggemodus
- en enkel meny med tank, pumpe, varmeenhet og destillasjonsenhet
- gjennomsiktig forhåndsvisning før plassering
- plassering på et grovt rutenett
- `Q` og `E` for rotasjon i byggemodus
- venstre museknapp for plassering
- høyre museknapp eller `Esc` for å avbryte
- markerte inn- og utløpsporter
- rør mellom kompatible porter
- grønn markering for gyldig plassering og rød for blokkert plassering

## Teknisk rekkefølge

1. Flytt data for maskinstørrelse, pris og porter ut av `main.gd`.
2. Lag én gjenbrukbar `BuildableUnit` for alle maskintyper.
3. Lag en `BuildController` som håndterer forhåndsvisning og plassering.
4. Lag `ProcessPort` for innløp og utløp.
5. Lag et prosessnett som finner sammenhengende utstyr fra råoljetank til
   produkttank.
6. La dagens `ProcessModel` motta kapasitet og tilgjengelighet fra nettet.
7. Behold den faste pilotlinjen som opplæringsnivå og bruk fri bygging i neste
   område.

Punkt 1–4 og den visuelle delen av punkt 5 er nå implementert. Neste milepæl
lar det sammenkoblede nettet beregne faktisk flow og kapasitet; rørene i 0.3 er
foreløpig visuelle forbindelser.

## Viktig designvalg

Vi erstatter ikke den fungerende pilotlinjen. Den blir nivå 1 og lærer spilleren
rekkefølgen. Fri bygging låses opp etter første godkjente salg. Dette gir en
naturlig overgang fra betjening til problemløsing og konstruksjon.

## Godkjenningskriterier

- En pumpe som står feil vei gir ikke flow.
- En manglende rørkobling er tydelig synlig.
- Spilleren kan flytte eller fjerne feilplassert utstyr uten å miste penger.
- En korrekt linje kan behandle samme 1 000-liters batch som pilotanlegget.
- Eksisterende oppdrag og prosesstester fortsetter å fungere.
