with source as (
    select * from {{ source("billing", "invoices") }}
),

casts as (
    select
        invoiceid as invoice_id,
        customer_id,
        {{ parse_yyyymmdd('invoice_date') }} as invoice_date,
        {{ parse_yyyymmdd('due_date') }}     as due_date,
        try_cast(amount_eur as decimal(10, 2)) as amount_eur,
        status
    from source
)

select
    invoice_id,
    customer_id,
    invoice_date,
    due_date,
    amount_eur,
    status
from casts
