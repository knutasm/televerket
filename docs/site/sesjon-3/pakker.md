---
title: dbt-pakke-økosystemet
---

# dbt-pakke-økosystemet

## Hva er en dbt-pakke?

En **pakke** er et dbt-prosjekt du henter inn som et bibliotek: makroer, modeller og tester som andre har skrevet og vedlikeholder.

I stedet for å skrive standardverktøy selv, importerer du dem fra pakker som allerede er testet på tvers av mange prosjekter.

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.3.0
  - package: dbt-labs/dbt_codegen
    version: 0.13.1
  - package: elementary-data/elementary
    version: 0.15.2
```

```bash
dbt deps    # laster ned pakker til dbt_packages/
```

## dbt Package Hub

Alle offisielle pakker er publisert på **hub.getdbt.com**.

Noen pakker å kjenne til:

| Pakke | Hva den gir |
|---|---|
| `dbt_utils` | Generelle makroer og tester |
| `dbt_codegen` | Genererer YAML-boilerplate automatisk |
| `elementary` | Datakvalitetsovervåkning og rapportering |
| `dbt_date` | Datefunksjoner med tidssonebehandling |
| `audit_helper` | Sammenlign to modeller rad for rad |
| `dbt_expectations` | Rikt sett med datakvalitetstester |

## `packages.yml` i dette prosjektet

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.3.0
  - package: dbt-labs/dbt_codegen
    version: 0.13.1
  - package: dbt-labs/dbt_date
    version: 0.10.2
  - package: dbt-labs/audit_helper
    version: 0.12.0
  - package: elementary-data/elementary
    version: 0.15.2
```

```bash
dbt deps
```

Pakkefilene lastes ned til `dbt_packages/`. Legg denne mappen i `.gitignore`; den regenereres av `dbt deps` og skal ikke versjonskontrolleres.

## `dbt_utils`: oversikt

Den mest brukte pakken i økosystemet. Den gir makroer og tester for de vanligste mønstrene.

**Noen sentrale makroer:**

| Makro | Hva den gjør |
|---|---|
| `star()` | SELECT alle kolonner fra en modell unntatt et utvalg |
| `generate_series()` | Generer en rekke tall eller datoer |
| `pivot()` | Roter rader til kolonner |
| `union_relations()` | UNION ALL på en liste med modeller |

**Noen sentrale tester:**

| Test | Hva den sjekker |
|---|---|
| `expression_is_true` | Vilkårlig SQL-uttrykk evaluerer til `true` |
| `unique_combination_of_columns` | Kombinasjon av kolonner er unik |
| `not_empty_string` | Streng er ikke tom |
| `at_least_one` | Minst én rad er ikke null |

## `dbt_utils.expression_is_true`

Den mest fleksible testen. Den lar deg sjekke et vilkårlig SQL-uttrykk direkte i YAML:

```yaml
models:
  - name: stg__billing_invoices
    columns:
      - name: amount_eur
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0 or status = 'credited'"
      - name: due_date
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= invoice_date"
```

Testen feiler hvis `expression` evaluerer til `false` for én eller flere rader.

Erstatter mange singulære tester.

## `dbt_utils.unique_combination_of_columns`

Sjekker at en **kombinasjon** av kolonner er unik, spesielt nyttig for modeller med en kompositt (sammensatt) primærnøkkel:

```yaml
models:
  - name: int_billing__invoice_settlement
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - invoice_id
            - customer_id
```

Den innebygde `unique`-testen sjekker kun én kolonne om gangen.

Nyttig for faktura-betalings-modeller, kontraktshistorikk og andre modeller med sammensatte nøkler.

## `dbt_utils.star()`

Velg alle kolonner unntatt noen få, uten å skrive ut hele listen manuelt:

```sql
select
    {{ dbt_utils.star(
        from=ref('int_customers__enriched'),
        except=['_loaded_at', '_row_hash']
    ) }}
from {{ ref('int_customers__enriched') }}
```

Kompileres til en eksplisitt `SELECT kolonne1, kolonne2, ...`-liste.

Nyttig i mart-modeller der du vil eksponere nesten alt fra en intermediate-modell uten å liste opp alle kolonner.

## `dbt_codegen`: generer boilerplate

`dbt_codegen` sparer tid på det kjedelige: å skrive YAML manuelt for eksisterende tabeller.

```bash
# Generer source-YAML for tabeller som finnes i databasen
dbt run-operation generate_source \
  --args '{"schema_name": "raw", "table_names": ["crm_customers", "crm_contracts"]}'

# Generer modell-YAML med alle kolonner fra en eksisterende modell
dbt run-operation generate_model_yaml \
  --args '{"model_names": ["stg__crm_customers", "int_customers__enriched"]}'
```

