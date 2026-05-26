---
name: document-source
description: Use this skill when the user asks to "document a source", "add documentation to a source", "describe a source table", "document [source name]", or otherwise wants to add descriptions, column docs, or metadata to source tables in __sources.yml.
argument-hint: [database schema]
allowed-tools: [Read, Edit, Bash]
---

# Document Source

Walk the user through documenting one or more source tables in `models/__sources.yml`.

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

> "Which schema contains the tables you want to document?"

Then run:

```bash
duckdb <database> -c "SELECT table_name FROM information_schema.tables WHERE table_schema = '<schema>' ORDER BY table_name"
```

Show the result to the user.

### 3. Which tables

Ask:

> "Which of these tables would you like to document? List them separated by spaces."

For each table the user selects, run through steps 4–9 before moving to the next table.

---

### Per-table steps

#### 4. Check for existing entry

Read `models/__sources.yml`. If an entry for this table already exists, tell the user and skip to the next table.

#### 5. Table description

Ask:

> "How would you describe the `<table>` table in one sentence?"

#### 6. Metadata

Ask:

> "Would you like to add any metadata for `<table>`? I can capture:
> - **Technical owner** — team responsible for the pipeline (e.g. `data_engineering`)
> - **Business owner** — business stakeholder (e.g. `finance`)
> - **Source system contact** — who to call when the source breaks (e.g. `erp_support@example.com`)
>
> Reply with whatever applies in the format `field: value`, one per line — or say 'skip'."

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

If **yes**: run the following to get the column list:

```bash
duckdb <database> -c "DESCRIBE <schema>.<table>"
```

Show the columns to the user and ask:

> "For each column you'd like to describe, reply in the format `column_name: description`, one per line. Leave out any you want to skip."

If **no**: skip column descriptions entirely.

#### 9. Write the entry

Add or update the table entry in `models/__sources.yml` under the correct source group (matching the schema name). If the source group does not yet exist, create it.

```yaml
- name: <table>
  description: <description>
  tags: [<tags>]                       # omit if none
  meta:
    technical_owner: <value>           # omit fields the user skipped
    business_owner: <value>
    source_contact: <value>
  columns:                             # omit block if user said no
    - name: <column_name>
      description: <description>
```

Preserve all existing entries exactly.

---

### After all tables

Tell the user which tables were updated and suggest:

```bash
dbt ls --select source:<schema>.*
```
