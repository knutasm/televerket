---
title: dbt cheat sheet
aside: false
---

# dbt cheat sheet

## Select-syntaks

### Velg modeller

| Kommando | Beskrivelse |
|---|---|
| `dbt run` | Kjør alle modeller i prosjektet |
| `dbt run -s stg_crm__customers` | Kjør én spesifikk modell |
| `dbt run -s staging` | Kjør alle modeller i en mappe |
| `dbt run -s tag:daily` | Velg modeller med et bestemt tag |

### Grafsyntaks

| Kommando | Beskrivelse |
|---|---|
| `dbt run -s +mart_customer_360` | Modellen og alle oppstrøms-avhengigheter |
| `dbt run -s mart_customer_360+` | Modellen og alle nedstrøms-avhengigheter |
| `dbt run -s +mart_customer_360+` | Hele grafen i begge retninger |
| `dbt run -s 1+stg_crm__customers` | Maks 1 nivå oppstrøms |
| `dbt run -s stg_crm__customers+1` | Maks 1 nivå nedstrøms |

### Kombinere og ekskludere

| Kommando | Beskrivelse |
|---|---|
| `dbt run -s staging intermediate` | Mellomrom = union (kjør begge) |
| `dbt run -s +mart_customer_360 --exclude staging` | Ekskluder en gruppe fra et bredere utvalg |
| `dbt run -s source:crm+` | Alt nedstrøms fra en bestemt source |

> `--select` / `-s` fungerer likt på tvers av `dbt run`, `dbt test`, `dbt build` og `dbt compile`.

## Sources

### Freshness

| Kommando | Beskrivelse |
|---|---|
| `dbt source freshness` | Sjekk freshness på alle registrerte kilder |
| `dbt source freshness -s source:crm` | Freshness kun for én source-gruppe |
| `dbt source freshness -o freshness.json` | Skriv resultatet til fil |

### Grafsyntaks for sources

| Kommando | Beskrivelse |
|---|---|
| `dbt run -s source:billing` | Modeller direkte avhengig av source-gruppen |
| `dbt run -s source:billing+` | Alle nedstrøms-modeller fra source |
| `dbt run -s source:billing.billing_invoices+` | Nedstrøms fra én spesifikk kildetabell |

### Referanseformat i SQL

| Syntaks | Beskrivelse |
|---|---|
| `` {{ source('crm', 'crm_customers') }} `` | Referer til en kildetabell — brukes kun i staging |
| `` {{ ref('stg_crm__customers') }} `` | Referer til en annen dbt-modell |
| `` {{ ref('other_project', 'mart_customers') }} `` | Cross-project ref |

> `ref()` og `source()` bygger linjeavstamningsgrafen dbt bruker til `--select`, docs og CI. Hardkodede tabellnavn bryter grafen.

## Testing

### Kjøre tester

| Kommando | Beskrivelse |
|---|---|
| `dbt test` | Kjør alle tester i prosjektet |
| `dbt test -s stg_crm__customers` | Tester for én modell |
| `dbt test -s staging` | Alle tester i en mappe |
| `dbt test -s source:crm` | Tester (inkl. freshness) for en source |
| `dbt test --store-failures` | Skriv feilende rader til tabeller i DB |
| `dbt build` | Kjør run + test + seed i rekkefølge |
| `dbt build -s +mart_customer_360` | Build hele grafen med tester underveis |

### Innebygde generiske tester

| Test | Sjekker |
|---|---|
| `not_null` | Ingen null-verdier i kolonnen |
| `unique` | Alle verdier er unike |
| `accepted_values` | Verdier finnes i en definert liste |
| `relationships` | Fremmednøkkel finnes i en annen modell |

```yaml
- name: customer_id
  tests:
    - not_null
    - unique
- name: status
  tests:
    - accepted_values:
        values: ['active', 'churned', 'suspended']
        # quote: false → sammenlign uten quotes
- name: contract_id
  tests:
    - relationships:
        to: ref('stg_crm__customers')
        field: customer_id   # PK i den andre modellen
```

## Dokumentasjon

| Kommando | Beskrivelse |
|---|---|
| `dbt docs generate` | Bygg dokumentasjonssiden fra YAML og skjema |
| `dbt docs serve` | Åpne dokumentasjonssiden i nettleseren |
| `dbt compile` | Valider at alle modeller kompilerer uten å kjøre dem |
| `dbt parse` | Les og valider hele prosjektet (raskere enn compile) |

### Doc-blokker

```jinja
{%- docs customer_id %}
Unik kundeidentifikator. Primærnøkkel.
{% enddocs %}
```

```yaml
description: '{% raw %}{{ doc("customer_id") }}{% endraw %}'
```

## Nyttige flagg

| Flagg | Beskrivelse |
|---|---|
| `--select` / `-s` | Velg noder |
| `--exclude` | Ekskluder noder |
| `--target` / `-t` | Bytt miljø (dev/prod) |
| `--profiles-dir` | Angi profiles.yml-sti |
| `--vars` | Send variabler inn i run |
| `--full-refresh` | Tving rebuilding av inkrementelle modeller |
| `--store-failures` | Lagre feilrader i DB |
| `--no-partial-parse` | Tving full parsing av prosjektet |
| `--threads N` | Antall parallelle tråder |
| `--warn-error` | Gjør advarsler til feil |
| `--defer` | Bruk prod-manifestet for ikke-valgte noder |
| `--favor-state` | Bruk prod-artefakter der det er mulig |
