---
title: Makroer
---

# Makroer

## Hva er en makro?

En **makro** er en gjenbrukbar Jinja-funksjon. I stedet for å kopiere den samme SQL-logikken i flere modeller, definerer du den én gang i `macros/` og kaller den der du trenger den.

`billing_invoices` har to YYYYMMDD-kolonner:

```sql
-- uten makro — samme logikk på begge kolonner
strptime(invoice_date, '%Y%m%d')::date as invoice_date,
strptime(due_date, '%Y%m%d')::date     as due_date,
```

Med en makro:

```sql
{{ parse_yyyymmdd('invoice_date') }} as invoice_date,
{{ parse_yyyymmdd('due_date') }}     as due_date,
```

Slik trenger du bare å endre logikken ett sted, dersom den skal oppdateres.

## Definere en makro

En makrofil i `macros/` bruker `{% macro %}` og `{% endmacro %}`:

```sql
-- macros/parse_yyyymmdd.sql
{% macro parse_yyyymmdd(column_name) %}
    strptime({{ column_name }}, '%Y%m%d')::date
{% endmacro %}
```

- `column_name` er argumentet, sendes inn når makroen kalles
- Hoveddelen er vanlig SQL med innslag av Jinja
- Makroen genererer SQL-tekst: den finnes ikke i databasen som en funksjon

## Kalle en makro

```sql
-- models/staging/stg__billing_invoices.sql
with source as (
    select * from {{ source('billing', 'billing_invoices') }}
),
renamed as (
    select
        cast(InvoiceID as varchar)                  as invoice_id,
        customer_id,
        {{ parse_yyyymmdd('invoice_date') }}         as invoice_date,
        {{ parse_yyyymmdd('due_date') }}             as due_date,
        safe_cast(amount_eur as numeric)             as amount_eur,
        status
    from source
)
select * from renamed
```

dbt kompilerer makroen til `strptime(invoice_date, '%Y%m%d')::date`

## Argumenter og standardverdier

Makroer kan ha standardverdier på argumenter med `=`:

```sql
{% macro parse_yyyymmdd(column_name, format='%Y%m%d') %}
    strptime({{ column_name }}, '{{ format }}')::date
{% endmacro %}
```

Med standardformat (dekker de fleste tilfellene):

```sql
{{ parse_yyyymmdd('invoice_date') }}
```

Med overstyrt format, for kildesystemer som bruker et annet mønster:

```sql
{{ parse_yyyymmdd('created_at', format='%d.%m.%Y') }}
```

Standardverdier gjør makroer fleksible uten at kalleren alltid trenger å spesifisere alt.

## Flerdatabasestøtte med `adapter.dispatch`

`strptime()` er DuckDB-syntaks. BigQuery og Snowflake bruker andre funksjoner.

`adapter.dispatch` lar dbt velge riktig implementasjon basert på databasen:

```sql
{% macro parse_yyyymmdd(column_name) %}
    {{ return(adapter.dispatch('parse_yyyymmdd')(column_name)) }}
{% endmacro %}

{% macro default__parse_yyyymmdd(column_name) %}
    to_date({{ column_name }}, 'YYYYMMDD')
{% endmacro %}

{% macro duckdb__parse_yyyymmdd(column_name) %}
    strptime({{ column_name }}, '%Y%m%d')::date
{% endmacro %}

{% macro bigquery__parse_yyyymmdd(column_name) %}
    parse_date('%Y%m%d', {{ column_name }})
{% endmacro %}
```

## `adapter.dispatch`: navnekonvensjon

dbt leter etter implementasjoner med prefikset `<adapter>__`:

```sql
{% macro default__makronavn() %}     -- fallback for alle databaser
{% macro duckdb__makronavn() %}      -- brukes kun på DuckDB
{% macro bigquery__makronavn() %}    -- brukes kun på BigQuery
{% macro snowflake__makronavn() %}   -- brukes kun på Snowflake
{% macro postgres__makronavn() %}    -- brukes kun på Postgres
```

