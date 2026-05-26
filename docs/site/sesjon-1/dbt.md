---
title: dbt
---

# dbt

## Hva er dbt
- Et transformasjonsrammeverk som kjører SQL SELECT-setninger
- Finner ut kjørerekkefølgen basert på avhengigheter mellom modeller (DAG)
- Pakker automatisk inn SELECT i `CREATE TABLE` eller `CREATE VIEW`
- Legger til testing, dokumentasjon og lineage

## Hva dbt ikke er

- Et ingestionsverktøy: henter ikke data fra kilder
- En loader: rå data må allerede ligge i målet
- En planlegger: kjøres av deg eller en orkestrator

## Ønskede egenskaper
- Idempotens: En operasjon kan gjenomføres 1, 2 eller 100 ganger uten at det påvirker resultatet utover første
- Deklarativ: Man beskriver ønsket tilstand, systemet tar seg av hvordan man kommer dit
  - Motsatt av Imperativ: Man beskriver nøyaktig prosedyre, steg for steg
- Lesbare endringer og enkel triage: "det gikk til h.. på mandag kl 14, hvilken endring ble gjort?"
- Enkelt å forstå hva som påvirkes
- Trygt samarbeid
- Enkel tilbakerulling
- Standardisering
- Automatisering
- Testbarhet
- Dokumentasjon

## Programvareutviklingsvinkelen

Modeller er `.sql`-filer i en mappe:

- De bor i Git: historikk, diff, blame
- De blir gjennomgått i pull requests
- Du ser nøyaktig hva som endret seg, når og av hvem
- Hele prosjektet kan bygges på nytt i et ferskt miljø på kort tid

## Vanlig støttefunksjonalitet
- Versjonskontroll: Alle datamodeller definert som kode, hvor alle versjoner er lagret i et repo
- CICD: Automatiserer prosessen med å ta modeller fra `utvikling` -> `test` -> `prod`
  - Isolerte miljøer
  - Testing
  - Linting
  - Opprydding
- Orkestrering: Hva skal kjøre når, starte jobber
