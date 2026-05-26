---
title: Staging-modeller og materialisering
---

# Staging-modeller og materialisering

## Hva er en staging-modell?

En staging-modell er en **1-til-1-representasjon av én kildetabell**, renset men ikke tolket.

Det er det eneste stedet i prosjektet der vi:

- Gir kolonner konsistente navn
- Caster datatyper til riktige typer
- Løser opp kildesystemets tekniske særegenheter

Staging-modeller inneholder **ingen forretningslogikk** og **ingen joins**.

```
stg_crm__customers.sql   ← én modell per kildetabell
stg_crm__contracts.sql
stg_billing__invoices.sql
stg_billing__payments.sql
```

## Hva hører hjemme i staging?

| Hører hjemme | Hører ikke hjemme |
|---|---|
| Kolonnenavn → standard navn | Joins mellom tabeller |
| `VARCHAR` → `DATE`, `NUMERIC` | Beregninger på tvers av rader |
| JSON-utpakking (enkle, flate felt) | Forretningsregler og flagg |
| Filtrering av tekniske metadata-rader | Aggregering |
| `COALESCE` for enkle standardverdier | Historisering / SCD-logikk |

## Navngiving i staging

Standardiser kolonnenavn på tvers av alle staging-modeller:

```sql
select
    -- rename: fjern kildesystemets særegenheter
    custID              as customer_id,
    full_name           as customer_name,

    -- cast: gi kolonnen riktig type
    cast(created_at as date)                        as created_date,
    safe_cast(monthly_fee as numeric)               as monthly_fee_eur,
    parse_date('%Y%m%d', invoice_date)              as invoice_date,

    -- beholdes som de er
    email,
    phone,
    status

from {{ source('crm', 'crm_customers') }}
```

`safe_cast` i BigQuery returnerer `null` i stedet for å feile ved ugyldige verdier, nyttig under utforsking.

## Hva er materialisering?

Materialisering bestemmer **hvordan dbt skriver modellen til databasen**.

| Type | Hva dbt gjør | Typisk bruk |
|---|---|---|
| `view` | Oppretter en view — ingen data lagres | Staging, enkle transformasjoner |
| `table` | Materialiserer hele resultatet som en tabell | Tunge intermediate-modeller |
| `incremental` | Legger til / oppdaterer kun nye rader | Store faktatabeller, events |
| `ephemeral` | Kompileres inn som en CTE — finnes ikke i DB | Gjenbrukbare mellomsteg |

Staging-modeller er nesten alltid `view`. De er tynne og brukes som grunnlag for neste lag, ikke som sluttpunkt.

## Materialisering i YAML-konfigurasjon

Materialisering settes i YAML, ikke i SQL-filen.

```yaml
# models/staging/_staging.yml
models:
  - name: stg_crm__customers
    config:
      materialized: view
```

Eller på mappenivå i `dbt_project.yml`:

```yaml
models:
  mitt_prosjekt:
    staging:
      +materialized: view     # gjelder alle modeller i staging/
    intermediate:
      +materialized: table
    marts:
      +materialized: table
```

`+` foran en nøkkel betyr at den arves nedover i mappestrukturen.

## View vs. table

En `view` beregnes på nytt hver gang den spørres. Det er greit når:
- Modellen er rask å kjøre
- Den brukes sjelden eller av andre modeller, ikke sluttbrukere
- Du vil alltid se ferske data

Bytt til `table` når:
- Modellen tar lang tid å kjøre og refereres ofte
- Downstream-modeller bygger på den og du vil ikke gjøre jobben om igjen
- Sluttbrukere spør direkte mot modellen

> Staging er nesten alltid `view`. Intermediate og mart er ofte `table`. Start med `view` og bytt når du har grunn til det.

## Datasett: staging

Vi skal bygge én staging-modell per kildetabell:

| Staging-modell | Kilde | Hva som må fikses |
|---|---|---|
| `stg_crm__customers` | `crm_customers` | `custID` → rename, JSON-felt, `created_at` cast |
| `stg_crm__contracts` | `crm_contracts` | `monthly_fee` VARCHAR → NUMERIC |
| `stg_billing__invoices` | `billing_invoices` | `InvoiceID` → rename, YYYYMMDD → DATE, `amount_eur` → NUMERIC |
| `stg_billing__payments` | `billing_payments` | Ryddig — minimalt å gjøre |
| `stg_network__service_activations` | `network_service_activations` | JSON `device_info` — diskusjon: her eller intermediate? |
| `stg_network__incidents` | `network_incidents` | `customer_ref` — behold navn eller rename? |
| `stg_catalog__products` | `catalog_products` | Ryddig — seed, bruker `ref()` ikke `source()` |
