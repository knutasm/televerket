with source as (
    select * from {{ source("crm", "contracts") }}
),

casts as (
    select
        contract_id,
        cust_id as customer_id,
        product_code,
        start_date::date as start_date,
        end_date::date as end_date,
        try_cast(monthly_fee as decimal(10, 2)) as monthly_fee_eur,
        status
    from source
)

select
    contract_id,
    customer_id,
    product_code,
    start_date,
    end_date,
    monthly_fee_eur,
    status
from casts
