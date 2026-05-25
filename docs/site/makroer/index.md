---
title: Makroer — eksempler og øvelser
description: Praktiske makroeksempler og øvelser for sentralisert logikk, dynamisk SQL og miljøstyring
---

# Makroer — eksempler og øvelser

## 1. Vedlikeholdbarhet: sentraliser forretningslogikk

Bruk denne typen makro når forretningslogikk kan endre seg, og du vil unngå at samme regel ligger spredt i mange modeller.

<table>
<tr>
<th>Makro</th>
<th>Bruk i modell</th>
</tr>
<tr>
<td>

```jinja
-- macros/is_successful_order.sql

{% macro is_successful_order(status_column) %}
    case
        when {{ status_column }} in ('paid', 'shipped', 'completed') then true
        else false
    end
{% endmacro %}
```

</td>
<td>

```sql
select
    order_id,
    order_status,
    {{ is_successful_order('order_status') }} as is_successful_order

from {{ ref('stg_orders') }}
```

</td>
</tr>
</table>

**Fordel vist:** Hvis `delivered` senere også skal regnes som en vellykket ordre, trenger vi bare å endre makroen.

---

## 2. Dynamisk SQL-generering: generer repeterte aggregeringer

Bruk denne typen makro når SQL-en følger et repeterende mønster og kan genereres fra en liste.

<table>
<tr>
<th>Makro</th>
<th>Bruk i modell</th>
</tr>
<tr>
<td>

```jinja
-- macros/sum_by_status.sql

{% macro sum_by_status(amount_column, status_column, statuses) %}
    {%- for status in statuses %}
        sum(
            case
                when {{ status_column }} = '{{ status }}'
                    then {{ amount_column }}
                else 0
            end
        ) as {{ status }}_amount
        {%- if not loop.last %},{% endif %}
    {%- endfor %}
{% endmacro %}
```

</td>
<td>

```sql
select
    customer_id,
    {{ sum_by_status(
        amount_column='amount',
        status_column='order_status',
        statuses=['paid', 'refunded', 'cancelled']
    ) }}

from {{ ref('fct_orders') }}
group by customer_id
```

</td>
</tr>
</table>

**Fordel vist:** Makroen genererer repeterende SQL basert på inputverdier, ved hjelp av en Jinja-løkke.

---

## 3. Miljøstyrt logikk: begrens skannet datamengde i BigQuery

Bruk denne typen makro når du vil at modeller skal kjøre raskere og billigere i utviklings- og testmiljøer, uten å endre produksjonslogikken.

I BigQuery er et filter på en partisjonskolonne eller datokolonne vanligvis mer nyttig enn `limit`, fordi det kan redusere mengden data som skannes.

<table>
<tr>
<th>Makro</th>
<th>Bruk i modell</th>
</tr>
<tr>
<td>

```jinja
-- macros/dev_date_filter.sql

{% macro dev_date_filter(date_column, dev_days=7, test_days=30) %}
    {% set environment = env_var('DBT_ENVIRONMENT', 'dev') %}

    {% if environment == 'dev' %}
        and {{ date_column }} >= timestamp_sub(current_timestamp(), interval {{ dev_days }} day)

    {% elif environment == 'test' %}
        and {{ date_column }} >= timestamp_sub(current_timestamp(), interval {{ test_days }} day)

    {% elif environment == 'prod' %}
        {# Ingen ekstra filtrering i produksjon. #}

    {% else %}
        {{ exceptions.raise_compiler_error(
            "Ugyldig verdi for DBT_ENVIRONMENT: " ~ environment
            ~ ". Forventet én av: dev, test, prod."
        ) }}
    {% endif %}
{% endmacro %}
```

</td>
<td>

```sql
select
    order_id,
    customer_id,
    order_status,
    order_created_at,
    amount

from {{ ref('fct_orders') }}

where 1 = 1
{{ dev_date_filter('order_created_at', dev_days=7, test_days=30) }}
```

</td>
</tr>
</table>

**Fordel vist:** Makroen gjør utviklings- og testkjøringer billigere og raskere i BigQuery ved å filtrere datagrunnlaget, ikke bare begrense antall rader som vises.

---

# Øvelser: Jinja-makroer i dbt Core

Disse øvelsene bygger videre på eksemplene med:

- sentralisert forretningslogikk
- dynamisk SQL-generering
- miljøstyrt logikk for BigQuery

Øvelsene er laget for data engineers som er nye til dbt-makroer, men kjent med SQL, modellering og dataplattformer.

---

## Øvelse 1: Lag en enkel makro for betalingsmetode

### Mål

