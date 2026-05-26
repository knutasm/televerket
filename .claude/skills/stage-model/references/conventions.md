# Staging Model Conventions

## File naming

`models/staging/stg__<source>_<entity>.sql`
Double underscore between `stg` and the rest. Source and entity are both lowercase snake_case.

## SQL style (enforced by sqlfluff)

- Lowercase SQL keywords
- 4-space indentation
- Max 80 characters per line
- Trailing commas
- All columns explicitly aliased when renamed or transformed

## CTE structure

Single CTE named `source`. Within the CTE, columns appear in this order:

1. **Pure selects** — columns passed through with no transformation and no rename
2. **Name / type conversions** — renames, type casts, or both together
3. **Unpacking / other transforms** — JSON extraction, macro calls, expressions

If the user wants deduplication, add a second CTE named `deduped` after `source`,
using `qualify row_number() over (partition by <pk> order by <tiebreaker> desc) = 1`.

## Column classification for the final select

| Class | Examples |
|---|---|
| Primary key | `<entity>_id` — first identifier column(s) |
| Foreign keys | other `_id` columns, `_ref` columns |
| Attributes — textual / categorical | `status`, `type`, `region`, `name`, `email` |
| Attributes — numerical | `monthly_fee_eur`, `amount_eur` |
| Flags | boolean columns; prefix `is_`, `has_`, `use_` |
| Dates / times | DATE or TIMESTAMP columns |
| System columns | `created_at`, `updated_at`, `loaded_at` |

## Column naming rules

- All output column names must be lowercase snake_case.
- Non-snake_case source names must be renamed: `custID → customer_id`, `InvoiceID → invoice_id`.
- Common abbreviation expansions: `cust_` → `customer_`, `inc_` → `incident_`.
- ID columns always end in `_id` with an underscore.

## Type cast rules

| Pattern | Cast |
|---|---|
| VARCHAR date (ISO format) | `col::date` |
| VARCHAR timestamp | `col::timestamp` |
| VARCHAR date in YYYYMMDD format | `{{ parse_yyyymmdd('col') }}` |
| VARCHAR monetary amount | `try_cast(col as decimal(10, 2))` |
| VARCHAR JSON blob | `{{ json_extract('col', 'field') }}` per field |
| Boolean stored as VARCHAR | `col::bool` |

Use `try_cast` for monetary values to avoid failures on dirty data.

## Macros available

- `{{ parse_yyyymmdd('col') }}` — parses YYYYMMDD string to DATE (multi-dialect)
- `{{ json_extract('col', 'path') }}` — extracts a JSON field (multi-dialect)
- `{{ cents_to_dollars('col') }}` — converts integer cents to decimal (multi-dialect)

## YAML tests (_staging.yml)

Every model entry must have:
- A `description:` summarising what the model does and which source quirks it resolves

### Uniqueness

| Situation | Test |
|---|---|
| Single-column PK, no duplicates expected | `unique` + `not_null` on the PK column |
| Composite PK, no duplicates expected | `dbt_utils.unique_combination_of_columns` at model level |
| Duplicates known to exist and NOT fixed here | `unique` test with inline comment `# known issue: ...` explaining the duplicates |
| Duplicates fixed by deduplication CTE | `unique` + `not_null` — no comment needed |

### Foreign keys

Add a `relationships` test on FK columns only when the user confirms they want FK testing.
Point to the staging model that owns the PK, e.g.:

```yaml
- name: customer_id
  tests:
    - relationships:
        to: ref('stg__crm_customers')
        field: customer_id
```

### Enum / categorical columns

Add `accepted_values` for any column with ≤ 15 distinct values (sampled from the source).

### Known data quality issues

Place an inline YAML comment immediately above the failing test:

```yaml
- name: customer_id
  tests:
    # known issue: 2 invoices reference customers not in crm_customers
    - relationships:
        to: ref('stg__crm_customers')
        field: customer_id
```
