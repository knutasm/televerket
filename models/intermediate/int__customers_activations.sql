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
    {{ json_extract('a.device_info', 'make') }}              as device_make,
    {{ json_extract('a.device_info', 'model') }}             as device_model,
    lower({{ json_extract('a.device_info', 'os') }})         as device_os,
    {{ json_extract('a.device_info', 'imei') }}              as device_imei
from customers as c
left join latest_activations as a
    on c.customer_id = a.customer_id