Lag en makro som definerer om en betaling skal regnes som en **kortbetaling**.

### Oppgave

Opprett filen:

```text
macros/is_card_payment.sql
```

Lag en makro med navnet:

```jinja
is_card_payment(payment_method_column)
```

Makroen skal returnere et SQL-uttrykk som gir:

- `true` hvis betalingsmetoden er `'credit_card'`
- `false` ellers

Tabellen `payments` har følgende kolonner:

```text
id
order_id
payment_method
amount
```

`payment_method` kan ha disse verdiene:

```text
credit_card
coupon
bank_transfer
gift_card
```

Bruk makroen i en modell, for eksempel:

```sql
select
    id,
    order_id,
    payment_method,
    amount,
    {{ is_card_payment('payment_method') }} as is_card_payment

from {{ ref('payments') }}
```

### Krav

- Makroen skal ta kolonnenavn som argument.
- Makroen skal generere et gyldig `case when`-uttrykk.
- Kjør `dbt compile` og inspiser SQL-en som genereres i `target/compiled`.

### Refleksjon

- Hvorfor kan dette være bedre enn å skrive `case when` direkte i modellen?
- Hva må endres hvis også `'bank_transfer'` skal regnes som en elektronisk betaling?
- Er makronavnet tydelig nok?

---

## Øvelse 2: Gjør makroen mer fleksibel med valgfrie argumenter

### Mål

Utvid en makro slik at den kan brukes til å klassifisere verdier i ulike kolonner.

### Oppgave

Lag en makro med navnet:

```jinja
is_value_in(column_name, values, default_value=false)
```

Makroen skal generere et uttrykk som returnerer `true` hvis verdien i `column_name` finnes i listen `values`.

Tabellen `stores` har kolonnen `name`, som kan ha disse verdiene:

```text
Philadelphia
Brooklyn
Chicago
San Francisco
New Orleans
Los Angeles
```

Eksempel på bruk:

```sql
select
    id,
    name,

    {{ is_value_in(
        column_name='name',
        values=['Brooklyn', 'Chicago', 'Philadelphia']
    ) }} as is_northern_store

from {{ ref('stores') }}
```

Forventet kompilert logikk:

```sql
case
    when name in ('Brooklyn', 'Chicago', 'Philadelphia') then true
    else false
end
```

### Krav

- Makroen skal ta en liste av verdier.
- Makroen skal bruke en Jinja-løkke eller strengbygging for å lage `in (...)`.
- Makroen skal støtte `default_value=true` eller `default_value=false`.
- Kjør `dbt compile` og sjekk at SQL-en er lesbar.

### Refleksjon

- Når blir en fleksibel makro nyttig?
- Når blir den for generell?
- Ville en mer domenespesifikk makro, for eksempel `is_northern_store`, vært lettere å forstå?

---

## Øvelse 3: Generer repeterte aggregeringer

### Mål

Lag en makro som genererer flere likeartede SQL-uttrykk basert på en liste.

### Oppgave

Opprett filen:

```text
macros/count_by_store_name.sql
```

Lag en makro med navnet:

```jinja
count_by_store_name(store_name_column, store_names)
```

Makroen skal generere én tellekolonne per butikk.

Tabellen `stores` har følgende kolonner:

```text
id
name
opened_at
tax_rate
```

Eksempel på bruk:

```sql
select
    date_trunc(opened_at, month) as opened_month,

    {{ count_by_store_name(
        store_name_column='name',
        store_names=['Philadelphia', 'Brooklyn', 'Chicago']
    ) }}

from {{ ref('stores') }}
group by opened_month
```

Forventet kompilert SQL:

```sql
sum(case when name = 'Philadelphia' then 1 else 0 end) as philadelphia_count,
sum(case when name = 'Brooklyn' then 1 else 0 end) as brooklyn_count,
sum(case when name = 'Chicago' then 1 else 0 end) as chicago_count
```

### Krav

- Makroen skal bruke en `for`-løkke.
- Den skal ikke generere komma etter siste kolonne.
- Kolonnenavnene skal være basert på butikknavnene.
- Butikknavn med mellomrom skal gi gyldige kolonnenavn, for eksempel `san_francisco_count`.
- Kjør `dbt compile` og kontroller at SQL-en er syntaktisk korrekt.

### Ekstra utfordring

Legg til et valgfritt argument:

```jinja
prefix=''
```

Slik at kolonnene kan hete for eksempel:

```text
store_philadelphia_count
store_brooklyn_count
store_chicago_count
```

### Refleksjon

- Er den genererte SQL-en lett å lese?
- Hvor mange butikker må til før makroen blir mer nyttig enn håndskrevet SQL?
- Hva må makroen gjøre for å håndtere navn som `San Francisco`, `New Orleans` og `Los Angeles`?

