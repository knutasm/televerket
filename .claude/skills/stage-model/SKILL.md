---
name: stage-model
description: Use this skill when the user asks to "create a staging model", "stage a source table", "add a staging layer for", "build stg__", or otherwise wants to generate a new dbt staging model and its _staging.yml entry.
argument-hint: [source.table ...]
allowed-tools: [Read, Write, Bash]
---

# Stage Model

Guide the user through creating a new dbt staging model (`stg__<source>_<table>.sql`)
and its `_staging.yml` entry from an existing dbt source definition.

Read `references/conventions.md` and `references/template.sql` before generating
any code. All output must conform to those standards.

## Arguments

The user may have provided: `$ARGUMENTS`

---

## Walkthrough

Ask one question at a time. Wait for each answer before continuing.

### 1. Pick the source table(s)

Read `models/__sources.yml` and display all registered sources and tables:

```
Available sources:
  crm       — customers, contracts
  billing   — invoices, payments
  ...
```

If `$ARGUMENTS` already contains a valid `source.table`, skip this question.
Otherwise ask:

> "Which source table(s) would you like to stage? You can list several separated
> by spaces (e.g. `crm.contracts billing.invoices`)."

For any table that already has a staging model in `models/staging/`, skip it and
let the user know.

---

### Per-table steps

Run through steps 2–12 for each selected table before moving to the next.

---

### 2. Inspect columns and sample data

Without asking, run:

```bash
duckdb televerket.duckdb -c "DESCRIBE <schema>.<table>"
```

Then for each column, check the number of distinct values:

```bash
duckdb televerket.duckdb -c "
  SELECT '<col>' as col, count(distinct <col>) as n_distinct
  FROM <schema>.<table>
"
```

For columns with ≤ 15 distinct values, fetch them:

```bash
duckdb televerket.duckdb -c "
  SELECT <col>, count(*) as n
  FROM <schema>.<table>
  GROUP BY <col>
  ORDER BY n desc
"
```

Also sample 3 rows to detect JSON blobs and YYYYMMDD strings:

```bash
duckdb televerket.duckdb -c "SELECT * FROM <schema>.<table> LIMIT 3"
```

Do not show all of this raw output to the user. Summarise your findings in the
next step.

### 3. Propose the transformation plan

Show the user a compact table of proposed column transformations:

```
Column plan for <schema>.<table>:

  source column     → output column         transform
  ─────────────────────────────────────────────────────────
  contract_id         contract_id           (none)
  cust_id           → customer_id           rename
  start_date          start_date            ::date
  monthly_fee       → monthly_fee_eur       rename + try_cast decimal(10,2)
  address             (ask user)            JSON blob detected
```

Use the detection rules from `references/conventions.md` to populate this table
automatically. Highlight any column where you are uncertain.

Ask:

> "Does this look right? Correct anything or say 'ok' to continue."

### 4. JSON columns

For each VARCHAR column whose sampled values start with `{` or `[`, ask:

> "The column `<col>` looks like a JSON blob. Which fields would you like to
> unpack? (e.g. `street, city, zip`) — or say 'skip' to pass it through as-is."

Use `{{ json_extract('col', 'field') }} as field` for each extracted field.

### 5. Duplicates

Ask:

> "Do you expect duplicate rows in `<table>` (i.e. the same primary key
> appearing more than once)?
>
> - **no** — uniqueness will be enforced with a test
> - **yes, fix here** — I'll add a deduplication CTE; which column should
>   break ties? (e.g. `updated_at desc`)
> - **yes, known issue** — uniqueness test added with a known-issue comment"

### 6. Foreign key tests

Ask:

> "Are there any foreign key relationships to test? For example, does
> `customer_id` in this table reference `stg__crm_customers`?
>
> List any you'd like tested as `column → stg__<model>.<field>`, or say 'none'."

### 7. Known data quality issues

Ask:

> "Are there any known data quality issues I should document as comments in
> the YAML? (e.g. 'some records have null email', 'two payments share the same
> invoice_ref') — or say 'none'."

---

### 8. Generate the SQL model

Write `models/staging/stg__<source>_<table>.sql` following `references/template.sql`
exactly:

- CTE named `source`, columns ordered: pure selects → name/type conversions →
  unpacking/other transforms
- If deduplication requested, add a `deduped` CTE after `source`
- Final `select` from `source` (or `deduped`), columns ordered:
  PK → FKs → attributes (text/categorical first, numerical) → flags →
  dates/times → system columns
- Use `{{ source("<schema>", "<table>") }}` for the source reference
- Use `{{ json_extract(...) }}` and `{{ parse_yyyymmdd(...) }}` macros where applicable

### 9. Generate the YAML entry

Add the model entry to `models/staging/_staging.yml`:

- `description:` — one-to-two sentences: what the model contains and which source
  quirks it resolves
- PK column(s):
  - Single column: `unique` + `not_null`
  - Composite PK: `dbt_utils.unique_combination_of_columns` at model level
  - If duplicates are a known issue: add `unique` with `# known issue:` comment
- FK columns (only if user said yes in step 6): `relationships` test
- Enum columns (≤ 15 distinct values): `accepted_values` with the sampled values
- Known data quality issues: inline `# known issue:` comment above the relevant test

### 10. Run sqlfluff

Run sqlfluff fix on the generated model:

```bash
uv run sqlfluff fix models/staging/stg__<source>_<table>.sql --dialect snowflake
```

If sqlfluff reports unfixable violations, show them to the user and fix manually.

### 11. Verify with dbt

Run:

```bash
uv run dbt run --select stg__<source>_<table>
uv run dbt test --select stg__<source>_<table>
```

Report the results. If tests fail, show the error, ask whether it is a known
issue, and update the YAML comment accordingly if so.

### 12. Summary

Tell the user which files were created and the test results. If multiple tables
were selected, move on to the next one.
