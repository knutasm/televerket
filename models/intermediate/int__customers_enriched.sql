with customers as (
    select * from {{ ref("stg__crm_customers") }}
),

latest_contracts as (
    select distinct on (customer_id)
        contract_id,
        customer_id,
        product_code,
        start_date,
        end_date,
        monthly_fee_eur,
        status
    from {{ ref("stg__crm_contracts") }}
    where status = 'active'
    order by customer_id, start_date desc
)

select
    c.customer_id,
    c.full_name,
    c.email,
    c.phone,
    c.status,
    c.created_at,
    c.street,
    c.city,
    c.zip_code,
    c.country_code,
    c.language as preferred_language,
    c.use_paperless as paperless_billing,
    c.is_marketing_enabled as marketing_opt_in,
    con.contract_id,
    con.product_code,
    con.start_date as contract_start_date,
    con.monthly_fee_eur,
    con.status as contract_status
from customers as c
left join latest_contracts as con
    on c.customer_id = con.customer_id
