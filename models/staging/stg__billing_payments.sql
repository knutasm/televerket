with source as (
    select * from {{ source("billing", "payments") }}
),

casts as (
    select
        payment_id,
        invoice_ref,
        paid_on::date as paid_on,
        try_cast(amount as decimal(10, 2)) as amount,
        method
    from source
)

select
    payment_id,
    invoice_ref,
    paid_on,
    amount,
    method
from casts
