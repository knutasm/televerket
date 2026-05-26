---
title: Intermediate-modeller
---

# Intermediate-modeller

## Hva er et intermediate-lag?

Intermediate-modeller kombinerer og beriker staging-modeller. De forbereder entiteter for konsumpsjon, uten å ta stilling til hvem som konsumerer dem.

Typisk innhold:
- Joins mellom staging-modeller fra ulike kildesystemer
- Utpakking av JSON-felt som er for komplekse for staging
- Deduplisering av rader fra kilden
- Tekniske avledninger som gjelder entiteten generelt (f.eks. er kontrakten aktiv?)

```
int_customers__enriched.sql       ← CRM + kontrakter
int_customers__activations.sql
int_invoices__with_payments.sql
```

> Navnekonvensjonen `int_<entitet>__<beskrivelse>` grupperer modeller etter entitet, ikke etter kilde.

## Staging vs. intermediate vs. mart

```
stg_crm__customers          stg_crm__contracts
        │                           │
        └──────────┬────────────────┘
                   ▼
        int_customers__enriched
                   │
                   ▼
        mart_customer_360
```

En **staging**-modell: *hva finnes i denne kildetabellen?*

En **intermediate**-modell: *hva vet vi om denne entiteten, uavhengig av hvem som spør?*

En **mart**-modell: *hva trenger dette spesifikke bruksområdet?*

## Hva skiller intermediate fra mart?

**Intermediate** inneholder logikk som er **universell for entiteten**:
- En kunde har én aktiv kontrakt (alltid sant, ikke konsumentspesifikt)
- En betaling er en duplikat hvis samme faktura er betalt to ganger (alltid sant)
- Kontraktsvarighet i dager (en egenskap ved kontrakten, ikke ved rapporten)

**Mart** inneholder logikk som er **spesifikk for konsumenten**:
- Livstidsverdi i euro (KPI for churn-teamet)
- Antall hendelser siste 90 dager (metrikk for nettverksdashboard)
- `is_at_risk`-flagg basert på betalingshistorikk (forretningsregel for én rapport)

> Det vanlige rådet er at «forretningslogikk hører hjemme i mart». Det stemmer for **konsumentspesifikk** logikk. Intermediate håndterer logikk som ville blitt duplisert på tvers av mange marts hvis den ikke ble løftet opp.

## JSON-utpakking: staging eller intermediate?

Dette er et designvalg, ikke et fasitsvar. To hensyn styrer beslutningen:

**Pakk ut i staging når:**
- JSON-feltet er flatt og enkelt
- Feltene brukes direkte som kolonner uten videre transformasjon
- Utpakkingen ikke avhenger av andre modeller
- Eksempel: `address` i `crm_customers`

**Pakk ut i intermediate når:**
- JSON-feltet er komplekst eller delvis null
- De utpakkede feltene må kombineres med data fra andre modeller for å gi mening
- Utpakket innhold er bare relevant i en spesifikk kontekst
- Eksempel: `preferences` og `device_info`: meningsfull først når vi vet hvem kunden er

> Staging handler om kilden. Intermediate handler om entiteten.

## JSON-utpakking i BigQuery

```sql
-- Flat utpakking med json_value()
json_value(preferences, '$.language')        as preferred_language,
json_value(preferences, '$.paperless')       as paperless_billing,
json_value(preferences, '$.marketing_opt_in') as marketing_opt_in,

-- Nested — device_info fra network_service_activations
json_value(device_info, '$.make')            as device_make,
json_value(device_info, '$.model')           as device_model,
json_value(device_info, '$.os')              as device_os,
json_value(device_info, '$.imei')            as device_imei,
```

`json_value()` returnerer alltid `STRING`. Cast eksplisitt hvis du trenger en annen type:

```sql
cast(json_value(preferences, '$.paperless') as bool) as paperless_billing
```

Tomme JSON-objekter `{}` gir `null` på alle `json_value()`-kall. Håndter dette med `COALESCE` eller en test.

## Tags i YAML

Tags lar deg gruppere modeller på tvers av mapper, nyttig for selektiv kjøring og dokumentasjon.

```yaml
models:
  - name: int_customers__enriched
    config:
      materialized: table
      tags:
        - customer
        - daily
    columns:
      - name: customer_id
        description: Unik kundeidentifikator. Primærnøkkel.
      - name: preferred_language
        description: Foretrukket språk fra kundens preferanseprofil. Null hvis ikke satt.
```

Bruk tags til å kjøre et utvalg:

```bash
dbt run --select tag:customer
dbt build --select tag:daily
```

## Kolonnenivå-beskrivelser i YAML

Beskrivelser på kolonnenivå fyller dokumentasjonssiden med innhold.

```yaml
models:
  - name: int_customers__enriched
    description: >
      Én rad per kunde, beriket med aktiv kontraktinformasjon og
      utpakkede preferanser fra CRM.
    columns:
      - name: customer_id
        description: Primærnøkkel. Arvet fra stg_crm__customers.
      - name: contract_status
        description: >
          Status på kundens siste aktive kontrakt.
          Null for kunder uten noen kontrakt (f.eks. status pending).
      - name: monthly_fee_eur
        description: Månedlig totalbeløp på tvers av alle aktive kontrakter.
```

> Skriv beskrivelsen slik at en ny kollega forstår kolonnen uten å se SQL-en.

## Deduplisering

`billing_payments` inneholder dupliserte betalingsrader, der samme faktura er betalt to ganger.

En vanlig tilnærming med `ROW_NUMBER()`:

```sql
with payments_deduped as (
    select
        *,
        row_number() over (
            partition by invoice_ref
            order by paid_on
        ) as rn
    from {{ ref('stg_billing__payments') }}
)

select * from payments_deduped
where rn = 1
```

Spørsmål å tenke på:
- Hvilken rad beholder du: den første eller siste?
- Bør du filtrere i intermediate, eller eksponere `rn` til mart-laget?
- Burde det også finnes en **test** som fanger dette problemet?

## Datasett: intermediate

Modellene vi skal bygge i denne blokken:

| Intermediate-modell | Hva den gjør |
|---|---|
| `int_customers__enriched` | Kobler `stg_crm__customers` med siste aktive kontrakt, pakker ut `preferences` |
| `int_customers__activations` | Kobler kunder med siste nettverksaktivering og pakker ut `device_info` |
| `int_billing__invoice_settlement` | Fakturaer beriket med betalingsstatus — faktura er primærentiteten, betaling er et oppslag |
| `int_network__incidents_enriched` | Kobler hendelser med kundeinformasjon |

> `crm_contracts` og `catalog_products` inneholder allerede historikk med `valid_from` / `valid_to` fra kildesystemet; staging eksponerer det som det er.
