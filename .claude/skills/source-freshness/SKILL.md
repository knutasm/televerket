---
name: source-freshness
description: Use this skill when the user asks to "add freshness tests", "configure freshness", "set up freshness for a source", "how stale can the data be", or otherwise wants to add dbt source freshness checks to tables in __sources.yml.
argument-hint: [database schema]
allowed-tools: [Read, Edit, Bash]
---

# Source Freshness

Walk the user through configuring dbt source freshness for one or more tables in `models/__sources.yml`.

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

> "Which schema contains the tables you want to add freshness tests to?"

Then run:

```bash
duckdb <database> -c "SELECT table_name FROM information_schema.tables WHERE table_schema = '<schema>' ORDER BY table_name"
```

Show the result to the user.

### 3. Which tables

Ask:

> "Which of these tables would you like to configure freshness for? List them separated by spaces."

For each selected table, run through steps 4–7 before moving to the next.

---

### Per-table steps

#### 4. Find timestamp columns

Without asking, run:

```bash
duckdb <database> -c "DESCRIBE <schema>.<table>"
```

Identify columns whose names contain `_at`, `_time`, `_date`, `loaded`, `updated`, or `created`, or whose type is `TIMESTAMP`, `DATE`, or `VARCHAR` holding date-like values. Show these candidates to the user.

#### 5. Freshness column

Ask:

> "Which column should dbt use to check freshness for `<table>`? (The one that best reflects when a record was last loaded or updated.)"

If no suitable column exists, tell the user and skip to the next table.

#### 6. Warning threshold

Ask:

> "How stale can the data in `<table>` get before a **warning** is raised? (e.g. `24 hours`, `7 days`, `6 hours`)"

Parse the answer into `count` (integer) and `period` (`minute` / `hour` / `day`).

#### 7. Error threshold

Ask:

> "And the **error** threshold — when should dbt consider the data critically stale? (Should be higher than the warning.)"

Parse into `count` and `period`.

#### 8. Write the config

Add or update the `config:` block for this table in `models/__sources.yml`:

```yaml
config:
  loaded_at_field: <column>::timestamp
  freshness:
    warn_after:
      count: <warn_count>
      period: <warn_period>
    error_after:
      count: <error_count>
      period: <error_period>
```

Cast `loaded_at_field` to `::timestamp` when the column is a string or date type. Preserve all other entries exactly.

---

### After all tables

Run for each configured table:

```bash
dbt source freshness --select source:<schema>.<table>
```

Report the output. If a table fails, show the error and suggest a fix.
