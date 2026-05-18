with source as (
    select * from {{ source("crm", "customers") }}
),

casts as (
    select
        custid as customer_id,
        full_name,
        email,
        phone,
        status,
        created_at::date as created_at,
        address::json ->> 'street' as street,
        address::json ->> 'city' as city,
        address::json ->> 'zip' as zip_code,
        address::json ->> 'country' as country_code,
        preferences::json ->> 'language' as language,
        (preferences::json ->> 'paperless')::bool as use_paperless,
        (preferences::json ->> 'marketing_opt_in')::bool as is_marketing_enabled
    from source
)

select
    customer_id,
    full_name,
    email,
    phone,
    status,
    created_at,
    street,
    city,
    zip_code,
    country_code,
    language,
    use_paperless,
    is_marketing_enabled
from casts
