---
name: create-source
description: Use this skill when the user asks to "create a source", "add a source", "register a new source", "set up a source in dbt", or otherwise wants to add brand-new source table entries to __sources.yml. Combines documentation and freshness configuration in one guided walkthrough.
argument-hint: [database schema]
allowed-tools: [Read, Edit, Bash]
---

# Create Source

Guide the user through registering one or more source tables in `models/__sources.yml` from scratch — covering table description, metadata, tags, optional column docs, and freshness configuration.

This skill combines `/document-source` and `/source-freshness` into a single conversation.

## Arguments

The user may have provided: `$ARGUMENTS`

---

## Walkthrough

Ask one question at a time. Wait for each answer before continuing.

### 1. Database

If not supplied in `$ARGUMENTS`, ask:

> "What is the path to the DuckDB database file? (e.g. `televerket.duckdb`)"

### 2. Schema

Ask:

> "Which schema contains the tables you want to register?"

Then run:

```bash
duckdb <database> -c "SELECT table_name FROM information_schema.tables WHERE table_schema = '<schema>' ORDER BY table_name"
```

Show the result to the user.

### 3. Which tables

Ask:

> "Which of these tables would you like to add? List them separated by spaces."

Read `models/__sources.yml`. For any table the user selects that already exists in the file, skip it and let the user know (suggest `/document-source` or `/source-freshness` for those).

For each remaining table, run through steps 4–11 before moving to the next table.

---

### Per-table steps

#### 4. Inspect columns

Without asking, run:

```bash
duckdb <database> -c "DESCRIBE <schema>.<table>"
```

Show the column names and types to the user so they have context for the questions that follow.

#### 5. Table description

Ask:

> "How would you describe the `<table>` table in one sentence?"

#### 6. Metadata

Ask:

> "Would you like to add metadata for `<table>`? I can capture:
> - **Technical owner** — team responsible for the pipeline (e.g. `data_engineering`)
> - **Business owner** — business stakeholder (e.g. `finance`)
> - **Source system contact** — who to call when the source breaks (e.g. `erp_support@example.com`)
>
> Reply with `field: value`, one per line — or say 'skip'."

#### 7. Tags

Ask:

> "Any tags for `<table>`? Common ones:
> - `pii` — personally identifiable information
> - `sensitive` — restricted access
> - `financial` — billing or revenue data
>
> List any that apply, or say 'none'."

#### 8. Column descriptions

Ask:

> "Would you like to add column-level descriptions for `<table>`? (yes / no)"

If **yes**: show the columns from step 4 and ask:

> "For each column you'd like to describe, reply in the format `column_name: description`, one per line. Leave out any you want to skip."

If **no**: skip column descriptions entirely.

#### 9. Freshness column

From the columns inspected in step 4, identify those that look like timestamps (`_at`, `_time`, `_date`, `loaded`, `updated`, `created`, or type `TIMESTAMP` / `DATE`). Show them and ask:

> "Should we configure a freshness check for `<table>`? If yes, which column should dbt use to measure staleness? (Say 'skip' to leave freshness out.)"

#### 10. Freshness thresholds

If the user did not skip freshness, ask:

> "How stale can `<table>` get before a **warning** is raised? (e.g. `24 hours`, `7 days`)"

Then:

> "And the **error** threshold — when should dbt treat the data as critically stale?"

Parse both answers into `count` and `period` (`minute` / `hour` / `day`).

#### 11. Write the entry

Build the complete YAML entry and add it to `models/__sources.yml`.

- If the source group (matching the schema name) already exists, add the table under its `tables:` key.
- If the source group is new, create it.
- Omit any optional blocks (`tags`, `meta`, `columns`, `config`) that the user skipped.
- Preserve all existing entries exactly.

```yaml
- name: <table>
  description: <description>
  tags: [<tags>]
  meta:
    technical_owner: <value>
    business_owner: <value>
    source_contact: <value>
  config:
    loaded_at_field: <column>::timestamp
    freshness:
      warn_after:
        count: <warn_count>
        period: <warn_period>
      error_after:
        count: <error_count>
        period: <error_period>
  columns:
    - name: <column_name>
      description: <description>
```

---

### After all tables

Run for each added table:

```bash
dbt ls --select source:<schema>.<table>
```

If freshness was configured, also run:

```bash
dbt source freshness --select source:<schema>.<table>
```

Report results. If anything fails, show the error and suggest a fix.
