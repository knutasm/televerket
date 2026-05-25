{# Blokk 1 — oppgave 3: Jinja-variabel og betingelse
   Sett inkluder_krediterte = false for å filtrere ut krediterte fakturaer. #}

{% set inkluder_krediterte = true %}

select
    invoice_id,
    customer_id,
    invoice_date,
    due_date,
    amount_eur,
    status
from {{ ref('stg__billing_invoices') }}
{% if not inkluder_krediterte %}
where status != 'credited'
{% endif %}
