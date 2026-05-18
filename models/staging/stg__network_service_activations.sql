with source as (
    select * from {{ source("network", "service_activations") }}
),

casts as (
    select
        activation_id,
        cust_id as customer_id,
        msisdn,
        activated_at::timestamp as activated_at,
        device_info
    from source
)

select
    activation_id,
    customer_id,
    msisdn,
    activated_at,
    device_info
from casts
