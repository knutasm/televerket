---
layout: home

hero:
  name: "Televerket dbt-kurs"
  tagline: Et praktisk kurs i dbt
  image:
    src: televerket.webp
    alt: ETL vs ELT

features:
  - title: Sesjon 1 — Den moderne datastakken
    details: Motivasjon, hva er dbt, oppsett og første modell. Jaffle-shop som introduksjonsprosjekt.
    link: /sesjon-1/
  - title: Sesjon 2 — Sources og staging
    details: Kilderegistrering, freshness, staging-modeller, materialisering, intermediate-lag og testing.
    link: /sesjon-2/
  - title: Sesjon 3 — Jinja, makroer og pakker
    details: Jinja-templating, makroer med flerdatabasestøtte, dbt-pakkeøkosystemet og elementary.
    link: /sesjon-3/
  - title: Makroer — eksempler og øvelser
    details: Praktiske makroeksempler og øvelser for sentralisert logikk, dynamisk SQL og miljøstyring.
    link: /makroer/
---

## Om datasettet

Vi jobber med data fra et fiktivt telecom-selskap. Selskapet kjører fire interne systemer som alle produserer egne data, og jobben din er å bygge et velstrukturert dbt-prosjekt på toppen av dem.

Kildedataene er lastet inn i BigQuery og tilgjengelig i `raw`-datasettet. dbt-prosjektet leser derfra og bygger modeller i et eget datasett.

### Kildesystemer

| System | Tabeller |
|---|---|
| CRM | `crm_customers`, `crm_contracts` |
| Fakturering | `billing_invoices`, `billing_payments` |
| Nettverk | `network_service_activations`, `network_incidents` |
| Produktkatalog | `catalog_products` |

### Lag-arkitektur

```
raw (BigQuery-kildedatasett)
│
├── Staging     — 1:1 med kildetabell; standardiser navn og typer
├── Intermediate — kombiner og berik; forretningslogikk
└── Marts        — analytics-klare, emneorienterte tabeller
```

### Kjente datakvalitetsproblemer

Kildedataene har 13 bevisste feil som du vil oppdage og håndtere underveis — inkonsistente kolonnenavn, strengkodede beløp, YYYYMMDD-formaterte datoer, JSON-blobs, null-verdier, duplikater og mer.
