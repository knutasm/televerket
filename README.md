# dbt Course — Telecom Dataset

## Context

For this course you will be working as a data engineer at a fictional Dutch telecom company. The company runs several internal systems that each produce their own data, and your job is to build a well-structured dbt project on top of them — from raw source tables all the way through to analytics-ready mart models.

The source data is already loaded into BigQuery and available in the `raw` dataset. Your dbt project will read from there and build models in a separate target dataset.

---

## Source Systems

Data comes from four systems. Each has its own naming conventions, data types, and quirks — just like the real world.

### CRM (`raw.crm_customers`, `raw.crm_contracts`)

The customer relationship management system is the authoritative source for customer identity and subscription contracts.

`crm_customers` holds one record per customer with contact details, account status, and two JSON blobs: an `address` field containing the customer's postal address, and a `preferences` field containing communication preferences such as language and marketing opt-in status.

`crm_contracts` holds the history of subscription contracts per customer. A customer can have more than one active contract (for example, a mobile plan and a fiber plan), and terminated contracts are retained in the table with their end dates intact.

### Billing (`raw.billing_invoices`, `raw.billing_payments`)

The billing system generates monthly invoices and records incoming payments separately.

`billing_invoices` holds one record per invoice. Note that invoice dates are stored as strings in `YYYYMMDD` format, and the amount field is also a string. The table contains invoices in various statuses: paid, overdue, open, and credited.

`billing_payments` records individual payment transactions. Payments reference invoices but do not carry a direct customer key — the link to the customer runs through the invoice.

### Network / OSS (`raw.network_service_activations`, `raw.network_incidents`)

The network operations system tracks when customer services were activated and logs incidents such as outages, degraded signal, or billing disputes.

`network_service_activations` records each time a SIM or line was activated for a customer. The `device_info` column contains a JSON object with device make, model, operating system, and IMEI number.

`network_incidents` logs incidents reported by or attributed to customers, with timestamps for when they were reported and when they were resolved. Unresolved incidents have a null `resolved_at`.

### Product Catalog (`raw.catalog_products`)

A small reference table describing the products the company offers. Products have a validity window (`valid_from`, `valid_to`), so the same product code can appear more than once when a product has changed over time. Legacy products with a `valid_to` date are retained for historical reference.

---

## Data Model Overview

```
raw (BigQuery source dataset)
│
├── crm_customers
├── crm_contracts
├── billing_invoices
├── billing_payments
├── network_service_activations
├── network_incidents
└── catalog_products
```

Over the course of the session you will build a layered dbt project on top of these sources:

**Staging** — one model per source table. Each staging model is the single place where column names are standardised, data types are cast to their correct types, and source-system quirks are resolved. Staging models are thin and stay close to the source.

**Intermediate** — models that combine or enrich staging models. Business logic lives here: joining customer data across systems, resolving one-to-many relationships, handling JSON fields that require more than a simple unpack, and dealing with data quality issues such as duplicate records.

**Marts** — subject-oriented, analytics-ready tables. These are what downstream consumers — reports, dashboards, data scientists — actually query. Marts are built from intermediate models and present a clean, integrated view of a business entity or process.

---

## Intentional Data Quality Issues

The dataset contains a number of deliberate imperfections. Part of the work is noticing them, deciding where in the layer stack to handle them, and writing tests that make them visible.

| Issue | Where |
|---|---|
| Column naming inconsistency (`custID`, `InvoiceID`) | `crm_customers`, `billing_invoices` |
| Amount and fee columns stored as strings | `billing_invoices`, `crm_contracts` |
| Dates stored as `YYYYMMDD` strings | `billing_invoices` |
| JSON blobs requiring unpacking | `crm_customers` (address, preferences), `network_service_activations` (device info) |
| Null values in contact fields | `crm_customers` (email, phone) |
| Customers with no contract | `crm_customers` (one pending customer) |
| Invoices referencing non-existent customers | `billing_invoices` |
| Duplicate payment records | `billing_payments` |
| Null IMEI and OS values inside JSON | `network_service_activations` |
| Open incidents with null resolution timestamp | `network_incidents` |
| Multiple active contracts per customer | `crm_contracts` |
| Product code reuse across product versions | `catalog_products` |

---

## Key Relationships

```
crm_customers ──< crm_contracts
crm_customers ──< billing_invoices
crm_customers ──< network_service_activations
crm_customers ──< network_incidents
billing_invoices ──< billing_payments
crm_contracts >── catalog_products
```

Note that `network_incidents` uses `customer_ref` as its foreign key column name, while other tables use `customer_id` or `cust_id`. This is intentional.

---

## Column Types at Source

The table below shows how columns arrive in BigQuery. Types marked as *intentional* are exercises — you will be casting these in your staging models.

| Table | Column | Type | Note |
|---|---|---|---|
| `crm_customers` | `created_at` | DATE | |
| `crm_customers` | `address` | STRING | JSON — unpack exercise |
| `crm_customers` | `preferences` | STRING | JSON — unpack exercise |
| `crm_contracts` | `start_date`, `end_date` | DATE | |
| `crm_contracts` | `monthly_fee` | STRING | *Intentional* — cast to NUMERIC |
| `billing_invoices` | `invoice_date`, `due_date` | STRING | *Intentional* — cast from YYYYMMDD |
| `billing_invoices` | `amount_eur` | STRING | *Intentional* — cast to NUMERIC |
| `billing_payments` | `paid_on` | DATE | |
| `billing_payments` | `amount` | FLOAT | |
| `network_service_activations` | `activated_at` | TIMESTAMP | |
| `network_service_activations` | `device_info` | STRING | JSON — unpack exercise |
| `network_incidents` | `reported_at`, `resolved_at` | TIMESTAMP | |
| `catalog_products` | `monthly_fee_eur` | FLOAT | |
| `catalog_products` | `valid_from`, `valid_to` | DATE | |

heihei
