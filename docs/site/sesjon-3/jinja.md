---
title: Jinja og templating i dbt
---

# Jinja og templating i dbt

## Jinja er sentralt i dbt

Hver `{{ }}` i SQL-filene dine er Jinja:

```sql
select * from {{ ref('stg_crm__customers') }}
select * from {{ source('crm', 'crm_customers') }}
```

dbt bruker Jinja til å gjøre SQL **dynamisk**. Malen kompileres til vanlig SQL før den sendes til databasen.

Jinja brukes i Python-webrammeverk, konfigurasjonssystemer og mange andre steder. I dbt er det den mekanismen som gjør makroer, pakker og `ref()` mulig.

## To typer Jinja-blokker

| Syntaks | Navn | Brukes til |
|---|---|---|
| `{{ ... }}` | Uttrykkblokk | Sett inn en verdi i teksten |
| `{% ... %}` | Setningsblokk | Kontrollstrukturer: `if`, `for`, `set` |
| `{# ... #}` | Kommentarblokk | Fjernes helt ved kompilering |

```sql
-- Uttrykkblokk — setter inn et tabellnavn
select * from {{ ref('stg_crm__customers') }}

-- Kommentar — vises ikke i kompilert SQL
{# Kunder uten kontrakt holdes i resultatet #}

-- Setningsblokk — setter inn ingenting, men påvirker logikken
{% set status_codes = ['active', 'suspended', 'terminated'] %}
```

## Variabler

`{% set %}` definerer en variabel. `{{ }}` setter inn verdien:

```sql
{% set kolonne = 'contract_status' %}

select
    customer_id,
    {{ kolonne }}
from {{ ref('int_customers__enriched') }}
```

Variabler kan holde tekst, tall, lister og ordbøker:

```sql
{% set grense = 1000 %}
{% set statuser = ['active', 'suspended', 'terminated'] %}
{% set config = {"materialized": "table"} %}
```

For nå er det nok å vite at `{% set %}` definerer og `{{ }}` bruker.

## Betingelser

`{% if %}` og `{% endif %}` omslutter kode som bare genereres under visse betingelser:

```sql
{% if target.name == 'dev' %}
    limit 1000
{% endif %}
```

`target.name` er et innebygd dbt-objekt med informasjon om miljøet du kjører mot.

Med `{% else %}`:

```sql
{% if target.name == 'prod' %}
    where status = 'active'
{% else %}
    limit 1000
{% endif %}
```

## `target`-objektet

dbt eksponerer informasjon om kjøremiljøet via `target`:

| Variabel | Eksempel | Beskrivelse |
|---|---|---|
| `target.name` | `'dev'`, `'prod'` | Profilnavn i `profiles.yml` |
| `target.schema` | `'dbt_dittnavn'` | Ditt personlige schema |
| `target.database` | `'my_project'` | BigQuery-prosjekt / Snowflake-database |
| `target.type` | `'bigquery'`, `'duckdb'` | Databasetype |

Nyttig for å skrive logikk som oppfører seg ulikt i dev vs. prod, uten å endre SQL-filene.

## Løkker

`{% for %}` itererer over en liste:

```sql
{% set status_codes = ['active', 'suspended', 'terminated'] %}

select
    customer_id
    {% for s in status_codes %}
    , sum(case when status = '{{ s }}' then 1 else 0 end) as {{ s }}_count
    {% endfor %}
from {{ ref('stg_crm__customers') }}
group by 1
```

`loop.last` er `true` på siste iterasjon, nyttig for å unngå kommaer:

```sql
{% if not loop.last %},{% endif %}
```

## Filtre

Jinja har innebygde **filtre** som bearbeider en verdi med `|`:

```sql
{{ '  aktiv  ' | trim }}           -- 'aktiv'  (fjerner mellomrom)
{{ 'aktiv' | upper }}              -- 'AKTIV'
{{ kolonne_liste | join(', ') }}   -- 'a, b, c'
```

Du finner filtre i flere makroer, som `generate_schema_name`:

```sql
{{ custom_schema_name | trim }}
```

Filtre lenkes med `|` og evalueres fra venstre mot høyre.

## Kompilert SQL

dbt transformerer Jinja til SQL i to steg:

1. **Jinja-kompilering**: malen evalueres, Jinja byttes ut med vanlig SQL
2. **SQL-kjøring**: den genererte SQL-en sendes til databasen

Se hva som faktisk sendes til databasen:

```bash
dbt compile --select stg__billing_invoices
```

Kompilert SQL ligger i `target/compiled/`. Svært nyttig ved feilsøking: hvis noe feiler, les den kompilerte SQL-en, ikke malen.