Outputen printes til terminalen. Kopier inn i riktig YAML-fil og legg til beskrivelser.

## `generate_source` i praksis

```yaml
# Output fra generate_source:
sources:
  - name: raw
    tables:
      - name: crm_customers
        columns:
          - name: custID
            description: ""
          - name: full_name
            description: ""
          - name: email
            description: ""
          - name: address
            description: ""
          - name: preferences
            description: ""
```

Start her, og legg til `description:`, `loaded_at_field` og `freshness` etter behov.

## `generate_model_yaml` i praksis

```yaml
# Output fra generate_model_yaml:
models:
  - name: stg__crm_customers
    description: ""
    columns:
      - name: customer_id
        description: ""
      - name: customer_name
        description: ""
      - name: email
        description: ""
      - name: created_date
        description: ""
```

Alle kolonner fra modellen, inkludert de du nettopp har omdøpt og castet. Legg til tester og beskrivelser.

> `generate_model_yaml` krever at modellen allerede er bygget i databasen. Kjør `dbt run` først.

## elementary: datakvalitetsovervåkning

**elementary** overvåker dataene dine over tid, ikke bare om én test passerer akkurat nå, men om noe er i ferd med å endre seg.

Elementary gir:

- **Anomalideteksjon**: varsler hvis radantall, nullandel eller verdidistribusjon endrer seg uventet
- **Testhistorikk**: sporer om tester passerer eller feiler over tid
- **HTML-rapport**: oversikt over hele prosjektets datakvalitet

I motsetning til statiske terskler (`warn_after: 24 timer`) **lærer elementary** hva som er normalt basert på historikk.

## elementary: installasjon og oppsett

Legg til i `packages.yml` og `dbt_project.yml`:

```yaml
# dbt_project.yml
models:
  elementary:
    +schema: elementary
    +materialized: incremental
```

```bash
dbt deps
dbt run --select elementary     # bygger elementarys sporingsmodeller
```

```bash
pip install 'elementary-data[bigquery]'   # eller duckdb / snowflake / postgres
edr report                                # generer HTML-rapport
```

Elementary lagrer testresultater og modellmetadata i egne tabeller i databasen.

## elementary: anomalitester i YAML

```yaml
models:
  - name: stg__billing_invoices
    tests:
      - elementary.volume_anomalies:
          timestamp_column: invoice_date
      - elementary.freshness_anomalies:
          timestamp_column: invoice_date
    columns:
      - name: amount_eur
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - null_count
                - average
                - max
      - name: status
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - null_count
```

## elementary: rapport

`edr report` genererer en lokal HTML-rapport:

```bash
edr report
```

Rapporten viser:

- Testresultater over tid: grønn/gul/rød per test per kjøring
- Radantall per modell per kjøring
- Skjemaendringer som har skjedd automatisk
- Lineage-visualisering

Nyttig for daglig overvåkning, post-mortem-analyse og som dokumentasjon for stakeholders som vil forstå datakvaliteten uten å lese SQL.

## Velge og vedlikeholde pakker

Ikke alle pakker passer alle prosjekter. Noen vurderinger:

| Spørsmål | Implikasjon |
|---|---|
| Er pakken aktivt vedlikeholdt? | Sjekk siste release-dato på GitHub |
| Støtter den dine databaser? | BigQuery, Snowflake og Postgres har ulike dialekter |
| Er versjonen festet? | Aldri `version: latest` i produksjon |
| Hvem eier `dbt deps` i CI? | Pakkeversjoner må oppdateres bevisst, ikke automatisk |

Pakker er avhengigheter. Oppdater dem som kode, ikke som infrastruktur.

## Oppsummering

**Jinja:**
- `{{ }}` setter inn en verdi, `{% %}` er kontrollstruktur, `{# #}` er kommentar
- `{% set %}`, `{% if %}`, `{% for %}` er de tre du bruker oftest

**Makroer:**
- Definer én gang i `macros/`, kall overalt
- `adapter.dispatch` gir flerdatabasestøtte med samme kall
- Generiske tester er makroer med signaturen `test_<navn>(model, column_name)`

**Pakker:**
- Konfigureres i `packages.yml`, installeres med `dbt deps`
- `dbt_utils`: tester og makroer for vanlige mønstre
- `dbt_codegen`: generer YAML-boilerplate fra eksisterende tabeller og modeller
- `elementary`: anomalideteksjon og historisk testovervåkning
