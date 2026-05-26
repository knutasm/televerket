---
title: Testing
---

# Testing

## Hva er en dbt-test?

En **test** i dbt er en sjekk som kjøres mot data i databasen og feiler hvis én eller flere rader ikke oppfyller kravet.

Tester kjøres med:

```bash
dbt test
dbt test --select stg__crm_customers   # ett modell
dbt test --select tag:customer         # alle med tag
```

dbt skiller mellom to typer:

| Type | Beskrivelse |
|---|---|
| **Generiske** | Makroer som konfigureres i YAML — gjenbrukbare |
| **Singulære** | SQL-filer i `data-tests/` — returnerer rader som feiler |

## Innebygde generiske tester

dbt har fire innebygde tester som dekker de vanligste behovene:

| Test | Sjekker |
|---|---|
| `unique` | Ingen duplikater i kolonnen |
| `not_null` | Ingen null-verdier |
| `accepted_values` | Kun verdier fra en definert liste |
| `relationships` | Fremmednøkkel finnes i en annen modell |

De konfigureres direkte i YAML, uten SQL.

## Tester i YAML

```yaml
models:
  - name: stg__crm_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
      - name: status
        tests:
          - accepted_values:
              values: ['active', 'suspended', 'terminated']
      - name: contract_id
        tests:
          - relationships:
              to: ref('stg__crm_contracts')
              field: contract_id
```

Alle fire innebygde tester brukes i dette prosjektet (se `_staging.yml`).

## Alvorlighetsgrad: `warn` vs. `error`

Ikke alle testfeil er like kritiske. dbt lar deg styre hva som skjer når en test feiler:

```yaml
columns:
  - name: email
    tests:
      - not_null:
          severity: warn   # logg advarsel, stopp ikke pipelinen
  - name: customer_id
    tests:
      - unique:
          severity: error  # stopp pipelinen (standard)
```

- **`error`** (standard): dbt feiler: downstream-modeller kjøres ikke
- **`warn`**: dbt rapporterer problemet, men fortsetter

> Bruk `warn` for kjente kildesystemfeil du dokumenterer men ikke kan fikse, f.eks. at 5 kunder mangler e-post.

## `store_failures`

Når en test feiler ønsker du ofte å se *hvilke rader* som feiler, ikke bare at testen feiler.

```yaml
columns:
  - name: customer_id
    tests:
      - relationships:
          to: ref('stg__crm_customers')
          field: customer_id
          store_failures: true
```

dbt materialiserer de feilende radene som en tabell i databasen, nyttig for feilsøking og dokumentasjon av kjente datakvalitetsproblemer.

Kan også settes globalt i `dbt_project.yml`:

```yaml
tests:
  +store_failures: true
```

## Singulære tester

En singulær test er en vanlig SQL-fil i `data-tests/` som returnerer rader som feiler.

```sql
-- data-tests/assert_invoice_amount_positive.sql
select *
from {{ ref('stg__billing_invoices') }}
where amount_eur < 0
  and status != 'credited'
```

dbt feiler testen hvis én eller flere rader returneres.

Passer for forretningsregler som ikke lar seg uttrykke med generiske tester, men kan bli mange og vanskelige å vedlikeholde i store prosjekter.

## Testing av kjente feil

Kildedataene i dette prosjektet har 13 kjente problemer. Tester kan brukes til å *dokumentere* dem, ikke bare oppdage dem:

```yaml
- name: customer_id
  tests:
    - unique:
        severity: warn
        # kjent: C001, C005, C010, C016 har to aktive kontrakter
```

To tilnærminger:
- **Ikke test det du vet feiler**: spar testen til kildesystemet er fikset
- **Test med `warn`**: dokumenterer problemet eksplisitt og varsler hvis det endrer seg

> Hva er risikoen ved å ikke teste kjente feil i det hele tatt?

## Datasett: tester i dette prosjektet

Viktige tester å ha på plass etter sesjon 2:

| Modell | Kolonne | Test | Merk |
|---|---|---|---|
| `stg__crm_customers` | `customer_id` | `unique`, `not_null` | |
| `stg__crm_contracts` | `customer_id` | `unique` | forventes å feile — 4 kunder |
| `stg__billing_invoices` | `customer_id` | `relationships` | forventes å feile — 2 foreldreløse |
| `stg__billing_payments` | `invoice_ref` | `unique` | forventes å feile — duplikater |
| `stg__crm_contracts` | `status` | `accepted_values` | |
| `int__customers_enriched` | `customer_id` | `unique`, `not_null` | |
