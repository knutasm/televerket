with incidents as (
    select * from {{ ref("stg__network_incidents") }}
),

customers as (
    select * from {{ ref("int__customers_enriched") }}
)

select
    i.incident_id,
    i.customer_id,
    i.reported_at,
    i.resolved_at,
    i.type,
    i.region,
    i.severity,
    c.full_name as customer_name,
    c.status as customer_status,
    c.contract_status,
    case
        when i.resolved_at is not null
            then datediff('minute', i.reported_at, i.resolved_at)
    end as resolution_time_minutes
from incidents as i
left join customers as c
    on i.customer_id = c.customer_id
