with customers as (
    select * from {{ ref("stg__crm_customers") }}
),

latest_activations as (
    select distinct on (customer_id)
        activation_id,
        customer_id,
        msisdn,
        activated_at,
        device_info
    from {{ ref("stg__network_service_activations") }}
    order by customer_id, activated_at desc
)

select
    c.customer_id,
    c.full_name,
    a.activation_id,
    a.msisdn,
    a.activated_at,
    a.device_info::json ->> 'make' as device_make,
    a.device_info::json ->> 'model' as device_model,
    lower(a.device_info::json ->> 'os') as device_os,
    a.device_info::json ->> 'imei' as device_imei
from customers as c
left join latest_activations as a
    on c.customer_id = a.customer_id
