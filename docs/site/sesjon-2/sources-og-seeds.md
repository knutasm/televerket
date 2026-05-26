---
title: Sources og seeds
---

# Sources og seeds

## Hva er en source i dbt?

En **source** er en tabell som dbt ikke eier. Den lastes inn av et annet system.

Ved å registrere kilder i dbt får du:

- Mulighet til å referere til dem med `{{ source() }}` i stedet for hardkodede tabellnavn
- Automatisk linjeavstamning fra kilde til mart
- Freshness-sjekker som varsler når data er for gammelt

```yaml
# models/sources.yml (filnavn. Et hvilket som helst gyldig finavn er ok)
sources:
  - name: crm # <- Navn på kilden
    schema: raw # <- Schema for kilden. Valgfritt; hvis ikke oppgitt brukes name
    tables:
      - name: crm_customers # <- navnet på tabellen i kilden
      - name: crm_contracts
```

## `{{ source() }}` i en modell

I stedet for å skrive `raw.crm_customers` direkte i SQL bruker du:

```sql
select *
from {{ source('crm', 'customers') }}
```

dbt peker til riktig database og schema basert på YAML-konfigurasjonen, slik at hvis schema-navnet endrer seg, endrer du det ett sted.

## Freshness

dbt kan sjekke hvor ferske kildedataene er ved å lese en tidsserie-kolonne.

```yaml
sources:
  - name: crm
    schema: raw
    loaded_at_field: _loaded_at # <- Hvilken kolonne som brukes til å angi rekkefølge
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    tables:
      - name: crm_customers
      - name: crm_contracts
        freshness:
          warn_after: {count: 6, period: hour}   # override per tabell
```

Kjøres med:

```bash
dbt source freshness
```

## Freshness: hva betyr terskelverdiene?

`warn_after` og `error_after` definerer hvor gammelt det nyeste innlastede datapunktet kan være.

- **warn**: dbt rapporterer en advarsel, jobben fortsetter
- **error**: dbt feiler: nyttig i en pipeline der downstream-kjøring ikke gir mening på foreldet data

Til diskusjon
- Hva er et realistisk freshness-SLA for hvert kildesystem?
- Bør CRM og billing ha samme terskel?
- Hva skjer i helger og helligdager?

## Hva er et seed?

Et **seed** er en CSV-fil som dbt laster inn som en tabell i databasen.

Passer for små, stabile referansedata som ikke finnes i noe kildesystem, for eksempel en mapping-tabell eller en produktkatalog.

```
dbt-project/
└── seeds/
    └── catalog_products.csv
```

Lastes inn med:

```bash
dbt seed
```

Deretter kan andre modeller referere til den med `{{ ref('catalog_products') }}`.

## Seeds i YAML

Seeds kan beskrives og konfigureres i YAML på samme måte som modeller.

```yaml
# seeds/_seeds.yml
seeds:
  - name: catalog_products
    description: >
      Produktkatalog med alle abonnementstyper selskapet tilbyr.
      Inneholder historiske produktversjoner med valid_from / valid_to.
    columns:
      - name: product_code
        description: Unik produktkode. Kan gjenbrukes på tvers av versjoner.
      - name: valid_to
        description: Null for gjeldende produkter. Satt for utgåtte versjoner.
```

Du kan også overstyre kolonnetyper direkte i YAML:

```yaml
    config:
      column_types:
        monthly_fee_eur: float64
        valid_from: date
```

## Kilder

Vi har data fra fire kildesystemer, alle i BigQuery-datasettet `raw`:

| System | Tabeller |
|---|---|
| CRM | `crm_customers`, `crm_contracts` |
| Fakturering | `billing_invoices`, `billing_payments` |
| Nettverk | `network_service_activations`, `network_incidents` |
| Produktkatalog | `catalog_products` |

I dette blokket registrerer vi kildene og gjør oss kjent med dataene.
