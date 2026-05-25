# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dbt course project modeled after a fictional telecom company (Televerket). It is used to teach multi-layered dbt pipelines with real-world data quality challenges. The project targets multiple databases: DuckDB (local), BigQuery, Snowflake, and Postgres.

## Command line utilities
You run in an environment where fd, fzf and ripgrep are available. For any file search or grep in the current directory, use fd and rg tools. For stuctural matching, use ast-grep

## Common Commands

**Package manager:** `uv` (not pip directly)

```bash
# Install Python dependencies
uv sync

# Install dbt packages
dbt deps

# Run all models
dbt run

# Run a single model
dbt run --select stg__crm_customers

# Run tests
dbt test

# Run tests for a single model
dbt test --select stg__crm_customers

# Lint SQL
sqlfluff lint models/
sqlfluff fix models/

# Generate and serve docs
dbt docs generate && dbt docs serve

# Load seed data (for local DuckDB development)
task seed
```

## Architecture

### Data Layers

Models live in `models/` and follow a three-layer pattern:

| Layer | Path | Materialization | Purpose |
|---|---|---|---|
| Staging | `models/staging/` | view | 1:1 with source tables; standardize names/types, resolve source quirks |
| Intermediate | `models/intermediate/` | view | Combine staging models; business logic; data quality handling |
| Marts | `models/marts/` | table | Analytics-ready, subject-oriented tables |

### Source Systems

Defined in `models/__sources.yml`. Four source systems from a `raw` dataset:
- **CRM:** `crm_customers`, `crm_contracts`
- **Billing:** `billing_invoices`, `billing_payments`
- **Network/OSS:** `network_service_activations`, `network_incidents`
- **Catalog:** `catalog_products`

Local source data is in `input_data/` as parquet files.

### Naming Convention

Models are named `<layer>__<source>_<entity>.sql` (double underscore between layer prefix and name), e.g. `stg__crm_customers.sql`.

### Macros

- `macros/cents_to_dollars.sql` — multi-dialect currency conversion
- `macros/generate_schema_name.sql` — custom schema naming (overrides dbt default)

### Packages

- `dbt_utils` — general utility functions
- `dbt_date` — date utilities (timezone set to `Europe/Oslo`)
- `audit_helper` — model comparison and auditing

## SQL Style

sqlfluff is configured (`.sqlfluff`) with:
- Dialect: snowflake (but macros support multiple dialects)
- Max line length: 80 characters
- Lowercase SQL keywords
- Explicit table/column aliasing required
- 4-space indentation

## Intentional Data Quality Issues

The source data has 13 known issues that models must handle, including:
- Inconsistent column naming (`custID`, `InvoiceID`)
- String-encoded amounts and `YYYYMMDD`-formatted dates
- JSON blobs for addresses, preferences, and device info
- Nulls in contact fields
- Orphaned invoices (referencing non-existent customers)
- Duplicate payment records
- Multiple active contracts per customer
- Product code reuse across catalog versions

## CI/CD

- PRs to `main` or `staging` trigger parallel dbt Cloud jobs on BigQuery, Snowflake, and Postgres
- Schema override pattern: `dbt_jsdx__pr_<branch-name>`
- Production deploys on merge to `main`; staging deploys on merge to `staging`
- CI script: `.github/workflows/scripts/dbt_cloud_run_job.py`