---

## Øvelse 4: Lag en BigQuery-vennlig miljømakro

### Mål

Lag en makro som gjør utviklings- og testkjøringer billigere i BigQuery ved å redusere datamengden som skannes.

### Oppgave

Opprett filen:

```text
macros/filter_recent_data_by_environment.sql
```

Lag en makro med navnet:

```jinja
filter_recent_data_by_environment(date_column, dev_days=7, test_days=30)
```

Makroen skal bruke miljøvariabelen:

```text
DBT_ENVIRONMENT
```

Regler:

- Hvis `DBT_ENVIRONMENT=dev`, filtrer til siste 7 dager.
- Hvis `DBT_ENVIRONMENT=test`, filtrer til siste 30 dager.
- Hvis `DBT_ENVIRONMENT=prod`, ikke legg til ekstra filter.
- Hvis miljøvariabelen har en annen verdi, stopp kompileringen med en tydelig feilmelding.

Eksempel på bruk:

```sql
select
    order_id,
    customer_id,
    ordered_at,
    amount

from {{ ref('fct_orders') }}

where 1 = 1
{{ filter_recent_data_by_environment('ordered_at') }}
```

Forventet kompilert SQL i `dev`:

```sql
where 1 = 1
and ordered_at >= timestamp_sub(current_timestamp(), interval 7 day)
```

### Krav

- Bruk `env_var('DBT_ENVIRONMENT', 'dev')`.
- Bruk `timestamp_sub(current_timestamp(), interval ... day)`.
- Ikke bruk `limit`.
- Makroen skal være trygg for produksjon.
- Kjør `dbt compile` med ulike verdier for `DBT_ENVIRONMENT`.

Eksempel:

```bash
DBT_ENVIRONMENT=dev dbt compile
DBT_ENVIRONMENT=test dbt compile
DBT_ENVIRONMENT=prod dbt compile
```

### Refleksjon

- Hvorfor er dette bedre enn `limit` i BigQuery?
- Hvorfor bør `ordered_at` helst være en partisjonskolonne?
- Hva kan gå galt hvis `ordered_at` ikke kan brukes til partition pruning?
- Bør denne makroen brukes i alle modeller, eller bare i store faktatabeller?

---

## Øvelse 5: Kombiner validering, dynamisk SQL og miljølogikk

### Mål

Lag en mer robust makro som både validerer input og genererer BigQuery-vennlig SQL.

### Oppgave

Lag en makro med navnet:

```jinja
safe_environment_date_filter(
    date_column,
    environment_variable='DBT_ENVIRONMENT',
    dev_days=7,
    test_days=30,
    allowed_environments=['dev', 'test', 'prod']
)
```

Makroen skal:

1. Lese miljø fra `environment_variable`.
2. Kontrollere at miljøet finnes i `allowed_environments`.
3. Kontrollere at `dev_days` og `test_days` er positive tall.
4. Legge til datofilter i `dev` og `test`.
5. Ikke legge til filter i `prod`.
6. Stoppe kompileringen med en tydelig feilmelding hvis input er ugyldig.

Eksempel på bruk:

```sql
select
    order_id,
    customer_id,
    ordered_at,
    amount

from {{ ref('fct_orders') }}

where 1 = 1
{{ safe_environment_date_filter(
    date_column='ordered_at',
    dev_days=3,
    test_days=14
) }}
```

Forventet kompilert SQL i `dev`:

```sql
where 1 = 1
and ordered_at >= timestamp_sub(current_timestamp(), interval 3 day)
```

### Krav

- Bruk `env_var`.
- Bruk `exceptions.raise_compiler_error`.
- Bruk `if`/`elif`/`else`.
- Sørg for at `prod` ikke får ekstra filter.
- Kjør `dbt compile` i minst to miljøer.
- Test også én ugyldig verdi, for eksempel:

```bash
DBT_ENVIRONMENT=sandbox dbt compile
```

### Ekstra utfordring

Legg til støtte for en egen miljøverdi:

```text
ci
```

Der makroen bare skanner siste 1 dag.

Eksempel:

```jinja
ci_days=1
```

Forventet logikk:

```sql
and ordered_at >= timestamp_sub(current_timestamp(), interval 1 day)
```

### Refleksjon

- Når er det verdt å legge validering inn i en makro?
- Gjør denne makroen modellene lettere eller vanskeligere å lese?
- Hvilke deler av denne makroen er BigQuery-spesifikke?
- Hvordan ville makroen måtte endres for Snowflake eller Postgres?