SQL-en i makroen `parse_yyyymmdd('invoice_date')` like overalt. dbt tar seg av å sende riktig dialekt til riktig database.

## Eksempel: `sample`

`TABLESAMPLE SYSTEM` lar databasen returnere en tilfeldig andel av datablokker i tabellen uten å lese hele tabellen.
Det er nyttig for å begrense kostnader under utvikling i BQ, hvor man betaler for antall bytes _scannet_ (ikke returnert). `LIMIT` begrenser bare hvor mange rader du får som _output_, ikke hvor mange som scannes.

Ulempen er at resultatet er **ikke-deterministisk**: du får ulike rader hver kjøring. Det gjør det vanskeligere å reprodusere feil og kan skjule bugs som bare dukker opp med bestemte dataverdier.

Noen databaser støtter native sampling; andre er enklest å begrense med `LIMIT`. Med `adapter.dispatch` og to parametere, `fraction` og `limit`, håndterer makroen begge:

```sql
{% macro sample(fraction=10, limit=1000) %}
    {{ return(adapter.dispatch('sample')(fraction, limit)) }}
{% endmacro %}

{% macro default__sample(fraction, limit) %}
    limit {{ limit }}
{% endmacro %}

{% macro bigquery__sample(fraction, limit) %}
    tablesample system ({{ fraction }} percent)
{% endmacro %}

{% macro snowflake__sample(fraction, limit) %}
    sample ({{ fraction }})
{% endmacro %}

{% macro duckdb__sample(fraction, limit) %}
    using sample {{ fraction }} percent
{% endmacro %}
```

Kallet er likt overalt; makroen velger riktig syntaks:

```sql
select *
from {{ source('billing', 'billing_invoices') }}
{% if target.name != 'prod' %}{{ sample() }}{% endif %}
```

## `generate_schema_name`: overstyring av dbt-standard

dbt har innebygde makroer som kan overstyres ved å definere en makro med samme navn. `generate_schema_name` styrer hvordan skjemanavn settes:

```sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {% set default_schema = target.schema %}

    {% if node.resource_type == 'seed' %}
        {{ custom_schema_name | trim }}
    {% elif custom_schema_name is none %}
        {{ default_schema }}
    {% elif target.name == 'prod' %}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {% else %}
        {{ default_schema }}
    {% endif %}
{% endmacro %}
```

I dette prosjektet: kun i produksjon får schemas prefiket; i dev samles alt i ett schema.

## Makroer som generiske tester

Generiske tester (som `unique` og `not_null`) er egentlig makroer. Du kan skrive dine egne:

```sql
-- macros/test_is_positive.sql
{% macro test_is_positive(model, column_name) %}
    select *
    from {{ model }}
    where {{ column_name }} <= 0
{% endmacro %}
```

Bruk i YAML på samme måte som innebygde tester:

```yaml
columns:
  - name: amount_eur
    tests:
      - is_positive
```

dbt feiler testen hvis makroen returnerer én eller flere rader.

## Når bør du lage en makro?

Makroer løser et problem. De introduserer ikke kompleksitet uten grunn.

**Lag en makro når:**
- Samme SQL-mønster gjentas i tre (vanlig tommelfingerregel) eller flere modeller
- Logikken er databasespesifikk og du støtter flere databaser
- Du overstyrer dbt-standardlogikk (som `generate_schema_name`)
- Du vil lage gjenbrukbare generiske tester

**Ikke lag en makro når:**
- Det er engangsbruk
- En CTE eller en view løser problemet like bra
- Den gjør modellkoden vanskeligere å lese
- Makroen du planlegger å lage, gjør for mange ting

Utgangspunktet for design av makroer bør være det samme som for funksjoner i programmering for øvrig: den bør gjøre kun en ting, og ikke ha [sideeffekter](https://www.marktinderholt.com/software%20development/2024/12/10/avoid-side-effects.html).
