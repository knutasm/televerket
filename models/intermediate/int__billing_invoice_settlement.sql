with invoices as (
    select * from {{ ref("stg__billing_invoices") }}
),

first_payments as (
    select distinct on (invoice_ref)
        payment_id,
        invoice_ref,
        paid_on,
        amount,
        method
    from {{ ref("stg__billing_payments") }}
    order by invoice_ref, paid_on asc
)

select
    i.invoice_id,
    i.customer_id,
    i.invoice_date,
    i.due_date,
    i.amount_eur,
    i.status,
    p.payment_id,
    p.paid_on,
    p.amount as amount_paid,
    p.method as payment_method,
    p.payment_id is not null as is_paid
from invoices as i
left join first_payments as p
    on i.invoice_id = p.invoice_ref
