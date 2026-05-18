with source as (
    select * from {{ source("network", "incidents") }}
),

casts as (
    select
        inc_id as incident_id,
        customer_ref as customer_id,
        reported_at::timestamp as reported_at,
        resolved_at::timestamp as resolved_at,
        type,
        region,
        severity
    from source
)

select
    incident_id,
    customer_id,
    reported_at,
    resolved_at,
    type,
    region,
    severity
from casts
